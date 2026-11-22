// Run against the local Firestore emulator only:
// FIRESTORE_EMULATOR_HOST=127.0.0.1:8189 node test/firestore/historical_rules_test.cjs
const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8189';
assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/);
const project = 'demo-lecapase-tests';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const name = path => `projects/${project}/databases/(default)/documents/${path}`;
const value = v => v instanceof Date ? {timestampValue:v.toISOString()} : typeof v === 'boolean' ? {booleanValue:v} : typeof v === 'number' ? {integerValue:String(v)} : {stringValue:v};
const fields = data => Object.fromEntries(Object.entries(data).map(([k,v])=>[k,value(v)]));
function token(uid) {
 const enc = v => Buffer.from(JSON.stringify(v)).toString('base64url');
 return `${enc({alg:'none',typ:'JWT'})}.${enc({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom'}})}.`;
}
async function request(url, body, auth='owner', method='POST') {
 const res=await fetch(url,{method,headers:{'Content-Type':'application/json',...(auth?{Authorization:`Bearer ${auth}`}:{})},body:JSON.stringify(body)});
 return {status:res.status,body:await res.text()};
}
async function seed(path,data) {
 const r=await request(`${base}/${path}`,{fields:fields(data)},'owner','PATCH');
 assert.equal(r.status,200,r.body);
}

(async()=>{
 await seed('_system/current_business_date',{dateKey:new Date().toISOString().slice(0,10)});
 let checks=0;
 for(const role of ['admin','manager','supervisor','staff','inactive']) {
  const uid='notification-'+role;
  await seed('staff_users/'+uid,{active:role!=='inactive',role:role==='inactive'?'admin':role});
  for(const dateKey of ['2020-01-01',new Date().toISOString().slice(0,10)]) for(const dismiss of [false,true]) {
   await seed('bookings/notification-test',{dateKey,date:new Date(dateKey),status:'cancelled',source:'customer',adminNotificationRead:false,reconfirmationStatus:'cancelled',reconfirmationResultRead:false});
   const r=await request(base+':commit',{writes:[{update:{name:name('bookings/notification-test'),fields:fields({adminNotificationRead:true,reconfirmationResultRead:true,adminNotificationRetained:!dismiss})},currentDocument:{exists:true},updateMask:{fieldPaths:['adminNotificationRead','reconfirmationResultRead','adminNotificationRetained']},updateTransforms:['adminNotificationReadAt','reconfirmationResultReadAt','updatedAt',...(dismiss?['adminNotificationDismissedAt']:[])].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}]},token(uid));
   assert.equal(r.status,['admin','manager'].includes(role)?200:403,role+': '+r.body);checks++;
  }
 }
 console.log(checks+' notification read authorization checks passed.');
})().catch(e=>{console.error(e);process.exitCode=1;});
