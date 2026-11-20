/**
 * BUDOWA GROUP Android API — TEST ONLY, v0.5 (replacement Code.gs).
 *
 * Deployment: Web app, execute as owner, access "Anyone".
 * Script properties:
 *   GOOGLE_OAUTH_CLIENT_ID = Web OAuth client ID already used by Flutter
 *   ENABLE_TEST_WRITES = true   (absent/false means READ ONLY)
 *
 * NEVER configure this code with the original payroll/finance spreadsheets.
 * All writable destinations below are fixed TEST copies.
 */
var BG_TEST = {
  owner: 'biuro.budowa.group@gmail.com',
  ids: {
    hours: '1pY6rcSlodNlXFRcu_UYqFnc9DB9zuIFFsoChX1Zmb_Y',
    finance: '1l5eB0EafcIBfwosO_o5s6TYiUOvqek6uuo037DoHeGk'
  },
  auditName: '_BG_APP_AUDIT',
  tabs: {
    hours: {
      'Робочі години': {start:4,width:15,editable:[0,1,2,3,4,5,9,10,11,12,14],required:[0,1,2,3,4],key:0,formulas:[6,7,8,13]},
      'Розрахунок': {start:5,width:31},
      'Працівники': {start:4,width:6,editable:[0,1,3,4],required:[0,3],key:0,formulas:[2]},
      'Обʼєкти': {start:4,width:5,editable:[0,1,2,3],required:[0,2],key:0},
      'Історія ставок': {start:4,width:4,editable:[0,1,2,3],required:[0,1,2],key:0}
    },
    finance: {
      'Операції': {start:4,width:9,editable:[1,2,3,4,5,6,7,8],required:[1,2,3,4],key:1},
      'Панель': {start:3,width:6},
      'Закупівельники': {start:4,width:4,editable:[0],required:[0],key:0,formulas:[1,2,3]},
      'Довідники': {start:4,width:2,editable:[0],required:[0],key:0}
    }
  }
};
function bgOutput_(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
function doGet() {
  return bgOutput_({ok:false,error:'POST_ONLY'});
}
function doPost(e) {
  try {
    var body = e && e.postData && e.postData.contents;
    if (!body || body.length > 30000) throw new Error('INVALID_BODY');
    var request = JSON.parse(body);
    if (!request || typeof request !== 'object') throw new Error('INVALID_REQUEST');
    var user = bgVerify_(request.idToken);
    var role = bgRole_(user.email);
    if (role === 'none') throw new Error('FORBIDDEN');
    var enabled = role === 'owner' && PropertiesService.getScriptProperties()
      .getProperty('ENABLE_TEST_WRITES') === 'true';
    if (request.action === 'health') {
      return bgOutput_({ok:true,role:role,version:'0.5',
        capabilities:{write:enabled,create:enabled,update:enabled}});
    }
    if (request.action === 'read') {
      return bgOutput_({ok:true,rows:bgRead_(request)});
    }
    if (request.action === 'history') {
      return bgOutput_({ok:true,entries:bgHistory_(request)});
    }
    if (request.action === 'create' || request.action === 'update') {
      if (role !== 'owner') throw new Error('FORBIDDEN');
      if (!enabled) throw new Error('TEST_WRITES_DISABLED');
      return bgOutput_(bgWrite_(request,user.email.toLowerCase()));
    }
    throw new Error('UNKNOWN_ACTION');
  } catch (error) {
    // Never echo tokens or arbitrary internal exception details to clients.
    var msg = error && error.message ? error.message : 'API_ERROR';
    if (!/^[A-Z0-9_]+$/.test(msg)) msg = 'API_ERROR';
    return bgOutput_({ok:false,error:msg});
  }
}
/**
 * Preserve read-only administrators from v0.4 without publishing their emails.
 * Copy the original BG.admins list into Script Property READ_ONLY_ADMINS
 * as a comma-separated list BEFORE deploying this replacement.
 */
function bgRole_(email) {
  var normalized=String(email || '').trim().toLowerCase();
  if (normalized === BG_TEST.owner) return 'owner';
  var list=PropertiesService.getScriptProperties()
    .getProperty('READ_ONLY_ADMINS') || '';
  var admins=list.split(',').map(function(x){return x.trim().toLowerCase();});
  return admins.indexOf(normalized)>=0 ? 'admin' : 'none';
}
function bgVerify_(token) {
  if (typeof token !== 'string' || token.length < 100 || token.length > 6000) {
    throw new Error('INVALID_TOKEN');
  }
  var clientId = PropertiesService.getScriptProperties()
    .getProperty('GOOGLE_OAUTH_CLIENT_ID');
  if (!clientId) throw new Error('OAUTH_NOT_CONFIGURED');
  var response = UrlFetchApp.fetch(
    'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(token),
    {muteHttpExceptions:true,followRedirects:false});
  if (response.getResponseCode() !== 200) throw new Error('TOKEN_REJECTED');
  var data = JSON.parse(response.getContentText());
  var issuer = data.iss;
  if (data.aud !== clientId ||
      (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') ||
      !data.sub || !data.email ||
      (data.email_verified !== true && data.email_verified !== 'true') ||
      Number(data.exp) <= Math.floor(Date.now()/1000)) {
    throw new Error('TOKEN_REJECTED');
  }
  return {email:String(data.email)};
}
function bgTarget_(request, allowWrite) {
  var book = request.book, tab = request.tab;
  if (book !== 'hours' && book !== 'finance') throw new Error('INVALID_BOOK');
  var cfg = BG_TEST.tabs[book][tab];
  if (!cfg) throw new Error('INVALID_TAB');
  if (allowWrite && !cfg.editable) throw new Error('CALCULATED_TAB_READ_ONLY');
  var spreadsheet = SpreadsheetApp.openById(BG_TEST.ids[book]);
  var sheet = spreadsheet.getSheetByName(tab);
  if (!sheet) throw new Error('SHEET_MISSING');
  return {sheet:sheet,spreadsheet:spreadsheet,cfg:cfg,book:book,tab:tab};
}
function bgRead_(request) {
  var target = bgTarget_(request,false);
  var cfg = target.cfg;
  var start = Number(request.start || cfg.start);
  var limit = Number(request.limit || 30);
  if (!Number.isInteger(start) || start < cfg.start ||
      !Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new Error('INVALID_PAGE');
  }
  if (start > target.sheet.getMaxRows()) return [];
  var count = Math.min(limit,target.sheet.getMaxRows()-start+1);
  return target.sheet.getRange(start,1,count,cfg.width).getDisplayValues();
}
function bgHistory_(request) {
  var target = bgTarget_(request,false);
  var audit = target.spreadsheet.getSheetByName(BG_TEST.auditName);
  if (!audit || audit.getLastRow() < 2) return [];
  var last = audit.getLastRow();
  var start = Math.max(2,last-49);
  return audit.getRange(start,1,last-start+1,7).getDisplayValues();
}
function bgText_(value) {
  if (typeof value !== 'string' || value.length > 500) throw new Error('INVALID_VALUE');
  var str = value.trim();
  if (/^[=+@\t\r]/.test(str)) throw new Error('FORMULA_INPUT_FORBIDDEN');
  return str;
}
function bgIso_(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) throw new Error('INVALID_DATE');
  var y=Number(match[1]),m=Number(match[2]),d=Number(match[3]);
  var dt=new Date(Date.UTC(y,m-1,d));
  if (y<2020 || y>2100 || dt.getUTCFullYear()!==y ||
      dt.getUTCMonth()!==m-1 || dt.getUTCDate()!==d) {
    throw new Error('INVALID_DATE');
  }
  return value;
}
function bgNumber_(value,positive) {
  if (!/^-?\d+(\.\d+)?$/.test(value)) throw new Error('INVALID_NUMBER');
  var n=Number(value);
  if (!Number.isFinite(n) || n<0 || (positive && n===0) || n>1000000000) {
    throw new Error('INVALID_NUMBER');
  }
  return n;
}
function bgTime_(value) {
  var match=/^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
  if (!match) throw new Error('INVALID_TIME');
  return (Number(match[1])*60 + Number(match[2])) / 1440;
}
function bgDateValue_(iso,spreadsheet) {
  bgIso_(iso);
  return Utilities.parseDate(iso, spreadsheet.getSpreadsheetTimeZone(),'yyyy-MM-dd');
}
function bgValue_(target,index,raw) {
  var v=bgText_(raw);
  var book=target.book,tab=target.tab;
  if (book==='hours' && tab==='Робочі години') {
    if (index===0) return bgDateValue_(v,target.spreadsheet);
    if (index===3 || index===4) return bgTime_(v);
    if (index===5 || index===9 || index===11) return v===''? '':bgNumber_(v,false);
  }
  if (book==='hours' && tab==='Історія ставок') {
    if (index===1) return bgDateValue_(v,target.spreadsheet);
    if (index===2) return bgNumber_(v,true);
  }
  if (book==='finance' && tab==='Операції') {
    if (index===1) {
      bgIso_(v);
      return v.substring(8,10)+'.'+v.substring(5,7)+'.'+v.substring(0,4);
    }
    if (index===3) return bgNumber_(v,true);
    if (index===4 && v!=='Надходження' && v!=='Витрати') {
      throw new Error('INVALID_OPERATION');
    }
  }
  if (book==='hours' &&
    ((tab==='Працівники' && index===3) ||
     (tab==='Обʼєкти' && index===2)) && v!=='Так' && v!=='Ні') {
    throw new Error('INVALID_ACTIVE_FLAG');
  }
  return v;
}
function bgValidateRefs_(target,values) {
  if (target.book==='hours' && (target.tab==='Робочі години' ||
      target.tab==='Історія ставок')) {
    var employees=target.spreadsheet.getSheetByName('Працівники')
      .getRange('A4:A53').getDisplayValues().map(function(r){return r[0].trim();});
    var employeeName=target.tab==='Робочі години' ? values['1'] : values['0'];
    if (employees.indexOf(employeeName)<0) {
      throw new Error('EMPLOYEE_NOT_FOUND');
    }
  }
  if (target.book==='hours' && target.tab==='Робочі години') {
    var sites=target.spreadsheet.getSheetByName('Обʼєкти')
      .getRange('A4:A53').getDisplayValues().map(function(r){return r[0].trim();});
    if (sites.indexOf(values['2'])<0) throw new Error('PROJECT_NOT_FOUND');
    if (values['3']===values['4']) throw new Error('INVALID_HOURS');
    var st=bgTime_(values['3']),en=bgTime_(values['4']);
    var duration=(en-st+1)%1*24;
    if (duration===0 || Number(values['5'] || 0)>=duration) {
      throw new Error('INVALID_BREAK');
    }
  }
  if (target.book==='finance' && target.tab==='Операції') {
    var buyers=target.spreadsheet.getSheetByName('Закупівельники')
      .getRange('A4:A200').getDisplayValues().map(function(r){return r[0].trim();});
    if (buyers.indexOf(values['2'])<0) throw new Error('BUYER_NOT_FOUND');
    if (values['7']) {
      var projects=target.spreadsheet.getSheetByName('Довідники')
        .getRange('B4:B101').getDisplayValues().map(function(r){return r[0].trim();});
      if (projects.indexOf(values['7'])<0) throw new Error('PROJECT_NOT_FOUND');
    }
    if (values['6']) {
      var cats=target.spreadsheet.getSheetByName('Довідники')
        .getRange('A4:A101').getDisplayValues().map(function(r){return r[0].trim();});
      if (cats.indexOf(values['6'])<0) throw new Error('CATEGORY_NOT_FOUND');
    }
  }
}
function bgFirstEmpty_(sheet,start,key) {
  var total=sheet.getMaxRows()-start+1;
  if (total<1) throw new Error('SHEET_FULL');
  var values=sheet.getRange(start,key+1,total,1).getDisplayValues();
  for (var i=0;i<values.length;i++) {
    if (!values[i][0].trim()) return start+i;
  }
  throw new Error('SHEET_FULL');
}
function bgAudit_(target) {
  var sheet=target.spreadsheet.getSheetByName(BG_TEST.auditName);
  if (!sheet) {
    sheet=target.spreadsheet.insertSheet(BG_TEST.auditName);
    sheet.appendRow(['requestId','time','status','actor','action','tab','row','response']);
    sheet.hideSheet();
  }
  return sheet;
}
function bgExistingRequest_(audit,id) {
  if (audit.getLastRow()<2) return null;
  var found=audit.getRange(2,1,audit.getLastRow()-1,1)
    .createTextFinder(id).matchEntireCell(true).findNext();
  return found ? found.getRow() : null;
}
function bgValidateUnique_(target,values,rowNumber) {
  var tab=target.tab;
  if (tab!=='Працівники' && tab!=='Обʼєкти' &&
      tab!=='Закупівельники' && tab!=='Довідники') return;
  var name=values['0'].toLowerCase();
  var cfg=target.cfg, start=cfg.start;
  var keys=target.sheet.getRange(start,1,target.sheet.getMaxRows()-start+1,1)
    .getDisplayValues();
  for (var i=0;i<keys.length;i++) {
    if (start+i!==rowNumber && keys[i][0].trim().toLowerCase()===name) {
      throw new Error('DUPLICATE_NAME');
    }
  }
}
function bgWrite_(request,email) {
  var target=bgTarget_(request,true);
  var cfg=target.cfg;
  var values=request.values;
  if (!values || typeof values!=='object' || Array.isArray(values)) {
    throw new Error('INVALID_VALUES');
  }
  var keys=Object.keys(values);
  if (keys.length!==cfg.editable.length ||
      cfg.editable.some(function(index){return typeof values[String(index)]!=='string';}) ||
      keys.some(function(key){return cfg.editable.indexOf(Number(key))<0;})) {
    throw new Error('INVALID_EDITABLE_FIELDS');
  }
  cfg.required.forEach(function(index){
    if (!values[String(index)].trim()) throw new Error('REQUIRED_FIELD');
  });
  var parsed={};
  cfg.editable.forEach(function(index){
    parsed[index]=bgValue_(target,index,values[String(index)]);
  });
  bgValidateRefs_(target,values);
  var id=request.requestId;
  if (typeof id!=='string' || !/^[a-zA-Z0-9_-]{12,120}$/.test(id)) {
    throw new Error('INVALID_REQUEST_ID');
  }
  var lock=LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw new Error('BUSY_RETRY');
  try {
    var audit=bgAudit_(target);
    var earlier=bgExistingRequest_(audit,id);
    if (earlier!==null) {
      var status=audit.getRange(earlier,3).getDisplayValue();
      if (status==='DONE') {
        return JSON.parse(audit.getRange(earlier,8).getValue());
      }
      throw new Error('REQUEST_ALREADY_STARTED');
    }
    var row;
    if (request.action==='create') {
      row=bgFirstEmpty_(target.sheet,cfg.start,cfg.key);
    } else {
      row=Number(request.rowNumber);
      if (!Number.isInteger(row) || row<cfg.start ||
          row>target.sheet.getMaxRows()) throw new Error('INVALID_ROW');
      var expected=request.expected;
      if (!expected || typeof expected!=='object') throw new Error('EXPECTED_REQUIRED');
      var current=target.sheet.getRange(row,1,1,cfg.width).getDisplayValues()[0];
      if (!current[cfg.key]) throw new Error('ROW_NOT_FOUND');
      for (var i=0;i<cfg.editable.length;i++) {
        var idx=cfg.editable[i], key=String(idx);
        if (typeof expected[key]!=='string' || expected[key]!==current[idx]) {
          throw new Error('EDIT_CONFLICT_REFRESH');
        }
      }
    }
    // Do not silently break references or formula lookups by renaming keys.
    // Name changes require a separate dependency-aware migration.
    if (request.action==='update' &&
        (target.tab==='Працівники' || target.tab==='Обʼєкти' ||
         target.tab==='Закупівельники' || target.tab==='Довідники')) {
      var existingName=target.sheet.getRange(row,1).getDisplayValue().trim();
      if (values['0']!==existingName) {
        throw new Error('RENAME_REQUIRES_MIGRATION');
      }
    }
    bgValidateUnique_(target,values,row);
    if (target.tab==='Історія ставок') {
      var name=values['0'].trim();
      var effectiveDate=values['1'];
      var existingRates=target.sheet.getRange(
        cfg.start,1,target.sheet.getMaxRows()-cfg.start+1,2
      ).getValues();
      for (var k=0;k<existingRates.length;k++) {
        if (cfg.start+k===row) continue;
        var priorName=String(existingRates[k][0] || '').trim();
        var priorDate=existingRates[k][1];
        if (priorName!==name || !(priorDate instanceof Date)) continue;
        var priorIso=Utilities.formatDate(
          priorDate,target.spreadsheet.getSpreadsheetTimeZone(),'yyyy-MM-dd');
        if (priorIso===effectiveDate) throw new Error('DUPLICATE_RATE_DATE');
      }
    }

    (cfg.formulas||[]).forEach(function(column){
      if (!target.sheet.getRange(row,column+1).getFormula()) {
        throw new Error('MISSING_FORMULA_ROW');
      }
    });
    var ledgerRow=audit.getLastRow()+1;
    audit.getRange(ledgerRow,1,1,7).setValues([[
      id,new Date(), 'PENDING', email, request.action,
      target.book + ':' + target.tab, row
    ]]);
    for (var j=0;j<cfg.editable.length;j++) {
      var col=cfg.editable[j];
      var dest=target.sheet.getRange(row,col+1);
      if (dest.getFormula()) throw new Error('FORMULA_CELL_PROTECTED');
      dest.setValue(parsed[col]);
      if (parsed[col] instanceof Date) dest.setNumberFormat('dd.MM.yyyy');
      if (target.tab==='Робочі години' && (col===3||col===4)) {
        dest.setNumberFormat('hh:mm');
      }
    }
    SpreadsheetApp.flush();
    var result={ok:true,action:request.action,book:target.book,tab:target.tab,
      rowNumber:row};
    audit.getRange(ledgerRow,8).setValue(JSON.stringify(result));
    audit.getRange(ledgerRow,3).setValue('DONE');
    return result;
  } finally {
    lock.releaseLock();
  }
}
