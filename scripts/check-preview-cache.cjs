// Verify an existing browser with a stale worker receives the current admin UI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const root = path.join(__dirname, '..');
const base = 'http://127.0.0.1:4173';
const workerPath = path.join(root, 'mobile/build/web/legacy-preview-fixture.js');

(async () => {
  const secret = fs.readFileSync(path.join(root, 'backend/.env'), 'utf8').match(/^DEMO_PASSWORD=(.+)$/m)?.[1].trim();
  assert(secret, 'Missing local demo credentials.');
  const build = (await fetch(base)).headers.get('x-aster-build');
  assert(build, 'The preview must serve a build identifier.');
  for (const resource of ['/', '/flutter_bootstrap.js', '/main.dart.js']) {
    const response = await fetch(base + resource, { headers: { 'If-Modified-Since': 'Wed, 01 Jan 2031 00:00:00 GMT' } });
    assert.equal(response.status, 200);
    assert(response.headers.get('cache-control').includes('no-store'));
  }
  fs.writeFileSync(workerPath, `
    self.addEventListener('install', () => self.skipWaiting());
    self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
    self.addEventListener('fetch', event => {
      const url = new URL(event.request.url);
      if (['/flutter_bootstrap.js', '/main.dart.js'].includes(url.pathname) && !url.searchParams.has('build')) {
        event.respondWith(new Response('window.stalePreview = true;', {headers: {'Content-Type': 'application/javascript'}}));
      }
      if (url.pathname.startsWith('/assets/') && url.pathname.endsWith('MaterialIcons-Regular.otf')) {
        event.respondWith(new Response('stale icon font'));
      }
    });
  `);
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 480, height: 940 } });
  const scripts = [], fonts = [];
  const errors = [];
  page.on('request', request => {
    const url = new URL(request.url());
    if (['/flutter_bootstrap.js', '/main.dart.js'].includes(url.pathname)) scripts.push(url);
    if (url.pathname.endsWith('MaterialIcons-Regular.otf')) fonts.push(url);
  });
  page.on('pageerror', error => errors.push(error.message));
  try {
    await page.goto(`${base}/#/rooms`, { waitUntil: 'networkidle' });
    await page.evaluate(async () => {
      await navigator.serviceWorker.register('/legacy-preview-fixture.js', { scope: '/' });
      await navigator.serviceWorker.ready;
      if (!navigator.serviceWorker.controller) await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, { once: true }));
    });
    scripts.length = 0;
    await page.reload({ waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    for (const [label, value] of [['Tài khoản', 'admin'], ['Mật khẩu', secret]]) {
      const input = page.getByLabel(label, { exact: true });
      await input.click(); await input.press('ControlOrMeta+A');
      await input.pressSequentially(value, { delay: 12 }); await input.press('Tab');
    }
    const loggedIn = page.waitForResponse(response => response.url().endsWith('/auth/login/') && response.request().method() === 'POST');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    assert.equal((await (await loggedIn).json()).user.role, 'admin');
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.waitForURL(`${base}/#/rooms`);
    assert.equal(page.url(), `${base}/#/rooms`);
    await page.getByRole('button', { name: /^101\b/ }).click();
    const edit = page.getByRole('button', { name: 'Sửa phòng', exact: true });
    await edit.waitFor();
    await page.screenshot({ path: path.join(root, '.artifacts/admin-room-after-cache-fix.png') });
    await edit.click();
    await page.getByRole('button', { name: 'Chọn ảnh phòng', exact: true }).waitFor();
    assert(scripts.some(url => url.pathname === '/main.dart.js'));
    assert(scripts.every(url => url.searchParams.get('build') === build));
    assert(fonts.length > 0 && fonts.every(url => url.pathname.startsWith(`/__build/${build}/`)));
    assert.equal(await page.evaluate(() => window.stalePreview), undefined);
    assert.deepEqual(errors, []);
    console.log(`PASS: stale worker bypassed, conditional requests return current files, real admin opens room editor at /#/rooms (build ${build}). No hotel records changed.`);
  } finally {
    await browser.close();
    fs.unlinkSync(workerPath);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
