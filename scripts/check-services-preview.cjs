// Complete service workflow with an isolated API fixture; no hotel database writes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const output = path.join(__dirname, '../docs/screenshots');
const paged = results => ({ count: results.length, next: null, previous: null, results });
const staff = { id: 1, username: 'admin', display_name: 'Anh Nhân', role: 'admin', role_label: 'Quản trị viên' };
const room = { id: 1, number: '101', floor: 1, room_type: { id: 1, name: 'Deluxe', description: '', capacity: 2, base_rate: '950000' }, condition: 'ready', display_status: 'occupied', notes: '' };
const booking = { id: 11, code: 'BK-SERVICE', room, customer: { id: 1, full_name: 'Nguyễn Minh An' }, start_date: '2026-10-23', end_date: '2026-10-25', guests: 2, nightly_rate: '950000', room_total: '1900000', status: 'checked_in', status_label: 'Đang ở', checked_in_at: '2026-10-23T08:00:00Z', created_at: '2026-10-20T08:00:00Z' };

async function install(page, user = staff) {
  const state = { catalog: [{ id: 1, name: 'Giặt ủi', unit: 'kg', unit_price: '30000', is_active: true }], usages: [], attempts: 0, keys: [] };
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), url = new URL(request.url()), endpoint = url.pathname.split('/api/v1/')[1], method = request.method();
    let body = {}, status = 200;
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });
    if (endpoint === 'auth/login/') body = { access: 'fixture-access', refresh: 'fixture-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'dashboard/') body = { date: '2026-10-24', rooms: { total: 1, ready: 0, occupied: 1, reserved: 0, cleaning: 0, maintenance: 0 }, floors: [], attention_rooms: [], arrivals: 0, departures: 0, guests: 2, today_bookings: [] };
    else if (endpoint === 'bookings/') body = paged([booking]);
    else if (endpoint === 'service-units/') body = { units: [
      { value: 'kg', label: 'kg', example: 'Giặt ủi theo cân' },
      { value: 'suất', label: 'Suất', example: 'Ăn sáng' },
      { value: 'chai', label: 'Chai', example: 'Nước suối' },
    ] };
    else if (endpoint === 'rooms/availability/') body = paged([room]);
    else if (endpoint === 'services/' && method === 'GET') body = paged(state.catalog.filter(item => (!url.searchParams.get('active') || String(item.is_active) === url.searchParams.get('active')) && item.name.toLowerCase().includes((url.searchParams.get('search') || '').toLowerCase())));
    else if (endpoint === 'services/' && method === 'POST') { body = { id: 2, ...request.postDataJSON() }; state.catalog.push(body); status = 201; }
    else if (/^services\/\d+\/$/.test(endpoint) && method === 'PATCH') { body = state.catalog.find(item => item.id === Number(endpoint.split('/')[1])); Object.assign(body, request.postDataJSON()); }
    else if (endpoint === 'bookings/11/services/' && method === 'GET') {
      const total = state.usages.filter(item => item.status === 'active').reduce((sum, item) => sum + Number(item.total), 0);
      body = { ...paged(state.usages), room_total: '1900000', service_total: String(total), estimated_total: String(1900000 + total), can_edit: user.role !== 'manager' };
    } else if (endpoint === 'bookings/11/services/' && method === 'POST') {
      state.attempts++; const key = request.headers()['idempotency-key']; assert(key); state.keys.push(key);
      const data = request.postDataJSON(); assert.equal(data.expected_unit_price, 30000); assert.equal(data.quantity, 2);
      if (!state.usages.length) state.usages.push({ id: 21, service_id: 1, name: 'Giặt ủi', unit: 'kg', unit_price: '30000', quantity: 2, total: '60000', status: 'active', created_at: '2026-10-24T09:00:00Z', created_by: 'Minh Anh', cancelled_at: null, cancelled_by: null, cancel_reason: '' });
      if (state.attempts === 1) { status = 503; body = { error: { message: 'Chưa nhận được kết quả. Thử lại.' } }; }
      else { assert.equal(state.keys[0], key); body = state.usages[0]; }
    } else if (endpoint === 'bookings/11/services/21/cancel/') {
      const data = request.postDataJSON(); assert.equal(data.reason, 'Nhập nhầm');
      body = state.usages[0]; Object.assign(body, { status: 'cancelled', cancelled_at: '2026-10-24T10:00:00Z', cancelled_by: 'Anh Nhân', cancel_reason: data.reason });
    } else throw new Error(`Unmocked API ${method} ${endpoint}`);
    await route.fulfill({ status, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' }, body: JSON.stringify(body) });
  });
  return state;
}
async function type(locator, value) {
  await locator.click(); await locator.press('ControlOrMeta+A'); await locator.pressSequentially(value, { delay: 4 }); await locator.press('Tab');
}
async function login(page) {
  await page.goto('http://127.0.0.1:4173', { waitUntil: 'networkidle' });
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  await type(page.getByLabel('Tài khoản', { exact: true }), 'admin'); await type(page.getByLabel('Mật khẩu', { exact: true }), 'preview');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
}
async function openServices(page) {
  await page.getByRole('button', { name: /^101.*Nguyễn Minh An/ }).click();
  await page.getByRole('button', { name: /^Dịch vụ/ }).click();
  await page.getByText('Tạm tính', { exact: true }).waitFor();
}
(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const errors = []; let page;
  try {
    page = await browser.newPage({ viewport: { width: 390, height: 844 } }); page.on('pageerror', error => errors.push(error.message));
    const state = await install(page); await login(page); await openServices(page);
    const snap = async name => { await page.mouse.move(1, 1); await page.waitForTimeout(400); await page.screenshot({ path: path.join(output, `services-${name}.png`) }); };
    await page.getByRole('button', { name: 'Ghi dịch vụ', exact: true }).click();
    await page.getByRole('button', { name: /Giặt ủi/ }).click();
    await type(page.getByRole('textbox', { name: /Số lượng/ }), '2'); await snap('add');
    await page.getByRole('button', { name: 'Ghi nhận', exact: true }).click();
    await page.getByText('Chưa nhận được kết quả. Thử lại.', { exact: true }).last().waitFor(); await snap('retry');
    await page.getByRole('button', { name: 'Ghi nhận', exact: true }).click();
    await page.getByRole('button', { name: 'Ghi dịch vụ', exact: true }).waitFor();
    assert.equal(state.usages.length, 1); assert.equal(state.attempts, 2); assert.equal(state.keys[0], state.keys[1]);
    await snap('summary');
    await page.getByRole('button', { name: 'Hủy khoản', exact: true }).click();
    await page.getByRole('button', { name: 'Hủy khoản', exact: true }).click();
    await page.getByText('Nhập lý do.', { exact: true }).last().waitFor();
    await type(page.getByRole('textbox', { name: /Lý do/ }), 'Nhập nhầm'); await snap('cancel');
    await page.getByRole('button', { name: 'Hủy khoản', exact: true }).click();
    await page.getByText('Đã hủy', { exact: true }).waitFor(); await snap('history');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByRole('button', { name: 'Dịch vụ', exact: true }).click(); await snap('catalog');
    await page.getByRole('button', { name: /Giặt ủi/ }).click();
    await page.getByRole('button', { name: 'Sửa dịch vụ', exact: true }).click();
    await type(page.getByRole('textbox', { name: /Đơn giá/ }), '45000');
    await page.getByRole('switch', { name: 'Đang bán', exact: true }).click();
    await page.getByRole('button', { name: 'Lưu', exact: true }).click();
    await page.getByText('Chi tiết dịch vụ', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('checkbox', { name: 'Ngừng bán', exact: true }).click();
    await page.getByRole('button', { name: /Giặt ủi/ }).waitFor();
    assert.equal(state.catalog[0].is_active, false); assert.equal(state.usages[0].unit_price, '30000');
    await page.getByRole('button', { name: 'Thêm dịch vụ', exact: true }).click();
    await type(page.getByRole('textbox', { name: /Tên dịch vụ/ }), 'Ăn sáng');
    await page.getByRole('combobox', { name: /Đơn vị/ }).or(page.getByRole('button', { name: /Đơn vị/ })).first().click();
    await snap('unit-options');
    await page.getByRole('menuitem', { name: /Suất/ }).click();
    await type(page.getByRole('textbox', { name: /Đơn giá/ }), '60000'); await snap('catalog-form');
    const created = page.waitForResponse(response => response.url().endsWith('/services/') && response.request().method() === 'POST');
    await page.getByRole('button', { name: 'Lưu', exact: true }).click(); await created;
    await page.getByRole('button', { name: 'Thêm dịch vụ', exact: true }).waitFor(); assert.equal(state.catalog.length, 2);
    await page.getByRole('button', { name: /Ăn sáng/ }).waitFor();
    assert.equal(state.catalog[1].unit, 'suất');
    await page.close();
    page = await browser.newPage({ viewport: { width: 320, height: 700 }, reducedMotion: 'reduce' });
    page.on('pageerror', error => errors.push(error.message));
    await install(page, { ...staff, role: 'manager', role_label: 'Quản lý' }); await login(page); await openServices(page);
    assert.equal(await page.getByRole('button', { name: 'Ghi dịch vụ', exact: true }).count(), 0);
    await snap('manager'); assert.deepEqual(errors, []);
    console.log('PASS: add service after lost response reuses key, totals, required cancellation reason and history, admin catalog create/price/deactivate, manager read-only, narrow reduced-motion UI. No business DB writes.');
  } catch (error) {
    if (page && !page.isClosed()) {
      await page.screenshot({ path: path.join(__dirname, '../.artifacts/services-preview-failed.png') });
      console.error(JSON.stringify(await page.locator('[role]').evaluateAll(elements => elements.map(element => ({ role: element.getAttribute('role'), text: element.getAttribute('aria-label') || element.innerText })).slice(-25))));
    }
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
