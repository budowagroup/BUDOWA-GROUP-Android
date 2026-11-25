'use strict';
const fs=require('node:fs');
const vm=require('node:vm');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/Code.gs','utf8')+'\n'+
  fs.readFileSync(__dirname+'/AdminPin.gs','utf8');
const props={
  GOOGLE_OAUTH_CLIENT_ID:'test.apps.googleusercontent.com',
  ENABLE_TEST_WRITES:'false',
  READ_ONLY_ADMINS:'first@example.test,second@example.test',
};
const cache={};
const entries={};
let seq=0;
const properties={
  getProperty:key=>props[key]||null,
  setProperty:(key,value)=>{props[key]=String(value);return properties;},
  deleteProperty:key=>{delete props[key];return properties;},
};
const ctx={
  Date,JSON,Number,Object,String,Array,Error,RegExp,Math, Set,
  PropertiesService:{getScriptProperties:()=>properties},
  Utilities:{
    DigestAlgorithm:{SHA_256:'sha256'},
    computeDigest:(alg,data)=>Array.from(crypto.createHash(alg).update(data).digest()),
    computeHmacSha256Signature:(data,key)=>
      Array.from(crypto.createHmac('sha256',key).update(data).digest()),
    base64EncodeWebSafe:data=>Buffer.from(data).toString('base64url'),
    getUuid:()=>('00000000-0000-4000-8000-'+String(++seq).padStart(12,'0')),
  },
  CacheService:{getScriptCache:()=>({
    get:key=>cache[key]||null,
    put:(key,value)=>{cache[key]=value;},
  })},
  LockService:{getScriptLock:()=>({tryLock:()=>true,releaseLock:()=>{}})},
  ContentService:{MimeType:{JSON:'json'},createTextOutput:body=>({
    text:body,setMimeType:function(){return this;}
  })},
};
vm.createContext(ctx);
vm.runInContext(source,ctx,{filename:'Code.gs + AdminPin.gs'});
ctx.bgVerify_=(token)=>{
  if(token==='owner')return {email:'biuro.budowa.group@gmail.com',sub:'owner-sub'};
  if(token==='first')return {email:'first@example.test',sub:'first-sub'};
  if(token==='second')return {email:'second@example.test',sub:'second-sub'};
  return {email:'outsider@example.test',sub:'stranger-sub'};
};
ctx.bgRead_=()=>[['DATA_FROM_TEST']];
let count=0;
function test(name,fn){fn();count++;process.stdout.write('PASS '+name+'\n');}
function call(body){return JSON.parse(ctx.doPost({postData:{contents:JSON.stringify(body)}}).text);}
const samplePinOne='sample-not-a-real-secret-1!';
const samplePinTwo='sample-not-a-real-secret-2!';
test('no admin data without second factor',()=>{
  const r=call({idToken:'first',action:'read',book:'hours',tab:'Працівники'});
  assert.equal(r.error,'ADMIN_PIN_REQUIRED');
  assert.equal(call({idToken:'first',action:'health'}).adminPinRequired,true);
  assert.equal(call({idToken:'first',action:'history'}).error,'ADMIN_PIN_REQUIRED');
});
test('setup fails closed when two codes missing',()=>{
  assert.throws(()=>ctx.bgInitializeAdminPins(),/ADMIN_PIN_SETUP_INCOMPLETE/);
});
test('owner manually configures both digests and clears plaintext setup codes',()=>{
  props.ADMIN_PIN_SETUP_1=samplePinOne;
  props.ADMIN_PIN_SETUP_2=samplePinTwo;
  assert.equal(ctx.bgInitializeAdminPins(),'ADMIN_PINS_CONFIGURED');
  assert.equal(props.ADMIN_PIN_SETUP_1,undefined);
  assert.equal(props.ADMIN_PIN_SETUP_2,undefined);
  assert.ok(props.ADMIN_PIN_PEPPER && props.ADMIN_PIN_PEPPER.length>30);
  assert.ok(Object.keys(props).filter(key=>key.startsWith('ADMIN_PIN_HASH_')).length===2);
  assert.ok(!JSON.stringify(props).includes(samplePinOne));
  assert.ok(!JSON.stringify(props).includes(samplePinTwo));
});
test('wrong PIN fails before any sheet data',()=>{
  assert.equal(call({idToken:'first',action:'adminPinLogin',adminPin:'sample-wrong-pin'}).error,'ADMIN_PIN_INVALID');
  assert.equal(call({idToken:'first',action:'read'}).error,'ADMIN_PIN_REQUIRED');
});
let session;
test('correct personal PIN grants short-lived session',()=>{
  const r=call({idToken:'first',action:'adminPinLogin',adminPin:samplePinOne});
  assert.equal(r.ok,true);
  assert.equal(r.role,'admin');
  assert.equal(r.expiresIn,1800);
  session=r.adminSession;
  assert.match(session,/^[0-9a-f-]{72}$/);
  const health=call({idToken:'first',action:'health',adminSession:session});
  assert.equal(health.ok,true);
  assert.equal(health.adminPinVerified,true);
  assert.equal(health.capabilities.write,false);
  assert.equal(health.version,'0.6');
});
test('one admin session never authenticates another',()=>{
  assert.equal(call({idToken:'second',action:'read',adminSession:session}).error,'ADMIN_PIN_REQUIRED');
  assert.equal(call({idToken:'outsider',action:'read',adminSession:session}).error,'FORBIDDEN');
  assert.equal(call({idToken:'second',action:'adminPinLogin',adminPin:samplePinOne}).error,'ADMIN_PIN_INVALID');
});
test('authenticated admin reads TEST data but cannot write or audit',()=>{
  assert.equal(call({idToken:'first',action:'read',adminSession:session,book:'hours',tab:'Працівники'}).rows[0][0],'DATA_FROM_TEST');
  assert.equal(call({idToken:'first',action:'create',adminSession:session}).error,'FORBIDDEN');
  assert.equal(call({idToken:'first',action:'history',adminSession:session}).error,'FORBIDDEN');
});
test('owner remains unaffected and no PIN can grant owner role',()=>{
  assert.equal(call({idToken:'owner',action:'health'}).role,'owner');
  assert.equal(call({idToken:'owner',action:'adminPinLogin',adminPin:samplePinOne}).error,'FORBIDDEN');
});
test('success needs valid session and invalidation follows credential change',()=>{
  const key=ctx.bgPinKey_('first@example.test');
  props['ADMIN_PIN_HASH_'+key]='credential-rotated';
  assert.equal(call({idToken:'first',action:'read',adminSession:session}).error,'ADMIN_PIN_REQUIRED');
});
test('rate limiting blocks after five wrong attempts',()=>{
  for(let i=0;i<4;i++){
    assert.equal(call({idToken:'second',action:'adminPinLogin',adminPin:'invalid-seven'}).error,'ADMIN_PIN_INVALID');
  }
  assert.equal(call({idToken:'second',action:'adminPinLogin',adminPin:'invalid-seven'}).error,'ADMIN_PIN_LOCKED');
  assert.equal(call({idToken:'second',action:'adminPinLogin',adminPin:samplePinTwo}).error,'ADMIN_PIN_LOCKED');
});
console.log('Admin PIN authorization tests passed: '+count);
