'use strict';
const fs = require('node:fs');
const assert = require('node:assert/strict');

const manifest = JSON.parse(
  fs.readFileSync(__dirname + '/appsscript.json', 'utf8')
);
const source = fs.readFileSync(__dirname + '/Code.gs', 'utf8');
const scopes = manifest.oauthScopes;
assert.equal(manifest.timeZone, 'Europe/Warsaw');
assert.equal(manifest.runtimeVersion, 'V8');
assert.deepEqual(manifest.dependencies, {});
assert.ok(manifest.webapp, 'Keep the existing Web App configuration during manifest replacement');
assert.equal(manifest.webapp.executeAs, 'USER_DEPLOYING',
  'Web App must run as project deploying user');
assert.equal(manifest.webapp.access, 'ANYONE_ANONYMOUS',
  'Keep existing access so Android POST requests remain reachable; API requires a valid ID token');

assert.ok(Array.isArray(scopes), 'Explicit OAuth scopes required');
assert.equal(scopes.length, new Set(scopes).size, 'No duplicate OAuth scopes');
assert.ok(scopes.includes('https://www.googleapis.com/auth/spreadsheets'),
  'SpreadsheetApp edits require the read/write Sheets scope');
assert.ok(scopes.includes('https://www.googleapis.com/auth/script.external_request'),
  'Google ID-token validation requires UrlFetchApp');
assert.ok(!scopes.includes('https://www.googleapis.com/auth/spreadsheets.readonly'),
  'Read-only Sheets scope is insufficient for CREATE/UPDATE');
assert.ok(source.includes("getProperty('ENABLE_TEST_WRITES') === 'true'"),
  'Write permission must default to disabled');
assert.ok(source.includes("role !== 'owner'"),
  'Only owner may enable test writes');
assert.ok(!source.includes('1Dk5qsoBVcHfPBIhmsFuKw7mezYZ1HMBir0luChjYRpI'),
  'Original employee-hours book must never be a backend write target');
assert.ok(!source.includes('1DFvgdekEnL-ewhhDVfBTuiDcxSRvN5RPfx1OYfYVC3Y'),
  'Original finance book must never be a backend write target');
console.log('PASS TEST-only Apps Script manifest and deployment gates');
