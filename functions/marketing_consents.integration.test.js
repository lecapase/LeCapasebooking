// Local emulator only. No messages are sent.
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const app = initializeApp({projectId: 'demo-lecapase-consents'});
const db = getFirestore();
const api = require('./marketing_consents');
const policy = require('./consent_policy');
const key = 'phone_393331234567';
const ref = db.collection('customer_profiles').doc(policy.hash('phone:393331234567'));
const email = 'consent-test@example.com';
const evidence = {normalizedPhone: '393331234567', normalizedEmail: email,
  marketingEmailConsent: true, marketingEmailConsentAt: Timestamp.now(),
  marketingEmailConsentSource: 'customer_booking', marketingEmailConsentVersion: '2.0',
  marketingWhatsappConsent: true, marketingWhatsappConsentAt: Timestamp.now(),
  marketingWhatsappConsentSource: 'customer_booking', marketingWhatsappConsentVersion: '2.0'};
after(async () => { await db.terminate(); await deleteApp(app); });
before(async () => {
  const response = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-lecapase-consents/databases/(default)/documents`, {method: 'DELETE'});
  assert.equal(response.status, 200);
});
test('authorization, independent revocation, duplicate-address suppression and audit', async () => {
  await db.collection('staff_users').doc('manager').set({active: true, role: 'manager'});
  await db.collection('staff_users').doc('staff').set({active: true, role: 'staff'});
  await db.collection('staff_users').doc('inactive').set({active: false, role: 'admin'});
  await ref.set(evidence);
  await assert.rejects(api.getCustomerConsents.run({data: {customerKey: key}}), {code: 'unauthenticated'});
  for (const uid of ['staff', 'inactive']) {
    await assert.rejects(api.revokeCustomerConsent.run({auth: {uid}, data: {customerKey: key, channel: 'email'}}), {code: 'permission-denied'});
  }
  const request = {auth: {uid: 'manager'}, data: {customerKey: key}};
  const original = await api.getCustomerConsents.run(request);
  assert.equal(original.email.state, 'granted');
  assert.equal(original.whatsapp.state, 'granted');
  await assert.rejects(api.revokeCustomerConsent.run({...request, data: {...request.data, channel: 'sms'}}), {code: 'invalid-argument'});
  await api.revokeCustomerConsent.run({...request, data: {...request.data, channel: 'whatsapp'}});
  const changed = await api.getCustomerConsents.run(request);
  assert.equal(changed.email.state, 'granted');
  assert.equal(changed.whatsapp.state, 'revoked');
  assert.equal(changed.events.length, 1);
  assert.equal(await api.eligible(ref, 'email', email), true);
  assert.equal(await api.eligible(ref, 'whatsapp', '393331234567'), false);
  const duplicate = db.collection('customer_profiles').doc('duplicate');
  await duplicate.set(evidence);
  assert.equal(await api.eligible(duplicate, 'whatsapp', '393331234567'), false);
  await api.revokeCustomerConsent.run({...request, data: {...request.data, channel: 'email'}});
  assert.equal(await api.eligible(duplicate, 'email', email), false);
  assert.equal((await api.getCustomerConsents.run(request)).events.length, 2);
});
test('unsubscribe link token is opaque, stored hashed, and GET does not revoke', async t => {
  const fresh = db.collection('customer_profiles').doc('f'.repeat(64));
  await fresh.set({...evidence, normalizedEmail: 'fresh@example.com'});
  const link = await api.emailUnsubscribeLink(fresh, 'fresh@example.com');
  const token = new URL(link).searchParams.get('token');
  assert.match(token, /^[a-f0-9]{64}$/);
  assert.equal((await db.collection('marketing_unsubscribe_tokens').doc(token).get()).exists, false);
  const express = require('express');
  const web = express();
  web.use(api.marketingUnsubscribe);
  const server = await new Promise(resolve => {
    const instance = web.listen(0, '127.0.0.1', () => resolve(instance));
  });
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/?token=${token}`;
  const page = await fetch(url);
  assert.equal(page.status, 200);
  assert.match(await page.text(), /form method="post"/);
  assert.equal(await api.eligible(fresh, 'email', 'fresh@example.com'), true);
  const submitted = await fetch(url, {method: 'POST'});
  assert.equal(submitted.status, 200);
  assert.equal(await api.eligible(fresh, 'email', 'fresh@example.com'), false);
  assert.equal((await fresh.get()).data().marketingWhatsappConsent, true);
  assert.equal((await fetch(url.replace(token, 'bad'), {method: 'POST'})).status, 400);
});
test('legacy revocation on a duplicate contact prevents future grants and sending', async () => {
  const email = 'legacy@example.com';
  await db.collection('customer_profiles').doc('legacy-optout').set({normalizedEmail:email,
    marketingOptOutAt:Timestamp.now(),marketingOptOutSource:'admin_removed'});
  const candidate = db.collection('customer_profiles').doc('legacy-candidate');
  await candidate.set({...evidence,normalizedEmail:email});
  assert.equal(await api.eligible(candidate,'email',email),false);
  await db.runTransaction(async tx => {
    const suppression = await api.revocationEvidence({normalizedEmail:email},'email',tx);
    assert.ok(suppression);
    assert.equal(policy.canRecordGrant({}, {marketingEmailConsent:true,marketingConsentRecordedAt:Timestamp.now(),
      marketingConsentVersion:'2.0',marketingConsentSource:'customer_booking'},'email',!!suppression),false);
  });
});
