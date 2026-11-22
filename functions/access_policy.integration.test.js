const {test, after} = require('node:test');
const assert = require('node:assert/strict');
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const app = initializeApp({projectId:'demo-lecapase-access-regression'});
const db = getFirestore();
const policy = require('./access_policy');
const api = require('./staff_users');
after(async()=>{await db.terminate();await deleteApp(app);});
test('current staff profile overrides legacy access and push recipients', async()=>{
  for (const [uid,role,active] of [
    ['admin','admin',true],['manager','manager',true],['supervisor','supervisor',true],
    ['staff','staff',true],['inactive','admin',false],['unknown','unknown',true],
  ]) {
    await db.collection('staff_users').doc(uid).set({role,active});
    await db.collection('admins').doc(uid).set({role:'admin',active:true,fcmTokens:[`${uid}-legacy`]});
    await db.collection('notification_devices').doc(uid).set({fcmTokens:[`${uid}-device`]});
  }
  await db.collection('admins').doc('legacy').set({role:'admin',active:true,fcmTokens:['legacy-device']});
  await db.collection('notification_devices').doc('deleted').set({fcmTokens:['deleted-device']});
  const tokens = await policy.notificationTokens(db);
  for (const uid of ['admin','manager','supervisor','staff']) assert.ok(tokens.includes(`${uid}-device`));
  for (const uid of ['inactive','unknown','deleted']) assert.ok(!tokens.some(t=>t.startsWith(uid)));
  assert.ok(tokens.includes('legacy-device'));
  const dateKey = new Date().toISOString().slice(0,10);
  for (const uid of ['inactive','unknown','deleted']) {
    await assert.rejects(api.getKitchenAgenda.run({auth:{uid},data:{dateKey}}),{code:'permission-denied'});
  }
  for (const uid of ['admin','manager','supervisor','staff','legacy']) {
    const result = await api.getKitchenAgenda.run({auth:{uid},data:{dateKey}});
    assert.deepEqual(result.bookings,[]);
  }
});
