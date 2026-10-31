const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    page.on('pageerror', error => console.error('Browser error:', error.message));
    await page.goto('http://127.0.0.1:4173', { waitUntil: 'networkidle', timeout: 60000 });
    await page.locator('flutter-view').waitFor({ timeout: 60000 });
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.evaluate(element => element.click());
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).waitFor({ timeout: 30000 });
    fs.mkdirSync(path.join(__dirname, '../docs/screenshots'), { recursive: true });
    await page.screenshot({ path: path.join(__dirname, '../docs/screenshots/login-desktop.png') });
    console.log(JSON.stringify(await page.locator('[role],input').evaluateAll(elements => elements.map(element => ({tag: element.tagName, role: element.getAttribute('role'), label: element.getAttribute('aria-label'), text: (element.innerText || '').slice(0, 100)}))), null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
