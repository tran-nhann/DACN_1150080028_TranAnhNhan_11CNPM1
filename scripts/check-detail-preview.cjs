// UI verification against the local API. No hotel records are created or changed.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const root = path.join(__dirname, '..');
const secret = fs.readFileSync(path.join(root, 'backend/.env'), 'utf8').match(/^DEMO_PASSWORD=(.+)$/m)?.[1].trim();
const escape = text => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

(async () => {
  assert(secret, 'Local demo credentials are missing.');
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/api/v1/**', async route => {
    const request = route.request();
    const endpoint = new URL(request.url()).pathname;
    if (!['GET', 'OPTIONS', 'HEAD'].includes(request.method()) && !endpoint.includes('/auth/')) {
      errors.push(`Unexpected write: ${request.method()} ${endpoint}`);
      return route.abort();
    }
    return route.continue();
  });
  const snap = async name => {
    await page.mouse.move(1, 1); await page.waitForTimeout(350);
    await page.screenshot({ path: path.join(root, `.artifacts/review-${name}.png`) });
  };
  try {
    await page.goto('http://127.0.0.1:4173', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    for (const [label, value] of [['Tài khoản', 'admin'], ['Mật khẩu', secret]]) {
      const input = page.getByLabel(label, { exact: true });
      await input.click(); await input.pressSequentially(value, { delay: 2 }); await input.press('Tab');
    }
    const login = page.waitForResponse(response => response.url().endsWith('/auth/login/') && response.request().method() === 'POST');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    const token = (await (await login).json()).access;
    const get = async endpoint => {
      const response = await fetch(`http://127.0.0.1:8000/api/v1/${endpoint}`, { headers: { Authorization: `Bearer ${token}` } });
      assert.equal(response.status, 200, endpoint); return response.json();
    };
    const dashboard = await get('dashboard/');
    const bookings = await get('bookings/');
    assert(bookings.count > 0, 'A booking is needed to verify linked details.');
    const booking = bookings.results[0];
    const guest = await get(`customers/${booking.customer.id}/`);
    await page.getByRole('button', { name: /Phòng sẵn sàng/ }).waitFor(); await snap('dashboard');
    const catalog = await get('services/?active=true');
    assert(catalog.count > 0, 'Demo services should be available.');
    const services = await get(`bookings/${booking.id}/services/`);
    assert.equal(Number(services.room_total), Number(booking.room_total));
    assert.equal(Number(services.estimated_total), Number(services.room_total) + Number(services.service_total));
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByRole('button', { name: 'Khách hàng', exact: true }).click();
    await page.getByRole('button', { name: 'Quay lại Thêm', exact: true }).waitFor(); await snap('customers-back');
    await page.getByRole('button', { name: 'Quay lại Thêm', exact: true }).click();
    await page.getByRole('button', { name: 'Đăng xuất', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Khách hàng', exact: true }).click();
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByRole('button', { name: 'Đăng xuất', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Khách hàng', exact: true }).click();
    await page.goBack();
    await page.getByRole('button', { name: 'Đăng xuất', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Dịch vụ', exact: true }).click();
    const firstService = catalog.results[0];
    await page.getByRole('button', { name: new RegExp(escape(firstService.name)) }).click();
    await page.getByRole('button', { name: 'Sửa dịch vụ', exact: true }).click();
    const priceInput = page.getByRole('textbox', { name: /Đơn giá/ });
    await priceInput.click();
    await page.waitForFunction(() => document.activeElement && 'value' in document.activeElement && document.activeElement.value !== '');
    assert.equal(Number(await priceInput.inputValue()), Number(firstService.unit_price));
    await snap('catalog-service');
    await page.getByRole('combobox', { name: /Đơn vị/ }).or(page.getByRole('button', { name: /Đơn vị/ })).first().click();
    await page.getByRole('menuitem', { name: /kg/ }).waitFor(); await snap('unit-options');
    await page.keyboard.press('Escape');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('button', { name: 'Quay lại Thêm', exact: true }).click();
    await page.getByRole('tab', { name: 'Hôm nay', exact: true }).click();
    await page.getByRole('button', { name: /Đến$/ }).click();
    await page.getByText('Khách đến', { exact: true }).waitFor(); await snap('arrivals');
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    if (dashboard.floors.length) {
      const floor = dashboard.floors[0].floor;
      const response = page.waitForResponse(item => item.url().includes('/rooms/?') && new URL(item.url()).searchParams.get('floor') === String(floor));
      await page.getByRole('button', { name: new RegExp(`Tầng ${floor}`) }).click();
      const result = await (await response).json();
      assert(result.results.every(room => room.floor === floor));
      const room = result.results[0];
      await page.getByRole('button', { name: new RegExp(`^${escape(room.number)}`) }).click();
      await page.getByText('Vận hành', { exact: true }).waitFor(); await snap('room');
      await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    }
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: new RegExp(`^${escape(booking.room.number)}.*${escape(booking.customer.full_name)}`) }).first().click();
    await page.getByText(booking.code, { exact: true }).waitFor();
    const price = await page.getByText('Tiền phòng', { exact: true }).boundingBox();
    assert(price && price.y > 0 && price.y + price.height < 750, 'Price should be in the initial detail viewport.');
    await snap('booking');
    await page.getByRole('button', { name: 'Hồ sơ khách', exact: true }).click();
    await page.getByText(guest.phone, { exact: true }).waitFor(); await snap('guest');
    if (guest.email) await page.getByText(guest.email, { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByText(booking.code, { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByRole('button', { name: 'Khách hàng', exact: true }).click();
    await page.getByRole('button', { name: new RegExp(escape(guest.full_name)) }).first().click();
    await page.getByText('Hồ sơ khách', { exact: true }).waitFor();
    await page.getByRole('button', { name: new RegExp(`^${escape(booking.room.number)}.*${escape(guest.full_name)}`) }).first().click();
    await page.getByText(booking.code, { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByText('Hồ sơ khách', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    assert.deepEqual(errors, []);
    console.log('PASS: local API data matches service catalog and estimates, dashboard filters, room detail, booking identity, guest contact and guest booking history. No business writes.');
  } catch (error) {
    await snap('failed');
    console.error(JSON.stringify(await page.locator('[role]').evaluateAll(elements => elements.map(element => ({ role: element.getAttribute('role'), label: element.getAttribute('aria-label') })).slice(-25))));
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
