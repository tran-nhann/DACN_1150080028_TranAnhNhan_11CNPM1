// Apply a catalog service to an occupied room using an isolated API fixture.
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const paged = results => ({ count: results.length, next: null, previous: null, results });
const user = { id: 1, username: 'admin', display_name: 'Admin', role: 'admin', role_label: 'Quản trị viên' };
const type = { id: 1, name: 'Superior', capacity: 2, description: '', base_rate: '650000' };
const room = { id: 1, number: '101', floor: 1, room_type: type, condition: 'ready', display_status: 'occupied', notes: '', images: [], amenities: [] };
const booking = { id: 11, code: 'BK-APPLY', room, customer: { id: 1, full_name: 'Nguyễn Minh An' }, start_date: '2026-10-31', end_date: '2026-11-01', guests: 1,
  nightly_rate: '650000', room_total: '650000', status: 'checked_in', status_label: 'Đang ở', checked_in_at: '2026-10-31T07:00:00Z' };
const water = { id: 1, name: 'Nước suối', unit: 'chai', unit_valid: true, unit_price: '15000', category: 'minibar', is_active: true,
  description: 'Nước uống đóng chai', notes: '', usage_count: 0 };
const invalid = { ...water, id: 2, name: 'Dịch vụ thiếu đơn vị', category: 'other', unit: '-', unit_valid: false };

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [], keys = [], searches = [];
  let usages = [];
  page.on('pageerror', error => errors.push(error.message));
  const snap = async name => { await page.mouse.move(1, 1); await page.waitForTimeout(300); await page.screenshot({ path: path.join(__dirname, `../.artifacts/services-apply-${name}.png`) }); };
  const enter = async (input, text) => { await input.click(); await input.press('ControlOrMeta+A'); await input.pressSequentially(text, { delay: 12 }); await input.press('Tab'); };
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), url = new URL(request.url()), endpoint = url.pathname.split('/api/v1/')[1];
    const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
    let body, status = 200;
    if (endpoint === 'auth/login/') body = { access: 'fixture-access', refresh: 'fixture-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'dashboard/') body = { date: '2026-10-31', rooms: { total: 1, ready: 0, occupied: 1, reserved: 0, cleaning: 0, maintenance: 0 }, floors: [], attention_rooms: [], today_bookings: [], arrivals: 0, departures: 0, guests: 1 };
    else if (endpoint === 'services/') body = paged([invalid, { ...water, usage_count: usages.length }]);
    else if (endpoint === 'services/1/') body = { ...water, usage_count: usages.length };
    else if (endpoint === 'bookings/') {
      assert.equal(url.searchParams.get('status'), 'checked_in');
      const search = url.searchParams.get('search') || ''; searches.push(search);
      body = paged(search && !`101 ${booking.customer.full_name}`.includes(search) ? [] : [booking]);
    } else if (endpoint === 'bookings/11/services/' && request.method() === 'POST') {
      const data = request.postDataJSON();
      assert.deepEqual(data, { service_id: 1, quantity: 2, expected_unit_price: 15000 });
      keys.push(request.headers()['idempotency-key']); assert(keys.at(-1));
      usages = [{ id: 8, service_id: 1, name: water.name, unit: 'chai', unit_price: '15000', quantity: 2,
        total: '30000', status: 'active', created_at: '2026-10-31T09:00:00Z', created_by: 'Admin', cancelled_at: null, cancelled_by: null, cancel_reason: '' }];
      body = usages[0]; status = 201;
    } else if (endpoint === 'bookings/11/services/') body = { ...paged(usages), room_total: '650000', service_total: usages.length ? '30000' : '0', estimated_total: usages.length ? '680000' : '650000', can_edit: true };
    else throw new Error(`Unexpected fixture request ${request.method()} ${endpoint}`);
    await route.fulfill({ status, contentType: 'application/json', headers, body: JSON.stringify(body) });
  });
  try {
    await page.goto('http://127.0.0.1:4173/#/profile/services', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await enter(page.getByLabel('Tài khoản', { exact: true }), 'admin');
    await enter(page.getByLabel('Mật khẩu', { exact: true }), 'preview');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByText('Dịch vụ', { exact: true }).click();
    const apply = page.getByRole('button', { name: 'Áp dụng', exact: true });
    await apply.nth(1).waitFor(); assert(await apply.first().isDisabled()); await snap('catalog');
    await apply.nth(1).click();
    await page.getByText('Áp dụng dịch vụ', { exact: true }).waitFor();
    const search = page.getByRole('textbox', { name: /Số phòng hoặc tên khách đang ở/ });
    await enter(search, '999'); await page.getByText('Không có phòng đang ở phù hợp', { exact: true }).waitFor();
    await enter(search, '101');
    await page.getByRole('button', { name: /Phòng 101.*Nguyễn Minh An/ }).click();
    await page.getByText('Phòng 101 · Nguyễn Minh An', { exact: true }).waitFor();
    await enter(page.getByRole('textbox', { name: /Số lượng/ }), '2');
    const save = page.getByRole('button', { name: 'Ghi nhận', exact: true });
    const before = await save.boundingBox();
    await page.mouse.move(180, 500); await page.mouse.wheel(0, 600); await page.waitForTimeout(300);
    assert.equal((await save.boundingBox()).y, before.y); await snap('quantity');
    await save.click();
    await page.getByRole('button', { name: 'Ghi dịch vụ', exact: true }).waitFor();
    await page.getByText('680.000 ₫', { exact: true }).waitFor();
    assert.equal(usages.length, 1); assert.equal(keys.length, 1); assert(searches.includes('999') && searches.includes('101'));
    await snap('recorded'); assert.deepEqual(errors, []);
    console.log('PASS: catalog Apply action, invalid unit disabled, occupied room search, preselected service and customer, fixed submit, quantity 2 charged to booking 11 and updated totals. Fixture only; no hotel records changed.');
  } catch (error) {
    await snap('failed');
    console.error(JSON.stringify(await page.locator('[role]').evaluateAll(elements => elements.map(e => ({ role: e.getAttribute('role'), name: e.getAttribute('aria-label') || e.innerText })).slice(-20))));
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
