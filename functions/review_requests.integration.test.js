// Emulator only; the mail transport is a fake and cannot send email.
const {test, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const app = initializeApp({projectId:'demo-lecapase-reviews'});
const db = getFirestore();
const {createRunner, contact, COOLDOWN_MS, previousBusinessDate} = require('./review_requests');
const consents = require('./marketing_consents');
const url = 'https://g.page/r/CVT1Lz6T5_JyEBM/review';
const now = new Date('2026-09-27T09:00:00Z');
const config = db.collection('_system').doc('review_automation');
beforeEach(async () => {
  const res = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-lecapase-reviews/databases/(default)/documents`, {method:'DELETE'});
  assert.equal(res.status,200);
  await config.set({enabled:true,reviewUrl:url});
});
after(async () => { await db.terminate(); await deleteApp(app); });
async function seed(id, patch = {}) {
  const b = {dateKey:'2026-09-26',status:'released',email:'guest@example.com',telefono:'3331234567',...patch};
  await db.collection('bookings').doc(id).set(b);
  const target = contact(b);
  if (target) await db.collection('customer_profiles').doc(target.profileId).set({
    normalizedEmail:target.email, normalizedPhone:target.phone,
    marketingEmailConsent:true, marketingEmailConsentAt:Timestamp.now(),
    marketingEmailConsentSource:'customer_booking', marketingEmailConsentVersion:'2.0',
  });
  return b;
}
function runner(sent, overrides = {}) {
  return createRunner({db,eligible:consents.eligible,unsubscribeLink:async ()=>'https://example.com/unsubscribe',
    isApproved:async()=>true,
    sendMail:async mail => {sent.push(mail);return {accepted:[mail.to],messageId:'fake'};},...overrides});
}
async function state(id) { return (await db.collection('review_requests').doc(id).get()).data()?.state; }
test('disabled by default and invalid configuration never sends', async () => {
  await seed('a'); const sent=[];
  await config.delete(); await runner(sent)(now);
  await config.set({enabled:true,reviewUrl:'https://evil.example'}); await runner(sent)(now);
  assert.equal(sent.length,0);
});
test('concurrent runs and repeated executions send at most once per booking/contact', async () => {
  await seed('a'); await seed('b'); const sent=[];
  const run = runner(sent);
  await Promise.all([run(now),run(now)]);
  await run(now);
  assert.equal(sent.length,1);
  assert.deepEqual([await state('a'),await state('b')].sort(),['sent','skipped']);
});
test('cooldown covers shared phone and email, with exact 90-day boundary', async () => {
  const b = await seed('a'); const sent=[];
  const lock = db.collection('review_contact_limits').doc(contact(b).keys[1]);
  await lock.set({lastAttemptAt:Timestamp.fromMillis(now.getTime()-COOLDOWN_MS+1)});
  await runner(sent)(now); assert.equal(sent.length,0);
  await seed('b');
  await lock.set({lastAttemptAt:Timestamp.fromMillis(now.getTime()-COOLDOWN_MS)});
  await runner(sent)(now); assert.equal(sent.length,1);
});
test('excludes non-visits, older dates, missing email and revoked consent', async () => {
  await seed('cancelled',{status:'cancelled'});
  await seed('arrived',{status:'arrived'});
  await seed('old',{dateKey:'2026-09-25'});
  await seed('noemail',{email:''});
  const b=await seed('revoked');
  await consents.revoke(db.collection('customer_profiles').doc(contact(b).profileId),['email'],'test','test');
  const sent=[]; await runner(sent)(now);
  assert.equal(sent.length,0);
  assert.equal(await state('cancelled'),undefined);
  assert.equal(await state('noemail'),'skipped');
  assert.equal(await state('revoked'),'skipped');
});
test('pause and revocation after claim stop delivery', async () => {
  const b=await seed('a'); const sent=[];
  await runner(sent,{unsubscribeLink:async () => {
    await consents.revoke(db.collection('customer_profiles').doc(contact(b).profileId),['email'],'test','test');
    return 'https://example.com/unsubscribe';
  }})(now);
  assert.equal(sent.length,0); assert.equal(await state('a'),'skipped');
  await seed('b',{email:'other@example.com',telefono:'4441234567'});
  await runner(sent,{unsubscribeLink:async () => {
    await config.update({enabled:false});return 'https://example.com/unsubscribe';
  }})(now);
  assert.equal(sent.length,0); assert.equal(await state('b'),'skipped');
});
test('uncertain provider outcome is retained and never retried automatically', async () => {
  await seed('a'); const sent=[];
  const run=runner(sent,{sendMail:async mail=>{sent.push(mail);throw new Error('timeout after acceptance');}});
  await run(now); await run(now);
  assert.equal(sent.length,1); assert.equal(await state('a'),'uncertain');
});
test('settings API requires active administrator and validates the review URL', async () => {
  const {defineSecret} = require('firebase-functions/params');
  const api = require('./review_automation')({db,consents,gmailUser:defineSecret('GMAIL_USER'),gmailAppPassword:defineSecret('GMAIL_APP_PASSWORD')});
  await assert.rejects(api.getReviewAutomation.run({data:{}}),{code:'unauthenticated'});
  await db.collection('staff_users').doc('staff').set({role:'staff',active:true});
  await assert.rejects(api.updateReviewAutomation.run({auth:{uid:'staff'},data:{enabled:true,reviewUrl:url}}),{code:'permission-denied'});
  await db.collection('staff_users').doc('manager').set({role:'manager',active:true});
  await assert.rejects(api.updateReviewAutomation.run({auth:{uid:'manager'},data:{enabled:true,reviewUrl:url}}),{code:'permission-denied'});
  await db.collection('staff_users').doc('admin').set({role:'admin',active:true});
  await assert.rejects(api.updateReviewAutomation.run({auth:{uid:'admin'},data:{enabled:true,reviewUrl:'https://evil.example'}}),{code:'invalid-argument'});
  await api.updateReviewAutomation.run({auth:{uid:'admin'},data:{enabled:false,reviewUrl:url}});
  assert.equal((await api.getReviewAutomation.run({auth:{uid:'admin'},data:{}})).enabled,false);
});
test('no approval means no send, even with valid config and consent', async () => {
  await seed('a'); const sent=[];
  await runner(sent,{isApproved:async()=>false})(now);
  assert.equal(sent.length,0);
});
test('11am prepares a persistent notification; one of two admins can authorize exactly once', async () => {
  const day=previousBusinessDate(new Date());
  await seed('a',{dateKey:day}); const sent=[];
  const {defineSecret}=require('firebase-functions/params');
  const api=require('./review_automation')({db,consents,gmailUser:defineSecret('GMAIL_USER'),gmailAppPassword:defineSecret('GMAIL_APP_PASSWORD'),
    mailTransport:{sendMail:async mail=>{sent.push(mail);return {accepted:[mail.to],messageId:'fake'};}}});
  await api.prepareReviewRequests.run({scheduleTime:new Date().toISOString()});
  await api.prepareReviewRequests.run({scheduleTime:new Date().toISOString()});
  const ref=db.collection('review_batches').doc(day);
  assert.equal((await ref.get()).data().state,'pending');
  assert.equal((await ref.get()).data().recipients.length,1);
  await api.sendApprovedReviewBatch.run({data:{after:await ref.get()}});
  assert.equal(sent.length,0);
  await db.collection('staff_users').doc('manager').set({role:'manager',active:true});
  await assert.rejects(api.approveReviewBatch.run({auth:{uid:'manager'},data:{batchId:day}}),{code:'permission-denied'});
  for (const uid of ['admin1','admin2']) await db.collection('staff_users').doc(uid).set({role:'admin',active:true});
  const approvals=await Promise.allSettled(['admin1','admin2'].map(uid=>api.approveReviewBatch.run({auth:{uid},data:{batchId:day}})));
  assert.equal(approvals.filter(r=>r.status==='fulfilled').length,1);
  const approved=await ref.get();
  assert.ok(approved.data().approvedBy);
  assert.ok(approved.data().approvedAt);
  // New bookings after preparation are not covered by the approval.
  await seed('late',{dateKey:day,email:'late@example.com',telefono:'4441234567'});
  await Promise.all([api.sendApprovedReviewBatch.run({data:{after:approved}}),api.sendApprovedReviewBatch.run({data:{after:approved}})]);
  assert.equal(sent.length,1);
  assert.equal(sent[0].to,'guest@example.com');
  assert.equal((await ref.get()).data().state,'completed');
});
test('changed recipient is not covered by the original approval', async () => {
  const b=await seed('a'); const sent=[];
  await runner(sent)(now,{dateKey:b.dateKey,reviewUrl:url,recipients:[{bookingId:'a',email:'old@example.com',phone:contact(b).phone}]});
  assert.equal(sent.length,0);
  assert.equal(await state('a'),'skipped');
});
