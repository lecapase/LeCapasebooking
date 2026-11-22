const assert = require('node:assert/strict');
const {booking, timestamps} = require('./customer_booking_fixture');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host || '', /^(127\.0\.0\.1|localhost):\d+$/);
const project = 'demo-lecapase-counter-regression';
const root = `projects/${project}/databases/(default)/documents`;
const base = `http://${host}/v1/${root}`;
const field = value => value === null ? {nullValue:null} : value instanceof Date ? {timestampValue:value.toISOString()} :
  typeof value === 'number' ? {integerValue:String(value)} : typeof value === 'boolean' ? {booleanValue:value} : {stringValue:value};
const write = (path, data, transforms = []) => ({update:{name:`${root}/${path}`,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,field(v)]))},
  ...(transforms.length ? {updateTransforms:transforms.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {})});
const counter = (id, count, path = '2099-01-01_dinner') => write(`availability_counters/${path}`, {
  dateKey:booking.dateKey, weekday:booking.weekday, service:booking.service,
  bookedGuests:count,lastBookingId:id,
}, ['updatedAt']);
async function commit(writes, expected, owner = false) {
  const response = await fetch(`${base}:commit`, {method:'POST',headers:{'Content-Type':'application/json',...(owner?{Authorization:'Bearer owner'}:{})},body:JSON.stringify({writes})});
  assert.equal(response.status,expected,await response.text());
}
(async()=>{
  await commit([write('_system/current_business_date',{dateKey:'2026-09-27'})],200,true);
  await commit([write('bookings/a',booking,timestamps),counter('a',2)],200);
  await commit([counter('a',4)],403);
  await commit([counter('a',4)],403);
  await commit([write('bookings/b',booking,timestamps),counter('b',4)],200);
  await commit([write('bookings/c',booking,timestamps),counter('c',2,'wrong-counter')],403);
  await commit([counter('missing',6)],403);
  await commit([counter('a',2,'another-counter')],403);
  const result = await (await fetch(`${base}/availability_counters/2099-01-01_dinner`)).json();
  assert.equal(result.fields.bookedGuests.integerValue,'4');
  console.log('8 counter rules checks passed (valid creation, increment, replay, wrong ID and missing booking).');
})().catch(error=>{console.error(error);process.exitCode=1;});
