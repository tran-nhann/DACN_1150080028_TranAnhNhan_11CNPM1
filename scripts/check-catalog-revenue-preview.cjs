// Real API/Edge check. Only a dedicated temporary service is created and deleted.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const root = path.join(__dirname, '..');
const api = 'http://127.0.0.1:8000/api/v1/';
const preview = 'http://127.0.0.1:4173';
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

(async () => {
  const password = fs.readFileSync(path.join(root, 'backend/.env'), 'utf8').match(/^DEMO_PASSWORD=(.+)$/m)?.[1].trim();
  assert(password, 'Missing local demo credentials.');
  const login = await fetch(api + 'auth/login/', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password }),
  });
  assert.equal(login.status, 200);
  const session = await login.json();
  const headers = { Authorization: `Bearer ${session.access}` };
  const jsonHeaders = { ...headers, 'Content-Type': 'application/json' };
  const get = async endpoint => {
    const response = await fetch(api + endpoint, { headers });
    assert.equal(response.status, 200, endpoint);
    return response.json();
  };
  const [rooms, estimate] = await Promise.all([get('rooms/'), get('reports/revenue-estimate/')]);
  assert.equal(Number(estimate.estimated_total), Number(estimate.room_total) + Number(estimate.service_total) + Number(estimate.planned_service_total || 0));
  assert(Number(estimate.collected_total) >= 0);
  assert.equal(Number(estimate.collected_total), Number(estimate.cash_total) + Number(estimate.bank_total));
  assert.equal(estimate.daily.reduce((sum, day) => sum + Number(day.total), 0), Number(estimate.estimated_total));
  const target = rooms.results.find(room => room.floor === 2) ?? rooms.results[0];
  assert(target);
  const name = `ZZZ_UI_${Date.now()}`;
  const created = await fetch(api + 'services/', {
    method: 'POST', headers: jsonHeaders,
    body: JSON.stringify({ name, unit: 'kg', unit_price: '45000', category: 'laundry', description: 'Dịch vụ kiểm tra giao diện', notes: 'Dữ liệu thử, xóa sau kiểm tra' }),
  });
  assert.equal(created.status, 201);
  let serviceId = (await created.json()).id;
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 480, height: 940 } });
  const errors = [], queries = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => {
    const url = new URL(request.url());
    if (url.pathname === '/api/v1/rooms/') queries.push(url.searchParams);
  });
  const snap = async name => {
    await page.mouse.move(1, 1); await page.waitForTimeout(350);
    await page.screenshot({ path: path.join(root, `.artifacts/catalog-${name}.png`) });
  };
  const type = async (input, value) => {
    await input.click(); await input.press('ControlOrMeta+A');
    await input.pressSequentially(value, { delay: 12 }); await input.press('Tab');
  };
  const dropdown = label => page.getByRole('combobox', { name: label }).or(page.getByRole('button', { name: label })).first();
  try {
    await page.goto(preview + '/#/rooms', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await type(page.getByLabel('Tài khoản', { exact: true }), 'admin');
    await type(page.getByLabel('Mật khẩu', { exact: true }), password);
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(250);
    await dropdown(/Hạng phòng/).click();
    await page.getByRole('menuitem', { name: target.room_type.name, exact: true }).click();
    await dropdown(/Tầng/).click();
    await page.getByRole('menuitem', { name: `Tầng ${target.floor}`, exact: true }).click();
    await page.waitForTimeout(500);
    assert(queries.some(query => query.get('room_type') === String(target.room_type.id) && query.get('floor') === String(target.floor)));
    await snap('room-filters');
    await page.getByRole('button', { name: 'Xóa bộ lọc', exact: true }).click();
    await page.getByRole('button', { name: /^Bộ lọc phòng/ }).click();
    await page.getByRole('button', { name: /^101\b/ }).waitFor();
    await page.waitForLoadState('networkidle');
    await snap('room-cards');
    await page.setViewportSize({ width: 390, height: 844 });
    await snap('room-cards-390');

    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByText('Dịch vụ', { exact: true }).click();
    await type(page.getByRole('textbox').first(), name);
    await page.getByRole('button', { name: new RegExp(escape(name)) }).click();
    await page.getByRole('button', { name: 'Sửa dịch vụ', exact: true }).click();
    const chooser = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: 'Chọn ảnh dịch vụ', exact: true }).click();
    await (await chooser).setFiles(path.join(root, 'backend/hotel/demo_assets/rooms/superior-bedroom.jpg'));
    await page.waitForTimeout(400);
    const saved = page.waitForResponse(response => response.url().endsWith(`/services/${serviceId}/`) && response.request().method() === 'PATCH');
    await page.getByRole('button', { name: 'Lưu', exact: true }).click();
    const saveResponse = await saved;
    assert.equal(saveResponse.status(), 200, await saveResponse.text());
    const item = await saveResponse.json();
    assert(item.image_url && item.category === 'laundry' && item.description);
    const uploadedUrl = new URL(item.image_url, api);
    await page.getByText('Chi tiết dịch vụ', { exact: true }).waitFor();
    await snap('service-detail');
    await page.getByRole('button', { name: 'Sửa dịch vụ', exact: true }).click();
    await page.mouse.move(230, 550); await page.mouse.wheel(0, 600); await page.waitForTimeout(400);
    await snap('service-form-pinned-save');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Xóa', exact: true }).click();
    const deleted = page.waitForResponse(response => response.url().endsWith(`/services/${serviceId}/`) && response.request().method() === 'DELETE');
    await page.getByRole('button', { name: 'Xóa dịch vụ', exact: true }).click();
    assert.equal((await deleted).status(), 204);
    serviceId = null;
    assert.equal((await fetch(uploadedUrl)).status, 404, 'Deleting the temporary service must also remove its photo.');
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByText('Doanh thu ước tính', { exact: true }).click();
    await page.getByText('Tổng giá trị dự kiến', { exact: true }).waitFor();
    await snap('revenue-month');
    await page.getByRole('button', { name: '7 ngày', exact: true }).click();
    await page.mouse.move(230, 580); await page.mouse.wheel(0, 420); await page.waitForTimeout(400);
    await snap('revenue-chart');
    assert.deepEqual(errors, []);
    console.log('PASS: combined room type/floor filters, redesigned photo cards at 480/390px, service profile/photo edit/delete, fixed save footer, monthly/week revenue and chart. Temporary service deleted; rooms/bookings unchanged.');
  } catch (error) {
    await snap('failed');
    console.error((await page.locator('body').innerText()).slice(-6500));
    throw error;
  } finally {
    await browser.close();
    if (serviceId) {
      const cleanup = await fetch(api + `services/${serviceId}/`, { method: 'DELETE', headers });
      assert([204, 404].includes(cleanup.status), 'Temporary service cleanup failed.');
    }
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
