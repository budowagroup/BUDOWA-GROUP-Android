/**
 * BUDOWA GROUP TEST — additional admin PIN verification.
 *
 * IMPORTANT: The script property READ_ONLY_ADMINS must contain two real
 * administrator emails in the same order as ADMIN_PIN_SETUP_1 and _2.
 * No PINs, salts, pepper or hashes may be committed to GitHub or APK.
 * Only the project owner executes bgInitializeAdminPins from Apps Script.
 */
var BG_ADMIN_PIN_SESSION_TTL = 1800; // 30 minutes, no persistent APK storage.
var BG_ADMIN_PIN_LOCKOUT_MS = 15 * 60 * 1000;
var BG_ADMIN_PIN_MAX_FAILURES = 5;

function bgAdminEmails_() {
  var raw=PropertiesService.getScriptProperties()
    .getProperty('READ_ONLY_ADMINS') || '';
  var emails=raw.split(',').map(function(x){return x.trim().toLowerCase();})
    .filter(function(x){return x!=='';});
  if (emails.length!==2 || emails[0]===emails[1] ||
      emails.some(function(email){return !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);})) {
    throw new Error('ADMIN_LIST_NOT_CONFIGURED');
  }
  return emails;
}
function bgPinKey_(email) {
  var data=Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,String(email).trim().toLowerCase());
  return Utilities.base64EncodeWebSafe(data).replace(/=+$/,'').substring(0,22);
}
function bgPinHash_(email,pin,secret) {
  return Utilities.base64EncodeWebSafe(
    Utilities.computeHmacSha256Signature(email+'\n'+pin,secret)
  ).replace(/=+$/,'');
}
function bgSame_(a,b) {
  if (typeof a!=='string' || typeof b!=='string') return false;
  var diff=a.length^b.length;
  for (var i=0;i<Math.max(a.length,b.length);i++) {
    diff |= (a.charCodeAt(i)||0)^(b.charCodeAt(i)||0);
  }
  return diff===0;
}
/**
 * OWNER SETUP (run manually in Apps Script editor, NOT via the public API):
 * 1) Set Script Properties ADMIN_PIN_SETUP_1 and ADMIN_PIN_SETUP_2 temporarily.
 * 2) Run bgInitializeAdminPins() once in the editor.
 * 3) Function stores keyed digests, deletes plaintext setup properties and
 *    never logs secrets. Check they disappeared from Project Settings.
 */
function bgInitializeAdminPins() {
  var props=PropertiesService.getScriptProperties();
  var admins=bgAdminEmails_();
  var pending=[
    props.getProperty('ADMIN_PIN_SETUP_1'),
    props.getProperty('ADMIN_PIN_SETUP_2')
  ];
  if (pending.some(function(pin){
    return typeof pin!=='string' || pin.length<7 || pin.length>128;
  })) throw new Error('ADMIN_PIN_SETUP_INCOMPLETE');
  var lock=LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw new Error('BUSY_RETRY');
  try {
    var pepper=props.getProperty('ADMIN_PIN_PEPPER');
    if (!pepper) {
      pepper=Utilities.getUuid()+Utilities.getUuid()+Utilities.getUuid();
      props.setProperty('ADMIN_PIN_PEPPER',pepper);
    }
    for (var i=0;i<2;i++) {
      var key='ADMIN_PIN_HASH_'+bgPinKey_(admins[i]);
      props.setProperty(key,bgPinHash_(admins[i],pending[i],pepper));
    }
    props.deleteProperty('ADMIN_PIN_SETUP_1');
    props.deleteProperty('ADMIN_PIN_SETUP_2');
    return 'ADMIN_PINS_CONFIGURED'; // No PIN, hash or pepper is returned.
  } finally {
    lock.releaseLock();
  }
}
function bgAdminSessionValid_(request,user) {
  var session=request.adminSession;
  if (typeof session!=='string' ||
      !/^[0-9a-f-]{72}$/i.test(session) ||
      !user.sub || !user.email) return false;
  var props=PropertiesService.getScriptProperties();
  var digest=props.getProperty('ADMIN_PIN_HASH_'+bgPinKey_(user.email));
  if (!digest) return false; // Fail closed until setup is completed.
  var cacheValue=CacheService.getScriptCache()
    .get('BG_ADMIN_SESSION_'+session);
  return bgSame_(cacheValue,user.email+'\n'+user.sub+'\n'+digest);
}
function bgAdminPinLogin_(request,user) {
  var pin=request.adminPin;
  if (typeof pin!=='string' || pin.length<7 || pin.length>128) {
    throw new Error('ADMIN_PIN_INVALID');
  }
  var props=PropertiesService.getScriptProperties();
  var identity=bgPinKey_(user.email);
  var digest=props.getProperty('ADMIN_PIN_HASH_'+identity);
  var pepper=props.getProperty('ADMIN_PIN_PEPPER');
  if (!digest || !pepper) throw new Error('ADMIN_PIN_NOT_CONFIGURED');
  if (!user.sub) throw new Error('TOKEN_REJECTED');
  var throttleKey='ADMIN_PIN_THROTTLE_'+identity;
  var lock=LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw new Error('BUSY_RETRY');
  try {
    var now=Date.now(), state;
    try {state=JSON.parse(props.getProperty(throttleKey)||'{}');}
    catch(e){state={};}
    if (Number(state.until||0)>now) throw new Error('ADMIN_PIN_LOCKED');
    if (!state.since || now-Number(state.since)>BG_ADMIN_PIN_LOCKOUT_MS) {
      state={since:now,failures:0,until:0};
    }
    var candidate=bgPinHash_(user.email,pin,pepper);
    if (!bgSame_(candidate,digest)) {
      state.failures=Number(state.failures||0)+1;
      if (state.failures>=BG_ADMIN_PIN_MAX_FAILURES) {
        state.until=now+BG_ADMIN_PIN_LOCKOUT_MS;
      }
      props.setProperty(throttleKey,JSON.stringify(state));
      throw new Error(state.until ? 'ADMIN_PIN_LOCKED':'ADMIN_PIN_INVALID');
    }
    props.deleteProperty(throttleKey);
  } finally {
    lock.releaseLock();
  }
  var session=Utilities.getUuid()+Utilities.getUuid();
  CacheService.getScriptCache().put('BG_ADMIN_SESSION_'+session,
    user.email+'\n'+user.sub+'\n'+digest,BG_ADMIN_PIN_SESSION_TTL);
  return {ok:true,role:'admin',adminSession:session,expiresIn:BG_ADMIN_PIN_SESSION_TTL};
}
