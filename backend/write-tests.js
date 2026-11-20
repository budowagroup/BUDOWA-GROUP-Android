'use strict';
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const code=fs.readFileSync(__dirname+'/Code.gs','utf8');
const files={};

function sheet(name,maxRows=15){
  const data={};
  let failOnce=null;
  const key=(row,col)=>row+':'+col;
  const cell=(row,col)=>data[key(row,col)]??=({value:'',format:'General',formula:''});
  const self={
    name, data, cell,
    getMaxRows:()=>maxRows,
    getLastRow:()=>Object.keys(data).reduce((m,k)=>{
      const [r]=k.split(':').map(Number);
      const x=data[k];
      return x.value!==''||x.formula ? Math.max(m,r) : m;
    },0),
    appendRow:values=>{
      const row=self.getLastRow()+1;
      values.forEach((v,i)=>cell(row,i+1).value=v);
    },
    hideSheet:()=>{},
    setFailOnce:(row,col)=>{failOnce=key(row,col);},
    getRange(row,col,numRows=1,numCols=1){
      const range={
        getValue:()=>cell(row,col).value,
        getDisplayValue:()=>String(cell(row,col).value),
        getFormula:()=>cell(row,col).formula,
        getNumberFormat:()=>cell(row,col).format,
        setValue(value){
          if(failOnce===key(row,col)){failOnce=null;throw new Error('SIMULATED_DISCONNECT');}
          cell(row,col).value=value;return range;
        },
        setNumberFormat(fmt){cell(row,col).format=fmt;return range;},
        getDisplayValues:()=>Array.from({length:numRows},(_,ri)=>
          Array.from({length:numCols},(_,ci)=>String(cell(row+ri,col+ci).value))),
        getValues:()=>Array.from({length:numRows},(_,ri)=>
          Array.from({length:numCols},(_,ci)=>cell(row+ri,col+ci).value)),
        setValues:values=>{
          values.forEach((arr,ri)=>arr.forEach((v,ci)=>{cell(row+ri,col+ci).value=v;}));
          return range;
        },
        createTextFinder:search=>({
          matchEntireCell(){return this;},
          findNext(){
            for(let r=row;r<row+numRows;r++){
              if(String(cell(r,col).value)===search)return {getRow:()=>r};
            }
            return null;
          }
        })
      };
      return range;
    }
  };
  return self;
}
const finance=sheet('Операції');
const buyer=sheet('Закупівельники');
const hours=sheet('Робочі години');
const payroll=sheet('Працівники');
buyer.cell(4,1).value='Ігор';
finance.cell(4,2).value='19.11.2026';
finance.cell(4,3).value='Ігор';
finance.cell(4,4).value=20;
finance.cell(4,5).value='Витрати';
finance.cell(4,6).value='Original note';
payroll.cell(4,1).value='Test Employee';
payroll.cell(4,3).formula='=CALCULATE()';
const workbooks={
  '1l5eB0EafcIBfwosO_o5s6TYiUOvqek6uuo037DoHeGk':{
    sheets:{'Операції':finance,'Закупівельники':buyer},
  },
  '1pY6rcSlodNlXFRcu_UYqFnc9DB9zuIFFsoChX1Zmb_Y':{
    sheets:{'Робочі години':hours,'Працівники':payroll},
  },
};
for (const wb of Object.values(workbooks)){
  wb.getSheetByName=name=>wb.sheets[name]||null;
  wb.insertSheet=name=>wb.sheets[name]=sheet(name);
  wb.getSpreadsheetTimeZone=()=> 'Europe/Warsaw';
}
const ctx={
  Date,JSON,Number,Object,String,Array,Error,RegExp,Math,
  SpreadsheetApp:{openById:id=>workbooks[id],flush:()=>{}},
  LockService:{getScriptLock:()=>({tryLock:()=>true,releaseLock:()=>{}})},
  Utilities:{
    parseDate:iso=>new Date(iso+'T00:00:00Z'),
    formatDate:date=>date.toISOString().slice(0,10),
  },
};
vm.createContext(ctx);
vm.runInContext(code,ctx,{filename:'Code.gs'});
// Reference validation belongs to separate checks; here exercise the write protocol.
ctx.bgValidateRefs_=()=>{};
let count=0;
function test(name,fn){fn();console.log('PASS '+name);count++;}
function error(fn,message){assert.throws(fn,e=>e.message===message,message);}
function financeValues(overrides={}){
  return {'1':'2026-11-20','2':'Ігор','3':'125.50','4':'Витрати',
    '5':'TEST transaction','6':'','7':'','8':'',...overrides};
}
const create={action:'create',book:'finance',tab:'Операції',
  values:financeValues(),requestId:'writeTestCreate0001'};
test('create adds one TEST operation without modifying previous row',()=>{
  const r=ctx.bgWrite_(create,'owner@example.com');
  assert.equal(r.rowNumber,5);
  assert.equal(finance.cell(5,2).value,'20.11.2026');
  assert.equal(finance.cell(5,4).value,125.5);
  assert.equal(finance.cell(4,6).value,'Original note');
});
test('idempotent request does not create duplicate',()=>{
  const r=ctx.bgWrite_(create,'owner@example.com');
  assert.equal(r.rowNumber,5);
  assert.equal(finance.cell(6,2).value,'');
});
function expected(row){
  const result={};
  for(const idx of [1,2,3,4,5,6,7,8])
    result[String(idx)]=String(finance.cell(row,idx+1).value);
  return result;
}
test('edit updates existing record in place',()=>{
  const req={action:'update',book:'finance',tab:'Операції',rowNumber:5,
    expected:expected(5),values:financeValues({'5':'Edited note'}),
    requestId:'writeTestUpdate0002'};
  const r=ctx.bgWrite_(req,'owner@example.com');
  assert.equal(r.rowNumber,5);
  assert.equal(finance.cell(5,6).value,'Edited note');
});
test('stale edits are rejected without mutation',()=>{
  const req={action:'update',book:'finance',tab:'Операції',rowNumber:5,
    expected:{...expected(5),'5':'Old note'},
    values:financeValues({'5':'Overwrite'}),
    requestId:'writeTestConflict03'};
  error(()=>ctx.bgWrite_(req,'owner@example.com'),'EDIT_CONFLICT_REFRESH');
  assert.equal(finance.cell(5,6).value,'Edited note');
});
test('invalid formula input never reaches a cell',()=>{
  const req={...create,requestId:'writeTestFormula004',
    values:financeValues({'5':'=IMPORTXML()'})};
  error(()=>ctx.bgWrite_(req,'owner@example.com'),'FORMULA_INPUT_FORBIDDEN');
  assert.equal(finance.cell(6,2).value,'');
});
test('preflight detects nonempty destination even with blank key',()=>{
  finance.cell(6,6).value='leftover';
  const req={...create,requestId:'writeTestOccupied05'};
  error(()=>ctx.bgWrite_(req,'owner@example.com'),'CREATE_TARGET_NOT_EMPTY');
  assert.equal(finance.cell(6,6).value,'leftover');
  finance.cell(6,6).value='';
});
test('partial writes are rolled back and logged',()=>{
  finance.setFailOnce(6,4);
  const req={...create,requestId:'writeTestRollback06'};
  error(()=>ctx.bgWrite_(req,'owner@example.com'),'WRITE_FAILED_ROLLED_BACK');
  assert.equal(finance.cell(6,2).value,'');
  assert.equal(finance.cell(6,3).value,'');
  assert.equal(finance.cell(6,4).value,'');
  const audit=workbooks['1l5eB0EafcIBfwosO_o5s6TYiUOvqek6uuo037DoHeGk']
    .getSheetByName('_BG_APP_AUDIT');
  const last=audit.getLastRow();
  assert.equal(audit.cell(last,3).value,'ROLLED_BACK');
});
test('creating worker hours fails if calculated formulas were not prepared',()=>{
  const req={action:'create',book:'hours',tab:'Робочі години',requestId:'writeTestMissingFormula07',
    values:{'0':'2026-11-20','1':'Test Employee','2':'Rembertow Rafal',
      '3':'08:00','4':'17:00','5':'0.5','9':'0','10':'','11':'0','12':'','14':''}};
  error(()=>ctx.bgWrite_(req,'owner@example.com'),'MISSING_FORMULA_ROW');
  assert.equal(hours.cell(4,1).value,'');
});
test('renaming worker is blocked to protect dependent formulas',()=>{
  const req={action:'update',book:'hours',tab:'Працівники',rowNumber:4,
    requestId:'writeTestRenameBlock08',
    expected:{'0':'Test Employee','1':'','3':'','4':''},
    values:{'0':'New Name','1':'','3':'Так','4':''}};
  error(()=>ctx.bgWrite_(req,'owner@example.com'),'RENAME_REQUIRES_MIGRATION');
  assert.equal(payroll.cell(4,1).value,'Test Employee');
});
console.log('Write integration tests passed: '+count);
