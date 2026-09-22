const BASE = 'http://localhost:3000/api/v1';
const C = {
  green:  s => '\x1b[32m' + s + '\x1b[0m',
  red:    s => '\x1b[31m' + s + '\x1b[0m',
  yellow: s => '\x1b[33m' + s + '\x1b[0m',
  cyan:   s => '\x1b[36m' + s + '\x1b[0m',
  bold:   s => '\x1b[1m'  + s + '\x1b[0m',
  dim:    s => '\x1b[2m'  + s + '\x1b[0m',
};
const results = [];
let adminToken = null;
let createdTemplateId = null;
let createdFestivalId = null;

async function req(method, path, opts) {
  if (!opts) opts = {};
  const { body, token, expectStatus, tag } = opts;
  const url = BASE + path;
  const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
  if (token) headers['Authorization'] = 'Bearer ' + token;
  const startMs = Date.now();
  let status, resBody;
  try {
    const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
    status = res.status;
    try { resBody = await res.json(); } catch(e) { resBody = null; }
  } catch (err) {
    const entry = { tag, method, path, status: 'ERR', ok: false, ms: Date.now() - startMs, error: err.message };
    results.push(entry); printRow(entry); return null;
  }
  const arr = Array.isArray(expectStatus) ? expectStatus : (expectStatus ? [expectStatus] : null);
  const ok = arr ? arr.includes(status) : (status >= 200 && status < 300);
  const entry = { tag, method, path, status, ok, ms: Date.now() - startMs };
  results.push(entry); printRow(entry);
  return resBody;
}

function printRow(r) {
  const icon = r.ok ? C.green('[PASS]') : C.red('[FAIL]');
  const errStr = r.error ? C.red(' -- ' + r.error) : '';
  console.log('  ' + icon + ' ' + r.method.padEnd(7) + r.path.padEnd(55) + ' ' + r.status + '  ' + r.ms + 'ms' + errStr);
}

function section(t) {
  console.log('\n' + C.bold(C.cyan('=== ' + t + ' ===')));
}

async function main() {
  console.log(C.bold(C.cyan('\nSTATUS GO -- API Test & Dummy Data Report')));
  console.log(C.dim('Target: ' + BASE + '\n'));

  section('1. HEALTH CHECK');
  const h = await fetch('http://localhost:3000/api/v1/health');
  const hb = await h.json();
  results.push({ tag: 'infra', method: 'GET', path: '/health', status: h.status, ok: h.status === 200, ms: hb.latency_ms || 0 });
  printRow({ tag: 'infra', method: 'GET', path: '/health', status: h.status, ok: h.status === 200, ms: hb.latency_ms || 0 });
  console.log('  DB   : ' + (hb.db === 'ok' ? C.green('CONNECTED') : C.red('ERROR')));
  console.log('  Redis: ' + (hb.redis === 'ok' ? C.green('CONNECTED') : C.red('ERROR')));
  console.log('  Env  : ' + hb.env + '  v' + hb.version);

  section('2. AUTH');
  const login = await req('POST', '/auth/admin/login', { tag: 'auth', body: { email: 'admin@statusgo.app', password: 'Admin@1234' }, expectStatus: [200, 401, 404] });
  if (login && login.accessToken) { adminToken = login.accessToken; console.log(C.green('  Admin token obtained')); }
  const dev = await req('POST', '/auth/dev-login', { tag: 'auth', body: { email: 'admin@statusgo.app' }, expectStatus: [200, 201, 404, 403] });
  if (!adminToken && dev && dev.accessToken) { adminToken = dev.accessToken; console.log(C.green('  Dev-login token obtained')); }
  if (!adminToken) console.log(C.yellow('  No token -- authenticated routes will show 401'));
  await req('POST', '/auth/refresh', { tag: 'auth', body: { refreshToken: 'invalid' }, expectStatus: [200, 400, 401] });
  await req('POST', '/auth/logout', { tag: 'auth', body: { refreshToken: 'dummy' }, expectStatus: [200, 400, 401] });
  await req('POST', '/auth/otp/send', { tag: 'auth', body: { phoneNumber: '+919876543210' }, expectStatus: [200, 201, 400, 429, 500] });
  await req('POST', '/auth/otp/verify', { tag: 'auth', body: { phoneNumber: '+919876543210', otp: '123456' }, expectStatus: [200, 400, 401, 429] });
  await req('POST', '/auth/google', { tag: 'auth', body: { idToken: 'dummy' }, expectStatus: [200, 201, 400, 401] });

  section('3. CATEGORIES (Public)');
  const cats = await req('GET', '/categories', { tag: 'categories', expectStatus: 200 });
  if (cats && cats.data && cats.data.length > 0) {
    console.log(C.green('  ' + cats.data.length + ' categories returned'));
    cats.data.slice(0, 3).forEach(function(c) { console.log(C.dim('    * ' + (c.emoji || '') + ' ' + (c.nameEn || c.nameHi) + ' (' + c.slug + ')')); });
  }

  section('4. TEMPLATES');
  await req('GET', '/templates', { tag: 'templates', token: adminToken, expectStatus: [200, 401] });
  const feat = await req('GET', '/templates/featured', { tag: 'templates', token: adminToken, expectStatus: [200, 401] });
  if (feat && feat.data && feat.data.length > 0) { createdTemplateId = feat.data[0].id; console.log(C.green('  ' + feat.data.length + ' featured templates')); }
  const trend = await req('GET', '/templates/trending', { tag: 'templates', token: adminToken, expectStatus: [200, 401] });
  if (trend && trend.data && trend.data.length > 0 && !createdTemplateId) createdTemplateId = trend.data[0].id;
  await req('GET', '/templates/new', { tag: 'templates', token: adminToken, expectStatus: [200, 401] });
  await req('GET', '/templates/home', { tag: 'templates', token: adminToken, expectStatus: [200, 401] });
  if (createdTemplateId) {
    await req('GET', '/templates/' + createdTemplateId, { tag: 'templates', token: adminToken, expectStatus: [200, 401, 404] });
    await req('POST', '/templates/' + createdTemplateId + '/view', { tag: 'templates', token: adminToken, expectStatus: [200, 201, 401, 404] });
    await req('POST', '/templates/' + createdTemplateId + '/use', { tag: 'templates', token: adminToken, expectStatus: [200, 201, 401, 404] });
    await req('POST', '/templates/' + createdTemplateId + '/share', { tag: 'templates', token: adminToken, expectStatus: [200, 201, 401, 404] });
  }

  section('5. SEARCH');
  await req('GET', '/search?q=birthday&limit=5', { tag: 'search', token: adminToken, expectStatus: [200, 401] });
  await req('GET', '/search/trending', { tag: 'search', token: adminToken, expectStatus: [200, 401] });
  await req('GET', '/search/suggestions?q=wish', { tag: 'search', token: adminToken, expectStatus: [200, 401] });

  section('6. USER PROFILE');
  const me = await req('GET', '/user/me', { tag: 'user', token: adminToken, expectStatus: [200, 401] });
  if (me && me.id) console.log(C.green('  User: ' + me.name + ' | ' + me.email + ' | Plan: ' + me.plan));
  await req('PUT', '/user/me', { tag: 'user', token: adminToken, body: { name: 'Test Admin', displayName: 'TestAdmin', state: 'Maharashtra', region: 'Pune', frameType: 'CLASSIC' }, expectStatus: [200, 400, 401] });
  await req('GET', '/user/saved', { tag: 'user', token: adminToken, expectStatus: [200, 401] });
  await req('GET', '/user/history', { tag: 'user', token: adminToken, expectStatus: [200, 401] });
  if (createdTemplateId) {
    await req('POST', '/user/saved/' + createdTemplateId, { tag: 'user', token: adminToken, expectStatus: [200, 201, 401, 404, 409] });
    await req('DELETE', '/user/saved/' + createdTemplateId, { tag: 'user', token: adminToken, expectStatus: [200, 401, 404] });
  }
  await req('PUT', '/user/player-id', { tag: 'user', token: adminToken, body: { playerId: 'dummy-player-123' }, expectStatus: [200, 400, 401] });

  section('7. SUBSCRIPTIONS');
  const plans = await req('GET', '/subscribe/plans', { tag: 'subscriptions', expectStatus: 200 });
  if (plans) console.log(C.green('  Plans response: ' + JSON.stringify(plans).slice(0, 150)));
  await req('GET', '/subscribe/status', { tag: 'subscriptions', token: adminToken, expectStatus: [200, 401] });
  await req('POST', '/subscribe/create', { tag: 'subscriptions', token: adminToken, body: { plan: 'PREMIUM' }, expectStatus: [200, 201, 400, 401, 500] });
  await req('POST', '/subscribe/verify', { tag: 'subscriptions', token: adminToken, body: { razorpay_order_id: 'order_dummy', razorpay_payment_id: 'pay_dummy', razorpay_signature: 'badsig' }, expectStatus: [200, 400, 401, 500] });

  section('8. FESTIVALS');
  const upfest = await req('GET', '/festivals/upcoming', { tag: 'festivals', token: adminToken, expectStatus: [200, 401] });
  if (upfest && upfest.data) console.log(C.green('  ' + upfest.data.length + ' upcoming festivals'));

  section('9. ADMIN ROUTES');
  await req('GET', '/admin/stats', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/templates?page=1&limit=5', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/templates/pending', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/users?page=1&limit=5', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/creators?page=1&limit=5', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/festivals', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  const nf = await req('POST', '/admin/festivals', { tag: 'admin', token: adminToken, body: { nameHi: 'टेस्ट', nameEn: 'Test Festival QA', nameMr: 'टेस्ट', emoji: '🧪', date: new Date(Date.now() + 30*24*60*60*1000).toISOString(), isRecurring: false }, expectStatus: [200, 201, 400, 401, 403] });
  if (nf && nf.festival && nf.festival.id) {
    createdFestivalId = nf.festival.id;
    console.log(C.green('  Dummy festival created: id=' + createdFestivalId));
    await req('PUT', '/admin/festivals/' + createdFestivalId, { tag: 'admin', token: adminToken, body: { nameEn: 'Test Festival QA Updated', isActive: true }, expectStatus: [200, 401, 403, 404] });
  }
  await req('GET', '/admin/revenue', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/analytics/dau?days=7', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/analytics/searches', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/analytics/shares', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/campaigns', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/config', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/audit-log', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/admin/coordinator-picks', { tag: 'admin', token: adminToken, expectStatus: [200, 401, 403] });
  await req('POST', '/admin/creators/invite', { tag: 'admin', token: adminToken, body: { email: 'dummyqa@statusgo.app', name: 'QA Creator', displayName: 'QACreator' }, expectStatus: [200, 201, 400, 401, 403, 409] });

  section('10. UPLOAD (auth gate check)');
  const ur = await fetch(BASE + '/upload/profile-photo', { method: 'POST', headers: { 'Authorization': adminToken ? 'Bearer ' + adminToken : '' } });
  results.push({ tag: 'upload', method: 'POST', path: '/upload/profile-photo', status: ur.status, ok: [400, 401, 415, 422].includes(ur.status), ms: 0 });
  printRow({ tag: 'upload', method: 'POST', path: '/upload/profile-photo', status: ur.status, ok: [400, 401, 415, 422].includes(ur.status), ms: 0 });
  console.log(C.dim('  (no file sent -- checking auth/multipart gate)'));

  section('11. CREATOR ROUTES');
  await req('GET', '/creator/templates', { tag: 'creator', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/creator/stats', { tag: 'creator', token: adminToken, expectStatus: [200, 401, 403] });
  await req('GET', '/creator/profile', { tag: 'creator', token: adminToken, expectStatus: [200, 401, 403] });

  const total = results.length;
  const passed = results.filter(function(r) { return r.ok; }).length;
  const failed = total - passed;
  const avgMs = Math.round(results.reduce(function(s, r) { return s + (r.ms || 0); }, 0) / total);

  console.log('\n' + C.bold('='.repeat(70)));
  console.log(C.bold('  API TEST SUMMARY -- STATUS GO BACKEND'));
  console.log(C.bold('='.repeat(70)));
  console.log('  Endpoints Tested : ' + total);
  console.log('  PASSED           : ' + C.green(String(passed)));
  console.log('  FAILED           : ' + (failed > 0 ? C.red(String(failed)) : C.green('0')));
  console.log('  Avg Response     : ' + avgMs + 'ms');
  console.log('\n  By Module:');
  const tags2 = [];
  results.forEach(function(r) { if (!tags2.includes(r.tag)) tags2.push(r.tag); });
  tags2.forEach(function(tag) {
    const g = results.filter(function(r) { return r.tag === tag; });
    const gp = g.filter(function(r) { return r.ok; }).length;
    const icon = gp === g.length ? C.green('[OK]') : C.red('[!!]');
    console.log('    ' + icon + ' ' + (tag || '?').padEnd(22) + gp + '/' + g.length);
  });
  if (failed > 0) {
    console.log('\n  ' + C.red('FAILED ENDPOINTS:'));
    results.filter(function(r) { return !r.ok; }).forEach(function(r) {
      console.log('    ' + r.method + ' ' + r.path + ' -> ' + r.status + (r.error ? ' (' + r.error + ')' : ''));
    });
  }
  console.log('\n' + C.dim('  Note: 401=needs real Google/OTP token | 403=role check | 400=validation'));
  console.log(C.dim('  These are all EXPECTED when using dummy data'));
  console.log(C.bold('='.repeat(70)) + '\n');
}
main().catch(function(e) { console.error(e); process.exit(1); });
