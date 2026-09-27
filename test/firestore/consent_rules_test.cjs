const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host || '', /^(127\.0\.0\.1|localhost):\d+$/);
const project = 'demo-lecapase-tests';
const root = `projects/${project}/databases/(default)/documents`;
const base = `http://${host}/v1/${root}`;
const run = Date.now();
const enc = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const auth = `${enc({alg:'none',typ:'JWT'})}.${enc({sub:'admin',user_id:'admin',aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom'}})}.`;
function field(v) {
  if (v === null) return {nullValue: null};
  if (v instanceof Date) return {timestampValue: v.toISOString()};
  if (typeof v === 'boolean') return {booleanValue:v};
  if (typeof v === 'number') return {integerValue:String(v)};
  return {stringValue:v};
}
async function commit(path, data, token, transforms = []) {
  if (path.startsWith('bookings/')) path += `-${run}`;
  return fetch(`${base}:commit`, {method:'POST', headers:{'Content-Type':'application/json', ...(token ? {Authorization:`Bearer ${token}`} : {})},
    body: JSON.stringify({writes:[{update:{name:`${root}/${path}`,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,field(v)]))},
      ...(transforms.length ? {updateTransforms:transforms.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {})}]})});
}
async function expectStatus(response, status) {assert.equal(response.status,status,await response.text());}
(async () => {
  await expectStatus(await commit('staff_users/admin', {active:true,role:'admin'}, 'owner'), 200);
  for (const path of ['customer_profiles/consent-rule-test', 'customer_profiles/consent-rule-test/consent_events/test',
    'marketing_suppressions/consent-rule-test', 'marketing_unsubscribe_tokens/consent-rule-test']) {
    await expectStatus(await commit(path,{marketingEmailConsent:true},auth),403);
    await expectStatus(await commit(path,{marketingEmailConsent:true},null),403);
  }
  const b = {nome:'Test',cognome:'Cliente',email:'test@example.com',normalizedEmail:'test@example.com',telefono:'3331234567',normalizedPhone:'393331234567',customerKey:'phone_393331234567',
    date:new Date('2099-01-01T00:00:00Z'),dateKey:'2099-01-01',weekday:4,time:'20:00',service:'dinner',guests:2,occasion:'',occasionCode:'none',language:'it',notes:'',
    healthDataDetected:false,healthDataConsent:false,healthDataConsentVersion:'1.0',healthDataConsentLanguage:'it',notesPurgedAt:null,healthDataConsentRecordedAt:null,
    source:'customer',bookingOrigin:'direct',privacyNoticeAccepted:true,privacyNoticeVersion:'1.0',privacyNoticeLanguage:'it',
    bookingWhatsappConsent:true,bookingWhatsappConsentVersion:'1.0',bookingWhatsappConsentSource:'customer_booking_submit',
    marketingEmailConsent:true,marketingWhatsappConsent:false,marketingConsentVersion:'2.0',marketingConsentSource:'customer_booking',
    status:'booked',autoBooked:true,autoConfirmed:true,requiresManualConfirmation:false,
    bookedBy:'automatic',confirmedAt:null,confirmedBy:null,cancelledAt:null,cancelledBy:null,
    noShowAt:null,noShowBy:null,noShowRecorded:false,requestReceivedEmailSent:false,
    confirmationEmailSent:false,cancellationEmailSent:false,rejectionEmailSent:false,
    confirmationWhatsappSent:false,cancellationWhatsappSent:false,rejectionWhatsappSent:false,adminNotificationSent:false};
  const timestamps=['privacyNoticeAcceptedAt','bookingWhatsappConsentRecordedAt','marketingConsentRecordedAt','createdAt','updatedAt','bookedAt'];
  assert.equal(Object.keys(b).length + timestamps.length, 61);
  for (const [email, whatsapp] of [[true,false],[false,true],[false,false],[true,true]]) {
    await expectStatus(await commit(`bookings/consent-${email}-${whatsapp}`,{...b,marketingEmailConsent:email,marketingWhatsappConsent:whatsapp},null,timestamps),200);
  }
  await expectStatus(await commit('bookings/consent-forged',{...b,marketingConsentRecordedAt:new Date('2020-01-01')},null,timestamps.filter(t=>t!=='marketingConsentRecordedAt')),403);
  await expectStatus(await commit('bookings/consent-legacy',{...b,marketingEmailConsent:true,marketingWhatsappConsent:true,marketingConsentVersion:'1.0'},null,timestamps),200);
  console.log('14 consent rules checks passed.');
})().catch(e=>{console.error(e);process.exitCode=1;});
