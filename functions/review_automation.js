const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {FieldValue} = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const {createRunner, validReviewUrl, previousBusinessDate, visitEligible, contact, COOLDOWN_MS} = require('./review_requests');
const DEFAULT_REVIEW_URL = 'https://g.page/r/CVT1Lz6T5_JyEBM/review';

module.exports = function buildReviewAutomation({db, gmailUser, gmailAppPassword, consents, mailTransport = null}) {
  const settings = db.collection('_system').doc('review_automation');
  const batches = db.collection('review_batches');
  const options = {region: 'europe-west1', maxInstances: 1};
  async function requireAdmin(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Accedi al gestionale.');
    const [staff, legacy] = await Promise.all([
      db.collection('staff_users').doc(uid).get(), db.collection('admins').doc(uid).get(),
    ]);
    if (![staff, legacy].some(doc => doc.data()?.active === true && doc.data()?.role === 'admin')) {
      throw new HttpsError('permission-denied', 'Solo gli amministratori possono autorizzare le richieste recensione.');
    }
    return uid;
  }
  const getReviewAutomation = onCall(options, async request => {
    await requireAdmin(request);
    const [config, events, groups, pending] = await Promise.all([
      settings.get(), db.collection('review_requests').orderBy('createdAt', 'desc').limit(100).get(),
      batches.orderBy('createdAt', 'desc').limit(30).get(),
      batches.where('state','==','pending').get(),
    ]);
    return {enabled: config.data()?.enabled === true, reviewUrl: config.data()?.reviewUrl || DEFAULT_REVIEW_URL,
      batches: [...new Map([...pending.docs,...groups.docs].map(doc=>[doc.id,doc])).values()].map(doc => {
        const value = doc.data();
        return {id: doc.id, state: value.state, dateKey: value.dateKey, count: value.recipients.length,
          recipients: value.recipients.map(r => ({email:r.email})), approvedBy: value.approvedBy || null,
          approvedAt: value.approvedAt?.toDate().toISOString() || null};
      }),
      events: events.docs.map(doc => {
        const value = doc.data();
        return {id: doc.id, dateKey: value.dateKey, email: value.email, state: value.state,
          reason: value.reason, at: value.updatedAt?.toDate().toISOString() || null};
      })};
  });
  const updateReviewAutomation = onCall(options, async request => {
    const uid = await requireAdmin(request);
    const enabled = request.data?.enabled;
    const reviewUrl = typeof request.data?.reviewUrl === 'string' ? request.data.reviewUrl.trim() : '';
    if (typeof enabled !== 'boolean' || reviewUrl.length > 1500 ||
        ((enabled || reviewUrl) && !validReviewUrl(reviewUrl))) {
      throw new HttpsError('invalid-argument', 'Inserisci il link Google diretto “Chiedi recensioni”.');
    }
    await settings.set({enabled, reviewUrl, updatedAt: FieldValue.serverTimestamp(), updatedBy: uid}, {merge: true});
    return {success: true};
  });
  // At 11 only prepare a batch. Pending documents are realtime admin notifications.
  const prepareReviewRequests = onSchedule({...options, schedule:'0 11 * * *',timeZone:'Europe/Rome',
    timeoutSeconds:540,retryCount:3,maxRetrySeconds:1800,minBackoffSeconds:60}, async event => {
    const scheduled = new Date(event.scheduleTime);
    if (Number.isNaN(scheduled.getTime()) || previousBusinessDate(scheduled) !== previousBusinessDate(new Date())) return;
    const config = (await settings.get()).data() || {};
    if (!config.enabled || !validReviewUrl(config.reviewUrl)) return;
    const dateKey = previousBusinessDate(scheduled);
    const batch = batches.doc(dateKey);
    if ((await batch.get()).exists) return;
    const snapshot = await db.collection('bookings').where('dateKey','==',dateKey).get();
    const recipients = [], used = new Set();
    for (const doc of snapshot.docs) {
      const booking = doc.data(), target = contact(booking);
      if (!visitEligible(booking,dateKey) || !target || target.keys.some(k=>used.has(k))) continue;
      if ((await db.collection('review_requests').doc(doc.id).get()).exists) continue;
      const profile = db.collection('customer_profiles').doc(target.profileId);
      if (!await consents.eligible(profile,'email',target.email)) continue;
      const limits = await db.getAll(...target.keys.map(k=>db.collection('review_contact_limits').doc(k)));
      if (limits.some(l=>l.data()?.lastAttemptAt?.toMillis() > scheduled.getTime()-COOLDOWN_MS)) continue;
      target.keys.forEach(k=>used.add(k));
      recipients.push({bookingId:doc.id,email:target.email,phone:target.phone});
    }
    await db.runTransaction(async tx => {
      const [existing, current] = await tx.getAll(batch,settings);
      if (existing.exists || current.data()?.enabled !== true) return;
      tx.create(batch,{dateKey,recipients,state:recipients.length ? 'pending' : 'empty',
        createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    });
  });
  const approveReviewBatch = onCall(options, async request => {
    const uid = await requireAdmin(request);
    const id = request.data?.batchId;
    if (typeof id !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(id)) throw new HttpsError('invalid-argument','Richiesta non valida.');
    const ref = batches.doc(id);
    await db.runTransaction(async tx => {
      const [batch, config] = await tx.getAll(ref,settings);
      if (config.data()?.enabled !== true || !validReviewUrl(config.data()?.reviewUrl)) {
        throw new HttpsError('failed-precondition','Attiva la preparazione e verifica il link prima di autorizzare.');
      }
      if (batch.data()?.state !== 'pending') throw new HttpsError('failed-precondition','Richiesta già gestita o non disponibile.');
      tx.update(ref,{state:'approved',approvedBy:uid,approvedAt:FieldValue.serverTimestamp(),
        reviewUrl:config.data().reviewUrl,updatedAt:FieldValue.serverTimestamp()});
    });
    return {success:true};
  });
  const sendApprovedReviewBatch = onDocumentUpdated({...options,document:'review_batches/{batchId}',
    timeoutSeconds:540,retry:false,secrets:[gmailUser,gmailAppPassword]}, async event => {
    if (event.data?.after.data()?.state !== 'approved') return;
    const ref = event.data.after.ref;
    const selected = await db.runTransaction(async tx => {
      const snapshot = await tx.get(ref);
      const batch = snapshot.data();
      if (batch?.state !== 'approved' || !batch.approvedBy || !batch.approvedAt) return null;
      tx.update(ref,{state:'sending',updatedAt:FieldValue.serverTimestamp()});
      return batch;
    });
    if (!selected) return;
    try {
      const sender = mailTransport ? 'test@example.com' : gmailUser.value().trim();
      const transport = mailTransport || nodemailer.createTransport({service:'gmail',
        auth:{user:sender,pass:gmailAppPassword.value()},connectionTimeout:15000,greetingTimeout:15000,socketTimeout:30000});
      const run = createRunner({db,eligible:consents.eligible,unsubscribeLink:consents.emailUnsubscribeLink,
        isApproved:async () => (await ref.get()).data()?.state === 'sending',
        sendMail:data=>transport.sendMail({...data,from:`"Le Capase" <${sender}>`,replyTo:sender})});
      const totals = await run(new Date(),selected);
      await ref.update({state:totals.disabled || totals.paused || totals.uncertain ? 'attention' : 'completed',
        totals,updatedAt:FieldValue.serverTimestamp()});
    } catch (_) {
      await ref.update({state:'attention',updatedAt:FieldValue.serverTimestamp()});
    }
  });
  return {getReviewAutomation,updateReviewAutomation,prepareReviewRequests,approveReviewBatch,sendApprovedReviewBatch};
};
