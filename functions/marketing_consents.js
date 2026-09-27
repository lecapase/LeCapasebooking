const crypto = require('node:crypto');
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const policy = require('./consent_policy');
const db = getFirestore();
const profiles = db.collection('customer_profiles');
function suppressionRef(profile, channel) {
  const value = policy.address(profile, channel);
  return value ? db.collection('marketing_suppressions').doc(policy.hash(`${channel}:${value}`)) : null;
}
async function revocationEvidence(profile, channel, transaction = null) {
  const read = ref => transaction ? transaction.get(ref) : ref.get();
  const ref = suppressionRef(profile, channel);
  if (!ref) return null;
  const explicit = await read(ref);
  if (explicit.exists) return explicit.data();
  // Honor documented legacy opt-outs even on another profile with the same contact.
  const field = channel === 'email' ? 'normalizedEmail' : 'normalizedPhone';
  const matches = await read(profiles.where(field, '==', policy.address(profile, channel)));
  const p = policy.prefix(channel);
  for (const doc of matches.docs) {
    const data = doc.data();
    const revokedAt = data[`${p}RevokedAt`] || data.marketingOptOutAt;
    if (revokedAt) return {revokedAt, source: data[`${p}RevokedSource`] || data.marketingOptOutSource};
  }
  return null;
}
async function requireManager(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Accedi al gestionale.');
  const [staff, legacy] = await Promise.all([
    db.collection('staff_users').doc(uid).get(), db.collection('admins').doc(uid).get(),
  ]);
  if (!(staff.data()?.active === true && ['admin', 'manager'].includes(staff.data()?.role)) &&
      !(legacy.data()?.active === true && legacy.data()?.role === 'admin')) {
    throw new HttpsError('permission-denied', 'Operazione riservata a Manager e Amministratore.');
  }
  return uid;
}
function profileId(data) {
  if (typeof data.profileId === 'string' && /^[a-f0-9]{64}$/.test(data.profileId)) return data.profileId;
  const key = data.customerKey;
  if (typeof key !== 'string' || key.length > 400 || !/^(phone|email)_.+/.test(key)) {
    throw new HttpsError('invalid-argument', 'Contatto non identificabile.');
  }
  return policy.hash(key.replace(/^(phone|email)_/, '$1:'));
}
function identityFromKey(key) {
  if (typeof key !== 'string') return {};
  if (key.startsWith('phone_')) return {normalizedPhone: key.slice(6)};
  if (key.startsWith('email_')) return {normalizedEmail: key.slice(6)};
  return {};
}
function iso(value) { return value?.toDate ? value.toDate().toISOString() : null; }
async function revoke(ref, channels, source, actor, identity = {}) {
  const eventRefs = channels.map(() => ref.collection('consent_events').doc());
  await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const profile = {...identity, ...snapshot.data()};
    const patch = {...(snapshot.exists ? {} : identity), updatedAt: FieldValue.serverTimestamp()};
    for (const [i, channel] of channels.entries()) {
      const p = policy.prefix(channel);
      patch[`${p}Consent`] = false;
      patch[`${p}RevokedAt`] = FieldValue.serverTimestamp();
      patch[`${p}RevokedSource`] = source;
      const suppression = suppressionRef(profile, channel);
      if (suppression) tx.set(suppression, {revokedAt: FieldValue.serverTimestamp(), source});
      tx.set(eventRefs[i], {channel, state: 'revoked', source, actor,
        at: FieldValue.serverTimestamp(), version: profile[`${p}ConsentVersion`] || profile.marketingConsentVersion || null});
    }
    tx.set(ref, patch, {merge: true});
  });
}
async function eligible(ref, channel, expectedAddress) {
  const profile = (await ref.get()).data() || {};
  return policy.address(profile, channel) === expectedAddress &&
    policy.consentState(profile, channel, !!await revocationEvidence(profile, channel)) === 'granted';
}
async function emailUnsubscribeLink(ref, email) {
  const token = crypto.randomBytes(32).toString('hex');
  await db.collection('marketing_unsubscribe_tokens').doc(policy.hash(token)).set({
    profileId: ref.id, email, createdAt: FieldValue.serverTimestamp(),
  });
  return `https://europe-west1-lecapase-booking-3af33.cloudfunctions.net/marketingUnsubscribe?token=${token}`;
}
const getCustomerConsents = onCall({region: 'europe-west1', maxInstances: 10}, async request => {
  await requireManager(request);
  const ref = profiles.doc(profileId(request.data || {}));
  const profile = {...identityFromKey(request.data?.customerKey), ...(await ref.get()).data()};
  const result = {};
  for (const channel of ['email', 'whatsapp']) {
    const p = policy.prefix(channel);
    const suppression = await revocationEvidence(profile, channel);
    result[channel] = {
      state: policy.consentState(profile, channel, !!suppression),
      at: iso(suppression?.revokedAt || profile[`${p}RevokedAt`] || profile.marketingOptOutAt || profile[`${p}ConsentAt`]),
      source: suppression?.source || profile[`${p}RevokedSource`] || profile.marketingOptOutSource || profile[`${p}ConsentSource`] || null,
      version: profile[`${p}ConsentVersion`] || profile.marketingConsentVersion || null,
    };
  }
  const events = await ref.collection('consent_events').orderBy('at', 'desc').limit(50).get();
  result.events = events.docs.map(doc => {
    const e = doc.data();
    return {channel: e.channel, state: e.state, at: iso(e.at), source: e.source, version: e.version};
  });
  return result;
});
const revokeCustomerConsent = onCall({region: 'europe-west1', maxInstances: 10}, async request => {
  const uid = await requireManager(request);
  const data = request.data || {};
  const channels = data.channel === 'both' ? ['email', 'whatsapp'] : [data.channel];
  if (channels.some(c => !['email', 'whatsapp'].includes(c))) throw new HttpsError('invalid-argument', 'Canale non valido.');
  await revoke(profiles.doc(profileId(data)), channels, 'staff_customer_request', uid, identityFromKey(data.customerKey));
  return {success: true};
});
const marketingUnsubscribe = onRequest({cors: false, region: 'europe-west1', maxInstances: 10}, async (req, res) => {
  res.set('Cache-Control', 'no-store').set('Referrer-Policy', 'no-referrer')
      .set('X-Content-Type-Options', 'nosniff');
  if (!['GET', 'POST'].includes(req.method)) return res.status(405).send('Metodo non consentito');
  const token = req.query.token;
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) return res.status(400).send('Link non valido');
  try {
    const record = (await db.collection('marketing_unsubscribe_tokens').doc(policy.hash(token)).get()).data();
    if (!record) return res.status(400).send('Link non valido');
    if (req.method === 'GET') {
      return res.type('html').send('<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Le Capase — Disiscrizione</title><body><h1>Disiscrizione email promozionali</h1><p>Le comunicazioni relative alle prenotazioni restano attive.</p><form method="post"><button type="submit">Conferma disiscrizione</button></form></body></html>');
    }
    await revoke(profiles.doc(record.profileId), ['email'], 'email_unsubscribe', 'customer', {normalizedEmail: record.email});
    // Also suppress the original recipient if the profile address changed since the email was sent.
    await db.collection('marketing_suppressions').doc(policy.hash(`email:${record.email}`))
        .set({revokedAt: FieldValue.serverTimestamp(), source: 'email_unsubscribe'});
    return res.type('html').send('<!doctype html><html lang="it"><meta charset="utf-8"><title>Le Capase</title><h1>Disiscrizione completata</h1><p>Non riceverai più email promozionali.</p></html>');
  } catch (_) { return res.status(503).send('Operazione non riuscita. Riprova.'); }
});
module.exports = {getCustomerConsents, revokeCustomerConsent, marketingUnsubscribe,
  revoke, eligible, emailUnsubscribeLink, suppressionRef, revocationEvidence};
