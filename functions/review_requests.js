const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const {hash, address} = require('./consent_policy');

const COOLDOWN_MS = 90 * 24 * 60 * 60 * 1000;
function previousBusinessDate(now) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Rome', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now).map(p => [p.type, p.value]));
  const date = new Date(Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day) - 1));
  return date.toISOString().slice(0, 10);
}
function validReviewUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || url.port) return false;
    return (url.hostname === 'g.page' && /^\/r\/[^/]+\/review\/?$/.test(url.pathname)) ||
      (url.hostname === 'search.google.com' && url.pathname === '/local/writereview' && !!url.searchParams.get('placeid')) ||
      (['www.google.com', 'google.com'].includes(url.hostname) && url.pathname === '/maps/reviews' && !!url.searchParams.get('placeid'));
  } catch (_) { return false; }
}
function visitEligible(booking, dateKey) {
  return booking.dateKey === dateKey && ['released', 'completed'].includes(booking.status);
}
function contact(booking) {
  const email = address(booking, 'email');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  const phone = address(booking, 'whatsapp');
  return {email, phone, profileId: hash(phone ? `phone:${phone}` : `email:${email}`),
    keys: [hash(`email:${email}`), ...(phone ? [hash(`phone:${phone}`)] : [])]};
}
function message(reviewUrl, unsubscribeUrl, language = 'it') {
  const en = language === 'en';
  const subject = en ? 'Thank you for visiting Le Capase' : 'Grazie per aver scelto Le Capase';
  const intro = en ? 'Thank you for visiting Le Capase! If you wish, share your experience on Google. Your feedback helps us improve.' :
    'Grazie per aver scelto Le Capase! Se ti va, racconta la tua esperienza su Google. La tua opinione ci aiuta a migliorare.';
  const label = en ? 'Leave a review' : 'Lascia una recensione';
  const stop = en ? 'Unsubscribe from promotional emails' : 'Disiscriviti dalle email promozionali';
  const escape = value => value.replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
  return {subject, text: `${intro}\n\n${label}: ${reviewUrl}\n\nLe Capase\n\n${stop}: ${unsubscribeUrl}`,
    html: `<p>${intro}</p><p><a href="${escape(reviewUrl)}">${label}</a></p><p>Le Capase</p><p><a href="${escape(unsubscribeUrl)}">${stop}</a></p>`};
}

// SMTP has no idempotency key. Persist a claim before sending and never retry an
// ambiguous result automatically: a crash must not create duplicate invitations.
function createRunner({db, eligible, unsubscribeLink, sendMail, isApproved = async () => false}) {
  const settings = db.collection('_system').doc('review_automation');
  async function enabledConfig() {
    if (!await isApproved()) return null;
    const config = (await settings.get()).data() || {};
    return config.enabled === true && validReviewUrl(config.reviewUrl) ? config : null;
  }
  return async function run(now = new Date(), selection = null) {
    const deadline = Date.now() + 450000;
    if (!await enabledConfig()) return {disabled: true};
    const dateKey = selection?.dateKey || previousBusinessDate(now);
    const approvedTargets = selection ? new Map(selection.recipients.map(r => [r.bookingId, r])) : null;
    const query = db.collection('bookings').where('dateKey', '==', dateKey);
    const bookings = await query.get();
    const totals = {sent: 0, skipped: 0, uncertain: 0};
    for (const snapshot of bookings.docs) {
      if (approvedTargets && !approvedTargets.has(snapshot.id)) continue;
      // Stop before a hard timeout so the approval batch can be flagged for review.
      if (Date.now() >= deadline) throw new Error('Review batch time limit reached');
      if (!await enabledConfig()) { totals.paused = true; break; }
      const booking = snapshot.data();
      if (!visitEligible(booking, dateKey)) continue;
      const event = db.collection('review_requests').doc(snapshot.id);
      if ((await event.get()).exists) continue;
      const target = contact(booking);
      const base = {bookingId: snapshot.id, dateKey, email: target?.email || '',
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
      const recordSkip = async reason => {
        await db.runTransaction(async tx => {
          if (!(await tx.get(event)).exists) tx.create(event, {...base, state: 'skipped', reason});
        });
        totals.skipped++;
      };
      if (!target) { await recordSkip('missing_email'); continue; }
      const approvedTarget = approvedTargets?.get(snapshot.id);
      if (approvedTarget && (approvedTarget.email !== target.email || approvedTarget.phone !== target.phone)) {
        await recordSkip('changed_before_send'); continue;
      }
      const profile = db.collection('customer_profiles').doc(target.profileId);
      if (!await eligible(profile, 'email', target.email)) { await recordSkip('no_consent'); continue; }
      const locks = target.keys.map(key => db.collection('review_contact_limits').doc(key));
      const claimed = await db.runTransaction(async tx => {
        const [prior, liveBooking, liveConfig, ...priorLocks] = await tx.getAll(event, snapshot.ref, settings, ...locks);
        if (prior.exists || !visitEligible(liveBooking.data() || {}, dateKey) || liveConfig.data()?.enabled !== true) return false;
        const currentContact = contact(liveBooking.data());
        if (!currentContact || currentContact.email !== target.email || currentContact.phone !== target.phone) return false;
        if (priorLocks.some(lock => {
          const at = lock.data()?.lastAttemptAt;
          return at?.toMillis && now.getTime() - at.toMillis() < COOLDOWN_MS;
        })) {
          tx.create(event, {...base, state: 'skipped', reason: 'cooldown'});
          return false;
        }
        tx.create(event, {...base, state: 'processing', reason: null});
        for (const lock of locks) tx.set(lock, {bookingId: snapshot.id, lastAttemptAt: Timestamp.fromDate(now)});
        return true;
      });
      if (!claimed) { totals.skipped++; continue; }
      let attempted = false;
      try {
        const unsubscribeUrl = await unsubscribeLink(profile, target.email);
        const config = await enabledConfig();
        const live = (await snapshot.ref.get()).data() || {};
        const liveContact = contact(live);
        if (!config || !visitEligible(live, dateKey) || liveContact?.email !== target.email ||
            liveContact?.phone !== target.phone || !await eligible(profile, 'email', target.email)) {
          await event.update({state: 'skipped', reason: 'changed_before_send', updatedAt: FieldValue.serverTimestamp()});
          totals.skipped++;
          continue;
        }
        attempted = true;
        const result = await sendMail({to: target.email, ...message(selection?.reviewUrl || config.reviewUrl, unsubscribeUrl, live.language)});
        if (!result?.accepted?.some(value => String(value).toLowerCase() === target.email)) {
          throw new Error('Delivery not confirmed');
        }
        await event.update({state: 'sent', sentAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(), messageId: result.messageId || null});
        totals.sent++;
      } catch (_) {
        // Do not expose provider errors or retry a possibly accepted email.
        await event.update({state: attempted ? 'uncertain' : 'failed',
          reason: attempted ? 'provider_result_unknown' : 'preparation_failed', updatedAt: FieldValue.serverTimestamp()});
        totals.uncertain++;
      }
    }
    return totals;
  };
}
module.exports = {createRunner, previousBusinessDate, validReviewUrl, visitEligible, contact, message, COOLDOWN_MS};
