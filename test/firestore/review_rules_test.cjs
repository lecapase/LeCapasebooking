const assert = require('node:assert/strict');
const host=process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host||'',/^(127\.0\.0\.1|localhost):\d+$/);
const project='demo-lecapase-reviews-rules';
const base=`http://${host}/v1/projects/${project}/databases/(default)/documents`;
const enc=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
const token=uid=>`${enc({alg:'none',typ:'JWT'})}.${enc({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom'}})}.`;
async function request(path,method,auth,fields) {
  return fetch(`${base}/${path}`,{method,headers:{'Content-Type':'application/json',...(auth?{Authorization:`Bearer ${auth}`}:{})},
    ...(fields?{body:JSON.stringify({fields})}:{})});
}
async function check(response,status){assert.equal(response.status,status,await response.text());}
(async()=>{
  for(const role of ['admin','manager','staff','inactive']) await check(await request(`staff_users/${role}`,'PATCH','owner',{
    role:{stringValue:role==='inactive'?'admin':role},active:{booleanValue:role!=='inactive'},
  }),200);
  await check(await request('review_batches/2026-09-26','PATCH','owner',{state:{stringValue:'pending'}}),200);
  await check(await request('review_batches/2026-09-26','GET',token('admin')),200);
  let checked=1;
  for(const role of ['manager','staff','inactive',null]) {
    await check(await request('review_batches/2026-09-26','GET',role?token(role):null),403);checked++;
  }
  for(const role of ['admin','manager','staff',null]) {
    for(const path of ['review_batches/2026-09-26','review_requests/test','review_contact_limits/test','_system/review_automation']) {
      await check(await request(path,'PATCH',role?token(role):null,{state:{stringValue:'approved'}}),403);checked++;
    }
  }
  console.log(`${checked} review authorization rules checks passed.`);
})().catch(error=>{console.error(error);process.exitCode=1;});
