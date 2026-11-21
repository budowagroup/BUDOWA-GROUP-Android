
'use strict';
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/Code.gs','utf8');
const props={
  GOOGLE_OAUTH_CLIENT_ID:'test.apps.googleusercontent.com',
  ENABLE_TEST_WRITES:'false',
  READ_ONLY_ADMINS:'admin@example.com, other@example.com',
};
const opened=[];
const ctx={
  Date,JSON,Number,Object,String,Array,Error,RegExp,Math,
  PropertiesService:{getScriptProperties:()=>({
    getProperty:name=>props[name]??null,
  })},
  SpreadsheetApp:{openById:id=>{
    opened.push(id);
    return {getSheetByName:()=>({getMaxRows:()=>100,
      getRange:()=>({getDisplayValues:()=>[['value']]})})};
  }},
  Utilities:{
    parseDate:iso=>new Date(iso+'T00:00:00Z'),
    formatDate:d=>d.toISOString().slice(0,10),
  },
  ContentService:{MimeType:{JSON:'json'},createTextOutput:body=>({
    text:body,setMimeType:function(){return this;}
  })},
};
vm.createContext(ctx);
vm.runInContext(source,ctx,{filename:'Code.gs'});
let count=0;
function test(label,callback){callback();count++;console.log('PASS '+label);}
function fails(fn,msg){assert.throws(fn,e=>e.message===msg,msg);}
test('valid leap date',()=>assert.equal(ctx.bgIso_('2028-02-29'),'2028-02-29'));
test('invalid date',()=>fails(()=>ctx.bgIso_('2026-02-29'),'INVALID_DATE'));
test('wrong date format',()=>fails(()=>ctx.bgIso_('29.02.2028'),'INVALID_DATE'));
test('time conversion',()=>assert.equal(ctx.bgTime_('12:00'),0.5));
test('invalid time',()=>fails(()=>ctx.bgTime_('24:00'),'INVALID_TIME'));
test('zero allowed',()=>assert.equal(ctx.bgNumber_('0',false),0));
test('zero positive rejected',()=>fails(()=>ctx.bgNumber_('0',true),'INVALID_NUMBER'));
test('negative rejected',()=>fails(()=>ctx.bgNumber_('-2',false),'INVALID_NUMBER'));
test('formula rejected',()=>fails(()=>ctx.bgText_('=IMPORTXML(...)'),'FORMULA_INPUT_FORBIDDEN'));
test('owner role',()=>assert.equal(ctx.bgRole_('BIURO.BUDOWA.GROUP@GMAIL.COM'),'owner'));
test('admin role read only',()=>assert.equal(ctx.bgRole_('ADMIN@example.com'),'admin'));
test('unknown role',()=>assert.equal(ctx.bgRole_('stranger@example.com'),'none'));
test('finance text date',()=>assert.equal(
  ctx.bgValue_({book:'finance',tab:'Операції'},1,'2026-11-20'),'20.11.2026'));
test('original hours ID absent',()=>assert(!source.includes('1Dk5qsoBVcHfPBIhmsFuKw7mezYZ1HMBir0luChjYRpI')));
test('original finance ID absent',()=>assert(!source.includes('1DFvgdekEnL-ewhhDVfBTuiDcxSRvN5RPfx1OYfYVC3Y')));
test('cannot inject spreadsheet ID',()=>{
  ctx.bgTarget_({book:'finance',tab:'Операції',spreadsheetId:'evil'},true);
  assert.equal(opened.at(-1),'1l5eB0EafcIBfwosO_o5s6TYiUOvqek6uuo037DoHeGk');
});
test('cannot edit calculated dashboard',()=>fails(
  ()=>ctx.bgTarget_({book:'finance',tab:'Панель'},true),'CALCULATED_TAB_READ_ONLY'));
test('cannot edit calculated payroll',()=>fails(
  ()=>ctx.bgTarget_({book:'hours',tab:'Розрахунок'},true),'CALCULATED_TAB_READ_ONLY'));
test('invalid tab rejected',()=>fails(
  ()=>ctx.bgTarget_({book:'hours',tab:'Fake'},false),'INVALID_TAB'));
ctx.bgVerify_=idToken=>({email:idToken==='owner'
  ?'biuro.budowa.group@gmail.com'
  :idToken==='admin'?'admin@example.com':'stranger@example.com'});
ctx.bgHistory_=()=>[['AUDIT_TEST_ROW']];
const call=req=>JSON.parse(ctx.doPost({postData:{contents:JSON.stringify(req)}}).text);
// Stage A: v0.5 must preserve read-only access to all nine tabs without
// invoking any mutation on the backing TEST copies.
test('all nine configured TEST tabs read as owner in read-only mode',()=>{
  const tabs = {
    hours:['Робочі години','Розрахунок','Працівники','Обʼєкти','Історія ставок'],
    finance:['Операції','Панель','Закупівельники','Довідники'],
  };
  const seen = [];
  for (const [book, names] of Object.entries(tabs)) {
    for (const tab of names) {
      const r = call({idToken:'owner',action:'read',book,tab,limit:30});
      assert.equal(r.ok,true,book + ' / ' + tab);
      assert.ok(Array.isArray(r.rows),book + ' / ' + tab);
      seen.push(book+':'+tab);
    }
  }
  assert.equal(seen.length,9);
});
test('legacy read-only admins can read all nine tabs without write rights',()=>{
  const tabs = {
    hours:['Робочі години','Розрахунок','Працівники','Обʼєкти','Історія ставок'],
    finance:['Операції','Панель','Закупівельники','Довідники'],
  };
  for (const [book, names] of Object.entries(tabs)) {
    for (const tab of names) {
      const r = call({idToken:'admin',action:'read',book,tab});
      assert.equal(r.ok,true,book + ' / ' + tab);
      assert.equal(call({idToken:'stranger',action:'read',book,tab}).error,
        'FORBIDDEN',book + ' / ' + tab);
    }
  }
});
test('missing write property fails closed, including UPDATE',()=>{
  delete props.ENABLE_TEST_WRITES;
  assert.equal(call({idToken:'owner',action:'health'}).capabilities.write,false);
  assert.equal(call({idToken:'owner',action:'create'}).error,'TEST_WRITES_DISABLED');
  assert.equal(call({idToken:'owner',action:'update'}).error,'TEST_WRITES_DISABLED');
  props.ENABLE_TEST_WRITES='false';
});
test('read-only deployment flag rejects both create and update',()=>{
  assert.equal(call({idToken:'owner',action:'create'}).error,'TEST_WRITES_DISABLED');
  assert.equal(call({idToken:'owner',action:'update'}).error,'TEST_WRITES_DISABLED');
  assert.equal(call({idToken:'admin',action:'create'}).error,'FORBIDDEN');
  assert.equal(call({idToken:'admin',action:'update'}).error,'FORBIDDEN');
});
test('owner write flag defaults off',()=>{
  const r=call({idToken:'owner',action:'health'});
  assert.equal(r.ok,true);assert.equal(r.capabilities.write,false);
});
test('owner write rejected when off',()=>{
  assert.equal(call({idToken:'owner',action:'create'}).error,'TEST_WRITES_DISABLED');
});
test('only owner may read the audit history',()=>{
  const owner = call({idToken:'owner',action:'history',book:'finance',tab:'Операції'});
  assert.equal(owner.ok,true);
  assert.equal(owner.entries[0][0],'AUDIT_TEST_ROW');
  assert.equal(
    call({idToken:'admin',action:'history',book:'finance',tab:'Операції'}).error,
    'FORBIDDEN');
  assert.equal(
    call({idToken:'stranger',action:'history',book:'finance',tab:'Операції'}).error,
    'FORBIDDEN');
});
test('admin can read but not write',()=>{
  props.ENABLE_TEST_WRITES='true';
  const r=call({idToken:'admin',action:'health'});
  assert.equal(r.role,'admin');assert.equal(r.capabilities.write,false);
  assert.equal(call({idToken:'admin',action:'create'}).error,'FORBIDDEN');
});
test('owner can enable write',()=>{
  assert.equal(call({idToken:'owner',action:'health'}).capabilities.write,true);
});
test('outsider denied',()=>{
  assert.equal(call({idToken:'stranger',action:'health'}).error,'FORBIDDEN');
});
console.log('Backend tests passed: '+count);
