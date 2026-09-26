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
let passed=0;
async function change(label,{role='manager',status='arrived',extra={},deny=false,oldStatus='booked',date='2020-01-01',badAudit=false,counter=false}={}) {
 await seed('bookings/history',{dateKey:date,date:new Date(`${date}T00:00:00Z`),status:oldStatus,guests:4,time:'20:00',service:'dinner',notes:'original',nome:'Test'});
 const audit={arrived:'arrived',released:'released',no_show:'noShow'}[status];
 const data={status,...(audit?{[`${audit}By`]:'admin'}:{}),...extra};
 const transforms=['updatedAt',...(audit?[`${audit}At`]:[])].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}));
 if(badAudit) {data.updatedAt='forged';transforms.shift();}
 const writes=[{update:{name:name('bookings/history'),fields:fields(data)},currentDocument:{exists:true},updateMask:{fieldPaths:Object.keys(data)},updateTransforms:transforms}];
 if(counter){
   await seed('availability_counters/2020-01-01_dinner',{dateKey:'2020-01-01',service:'dinner',bookedGuests:4});
   writes.push({update:{name:name('availability_counters/2020-01-01_dinner'),fields:fields({bookedGuests:0})},updateMask:{fieldPaths:['bookedGuests']}});
 }
 const r=await request(`${base}:commit`,{writes},role==='anonymous'?null:token(role));
 assert.equal(r.status,deny?403:200,`${label}: ${r.body}`);
 console.log(`PASS ${label}`);passed++;
}
(async()=>{
 await seed('_system/current_business_date',{dateKey:new Date().toISOString().slice(0,10)});
 for(const role of ['admin','manager','supervisor','staff','inactive'])await seed(`staff_users/${role}`,{active:role!=='inactive',role:role==='inactive'?'manager':role});
 for(const role of ['admin','manager'])for(const status of ['arrived','released','no_show'])await change(`${role} corrects ${status}`,{role,status});
 for(const oldStatus of ['arrived','released','no_show'])for(const status of ['arrived','released','no_show'])if(oldStatus!==status)await change(`${oldStatus} -> ${status}`,{oldStatus,status});
 for(const status of ['booked','confirmed','cancelled','rejected','pending','completed'])await change(`reject historical ${status}`,{status,deny:true});
 for(const [key,v] of Object.entries({dateKey:'2026-09-28',date:new Date('2026-09-28'),time:'21:00',guests:8,service:'lunch',notes:'changed',nome:'Other',noShowRecorded:true,confirmedBy:'admin'}))await change(`reject structural ${key}`,{extra:{[key]:v},deny:true});
 for(const role of ['supervisor','staff','inactive','anonymous','unknown'])await change(`reject ${role}`,{role,deny:true});
 await change('reject forged timestamp',{badAudit:true,deny:true});
 await change('status and counter in one atomic commit',{status:'released',counter:true});
 await change('current booking workflow still allowed',{date:new Date().toISOString().slice(0,10),status:'confirmed'});
 const r=await request(`${base}:commit`,{writes:[{delete:name('bookings/history')}]},token('admin'));
 assert.equal(r.status,200,r.body);
 await change('seed historical booking for delete protection');
 const denied=await request(`${base}:commit`,{writes:[{delete:name('bookings/history')}]},token('admin'));
 assert.equal(denied.status,403,denied.body);passed++;
 console.log(`${passed} Firestore checks passed.`);
})().catch(e=>{console.error(e);process.exitCode=1;});
