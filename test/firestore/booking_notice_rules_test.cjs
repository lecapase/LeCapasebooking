const assert = require('node:assert/strict');
const {booking, timestamps} = require('./customer_booking_fixture');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host || '', /^(127\.0\.0\.1|localhost):\d+$/);
const project = 'demo-lecapase-tests';
const root = `projects/${project}/databases/(default)/documents`;
const base = `http://${host}/v1/${root}`;
const run = Date.now();
function field(v) {
  if (v === null) return {nullValue:null};
  if (v instanceof Date) return {timestampValue:v.toISOString()};
  if (typeof v === 'boolean') return {booleanValue:v};
  if (typeof v === 'number') return {integerValue:String(v)};
  return {stringValue:v};
}
async function create(id, data, token) {
  return fetch(`${base}:commit`, {method:'POST', headers:{'Content-Type':'application/json',
    ...(token ? {Authorization:`Bearer ${token}`} : {})}, body:JSON.stringify({writes:[{
      update:{name:`${root}/bookings/notice-${run}-${id}`, fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,field(v)]))},
      updateTransforms:timestamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'})),
    }]})});
}
function slot(instant) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-GB', {
    timeZone:'Europe/Rome',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23',
  }).formatToParts(instant).map(p=>[p.type,p.value]));
  return {dateKey:`${parts.year}-${parts.month}-${parts.day}`,time:`${parts.hour}:${parts.minute}`};
}
async function check(response, status) {assert.equal(response.status,status,await response.text());}
(async () => {
  // Use the emulator's request time, independent of the test machine clock.
  const probe = await create('clock',booking,'owner');
  assert.equal(probe.status,200);
  const clock = new Date((await probe.json()).commitTime).getTime();
  const minute = Math.floor(clock / 60000) * 60000;
  for (const [offset, status] of [[-5,403],[0,403],[44,403],[46,200],[120,200],[1440,200]]) {
    // A forged far-future `date` must not bypass the selected dateKey/time.
    await check(await create(offset,{...booking,...slot(new Date(minute+offset*60000))}),status);
  }
  await check(await create('invalid-hour',{...booking,time:'29:00'}),403);
  await check(await create('invalid-date',{...booking,dateKey:'2099-99-99'}),403);
  const enc = v=>Buffer.from(JSON.stringify(v)).toString('base64url');
  const uid = `notice-manager-${run}`;
  await check(await fetch(`${base}/staff_users/${uid}`, {method:'PATCH', headers:{Authorization:'Bearer owner','Content-Type':'application/json'},
    body:JSON.stringify({fields:{role:{stringValue:'manager'},active:{booleanValue:true}}})}),200);
  const token = `${enc({alg:'none',typ:'JWT'})}.${enc({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom'}})}.`;
  await check(await create('manual',{...booking,...slot(new Date(minute+10*60000)),source:'manual'},token),200);
  console.log('9 booking notice rules checks passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
