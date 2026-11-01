// Read-only regression against the real local API and preview, not fixture responses.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const root = path.join(__dirname, '..');
const api = 'http://127.0.0.1:8000/api/v1/';

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
  const get = async url => {
    const response = await fetch(url, { headers });
    assert.equal(response.status, 200, `GET ${url}`);
    return response.json();
  };
  const bookings = [];
  for (let next = api + 'bookings/?status=checked_in'; next;) {
    const data = await get(next);
    bookings.push(...data.results); next = data.next;
  }
  assert(bookings.length > 0, 'Need a real occupied booking for the read-only check.');
  for (const booking of bookings) {
    assert.equal(booking.status, 'checked_in');
    assert(booking.checked_in_at, 'Occupied booking must have a Stay.');
    const folio = await get(api + `bookings/${booking.id}/folio/`);
    assert.equal(folio.state, 'open');
    assert(folio.folio.lines.length > 0);
    const services = await get(api + `bookings/${booking.id}/services/`);
    assert.equal(services.can_edit, true);
    assert.equal(services.blocked_reason, '');
  }
  const target = bookings.find(row => row.check_in_record_recovered) ?? bookings[0];
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 480, height: 940 } });
  const errors = [], folioResponses = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (response.url().endsWith(`/bookings/${target.id}/folio/`)) folioResponses.push(response.status());
  });
  // Fail if this check ever accidentally tries to create a business transaction.
  await page.route('**/api/v1/**', route => {
    const request = route.request();
    const pathname = new URL(request.url()).pathname;
    const readOnlyPost = /\/auth\/(login|refresh)\/$/.test(pathname) || /\/bookings\/\d+\/transfer-quote\/$/.test(pathname);
    if (!['GET', 'OPTIONS'].includes(request.method()) && !readOnlyPost) {
      errors.push(`Unexpected mutation: ${request.method()} ${new URL(request.url()).pathname}`);
      return route.abort();
    }
    return route.continue();
  });
  try {
    await page.goto('http://127.0.0.1:4173/#/bookings', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    for (const [label, value] of [['Tài khoản', 'admin'], ['Mật khẩu', password]]) {
      const field = page.getByLabel(label, { exact: true });
      await field.click(); await field.press('ControlOrMeta+A');
      await field.pressSequentially(value, { delay: 12 }); await field.press('Tab');
    }
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('checkbox', { name: 'Đang ở', exact: true }).click();
    await page.getByRole('button', { name: new RegExp(`^${target.room.number}.*${target.customer.full_name}`) }).click();
    await page.getByRole('button', { name: 'Thêm dịch vụ', exact: true }).waitFor();
    await page.screenshot({ path: path.join(root, '.artifacts/stay-live-fixed-action.png') });
    const options = await get(api + `bookings/${target.id}/transfer-options/`);
    const destination = options.rooms.find(row => Number(row.room_type.base_rate) > Number(target.nightly_rate)) ?? options.rooms[0];
    assert(destination, 'Need an available room for the read-only transfer preview.');
    await page.getByRole('button', { name: 'Chuyển phòng', exact: true }).click();
    await page.getByRole('button', { name: new RegExp(`^${destination.number}\\s`) }).click();
    const reason = page.getByRole('textbox', { name: 'Lý do chuyển phòng', exact: true });
    await reason.click(); await reason.pressSequentially('Kiem tra xem truoc, khong chuyen khach', { delay: 12 }); await reason.press('Tab');
    const quoted = page.waitForResponse(response => response.url().endsWith(`/bookings/${target.id}/transfer-quote/`));
    await page.getByRole('button', { name: 'Xem chênh lệch', exact: true }).click();
    const quoteResponse = await quoted;
    assert.equal(quoteResponse.status(), 200);
    const preview = await quoteResponse.json();
    assert.equal(Number(preview.new_room_total), Number(preview.current_room_total) + Number(preview.difference));
    await page.getByRole('button', { name: 'Xác nhận chuyển phòng', exact: true }).waitFor();
    await page.screenshot({ path: path.join(root, '.artifacts/stay-live-move-preview.png') });
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Xem chênh lệch', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    assert.equal((await get(api + `bookings/${target.id}/`)).room.id, target.room.id, 'Preview must not transfer the actual guest.');
    await page.getByRole('button', { name: 'Thêm dịch vụ', exact: true }).click();
    await page.getByText('Ghi dịch vụ', { exact: true }).waitFor();
    const catalog = await get(api + 'services/?active=true');
    const service = catalog.results.find(row => row.unit_valid);
    assert(service, 'Need an active service with a valid unit.');
    await page.getByRole('button', { name: new RegExp(`^${service.name}`) }).waitFor();
    await page.screenshot({ path: path.join(root, '.artifacts/stay-live-service-form.png') });
    await page.getByRole('button', { name: 'Quay lại', exact: true }).last().click();
    await page.getByRole('button', { name: 'Ghi dịch vụ', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    const loaded = page.waitForResponse(response => response.url().endsWith(`/bookings/${target.id}/folio/`));
    await page.getByRole('button', { name: 'Trả phòng', exact: true }).click();
    assert.equal((await loaded).status(), 200);
    await page.getByText('Quyết toán lưu trú', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Bổ sung / hủy dịch vụ', exact: true }).waitFor();
    await page.getByText(/Tổng thanh toán/).waitFor();
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(root, '.artifacts/stay-live-folio.png') });
    assert.deepEqual(folioResponses, [200], 'No folio retry loop.');
    assert.deepEqual(errors, []);
    console.log(`PASS: ${bookings.length} real occupied bookings have editable services and a working folio; fixed Add service opens the real catalog; real transfer preview works without moving the guest; no business mutations.`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
