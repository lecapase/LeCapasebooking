// Diagnostic reproducer: LOCAL EMULATOR ONLY. Never connects to production.
const assert = require('node:assert/strict');
const functionRequire = require('node:module').createRequire(require('node:path').resolve(__dirname, '../functions/package.json'));
const {initializeApp, deleteApp} = functionRequire('firebase-admin/app');
const {getFirestore} = functionRequire('firebase-admin/firestore');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host || '', /^(127\.0\.0\.1|localhost):\d+$/);
const project = 'demo-lecapase-general-audit';
const app = initializeApp({projectId: project});
const db = getFirestore();
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const fields = data => Object.fromEntries(Object.entries(data).map(([key, value]) =>
  [key, typeof value === 'number' ? {integerValue:String(value)} : {stringValue:value}]));
async function patch(path, data, owner = false) {
  const response = await fetch(`${base}/${path}`, {
    method:'PATCH', headers:{'Content-Type':'application/json', ...(owner ? {Authorization:'Bearer owner'} : {})},
    body:JSON.stringify({fields:fields(data)}),
  });
  const body = await response.json();
  return {status:response.status, body};
}
(async () => {
  const booking = {source:'customer',dateKey:'2099-01-01',weekday:4,service:'dinner',guests:2};
  await db.collection('bookings').doc('audit-existing-booking').set(booking);
  const counter = {dateKey:booking.dateKey,weekday:4,service:'dinner',bookedGuests:2,lastBookingId:'audit-existing-booking',updatedAt:'audit'};
  await db.collection('availability_counters').doc('2099-01-01_dinner').set(counter);
  const replay = await patch('availability_counters/2099-01-01_dinner', {...counter,bookedGuests:4});
  const repeated = await patch('availability_counters/2099-01-01_dinner', {...counter,bookedGuests:6});
  console.log(JSON.stringify({check:'anonymous counter replay without a new booking',expected:403,actual:[replay.status,repeated.status],bookedGuests:(await db.collection('availability_counters').doc('2099-01-01_dinner').get()).data().bookedGuests}));

  const uid = 'audit-revoked-admin';
  await db.collection('staff_users').doc(uid).set({active:false,role:'admin'});
  await db.collection('admins').doc(uid).set({active:true,role:'admin'});
  const dateKey = new Date().toISOString().slice(0,10);
  await db.collection('bookings').doc('audit-kitchen').set({dateKey,status:'booked',nome:'Synthetic audit guest',notes:'Synthetic private note',guests:2,time:'20:00',service:'dinner'});
  const api = require('../functions/staff_users');
  try {
    const result = await api.getKitchenAgenda.run({auth:{uid},data:{dateKey}});
    console.log(JSON.stringify({check:'revoked staff with legacy admin accesses kitchen agenda',expected:'permission-denied',actual:'allowed',records:result.bookings.length}));
  } catch (error) {
    console.log(JSON.stringify({check:'revoked staff with legacy admin accesses kitchen agenda',expected:'permission-denied',actual:error.code}));
  }
  // Execute only the token-selection helper, never a sender or a trigger.
  await db.collection('notification_devices').doc(uid).set({fcmTokens:['synthetic-disabled-token']});
  const tokens = await require('../functions/access_policy').notificationTokens(db);
  console.log(JSON.stringify({check:'disabled account remains a push recipient',expected:false,actual:tokens.includes('synthetic-disabled-token')}));
})().catch(error => {console.error(error);process.exitCode=1;}).finally(async () => {await db.terminate();await deleteApp(app);});
