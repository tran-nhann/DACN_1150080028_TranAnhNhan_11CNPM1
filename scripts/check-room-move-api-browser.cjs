// Invoked by pytest's live_server against HotelManagementTest. Every HTTP reply is real DRF/SQL.
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const api = process.env.ROOM_MOVE_API_URL;
assert(api, 'Run via pytest RUN_BROWSER_E2E=1, not against the hotel database.');
const server = new URL(api);
assert(['localhost', '127.0.0.1'].includes(server.hostname) && server.port && server.port !== '8000', 'Only the isolated pytest live server is allowed.');
const bookingId = Number(process.env.ROOM_MOVE_BOOKING_ID), targetId = Number(process.env.ROOM_MOVE_TARGET_ID);

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 480, height: 940 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (response.url().includes('/api/v1/') && response.status() >= 400) errors.push(`Unexpected API status ${response.status()} at ${new URL(response.url()).pathname}`);
  });
  // Relay the existing web build's API calls to pytest's isolated real HTTP server.
  await page.route('**/api/v1/**', async route => {
    const original = new URL(route.request().url());
    const response = await route.fetch({ url: api + original.pathname.split('/api/v1/')[1] + original.search });
    await route.fulfill({ response });
  });
  const enter = async (field, value) => { await field.click(); await field.press('ControlOrMeta+A'); await field.pressSequentially(value, { delay: 12 }); await field.press('Tab'); };
  const snap = async name => { await page.waitForTimeout(250); await page.screenshot({ path: path.join(__dirname, `../.artifacts/room-move-sql-${name}.png`) }); };
  try {
    await page.goto('http://127.0.0.1:4173/#/bookings', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await enter(page.getByLabel('Tài khoản', { exact: true }), 'admin');
    await enter(page.getByLabel('Mật khẩu', { exact: true }), 'TestingOnly!2026');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Khách chuyển phòng/ }).click();
    await page.getByRole('button', { name: 'Chuyển phòng', exact: true }).click();
    await page.getByRole('button', { name: /^202\s/ }).click();
    await enter(page.getByRole('textbox', { name: 'Lý do chuyển phòng', exact: true }), 'Khách yêu cầu nâng hạng');
    const quoted = page.waitForResponse(response => response.url().endsWith(`/bookings/${bookingId}/transfer-quote/`));
    await page.getByRole('button', { name: 'Xem chênh lệch', exact: true }).click();
    assert.equal((await quoted).status(), 200);
    await page.getByText(/600.000/).waitFor(); await snap('quote');
    const moved = page.waitForResponse(response => response.url().endsWith(`/bookings/${bookingId}/transfer/`));
    await page.getByRole('button', { name: 'Xác nhận chuyển phòng', exact: true }).click();
    const movedResponse = await moved;
    assert.equal(movedResponse.status(), 201);
    const booking = (await movedResponse.json()).booking;
    assert.equal(booking.room.id, targetId); assert.equal(booking.room_total, '2550000');
    assert.equal(booking.service_total, '30000'); assert.equal(booking.room_moves.length, 1);
    assert.deepEqual(booking.room_segments.map(row => row.nights), [1, 2]);
    await page.getByText('Phòng 202', { exact: true }).waitFor(); await snap('moved');
    await page.getByRole('button', { name: 'Trả phòng', exact: true }).click();
    await page.getByText(/^Phòng 101 ·/).waitFor(); await page.getByText(/^Phòng 202 ·/).waitFor(); await snap('folio');
    await page.getByRole('combobox', { name: /Hình thức thanh toán/ }).or(page.getByRole('button', { name: /Hình thức thanh toán/ })).first().click();
    await page.getByRole('menuitem', { name: 'Tiền mặt', exact: true }).click();
    await page.mouse.move(220, 600); await page.mouse.wheel(0, 650); await page.waitForTimeout(300);
    await page.getByRole('checkbox', { name: /Đã nhận đủ/ }).click();
    const checkedOut = page.waitForResponse(response => response.url().endsWith(`/bookings/${bookingId}/check-out/`));
    await page.getByRole('button', { name: 'Chốt hóa đơn & trả phòng', exact: true }).click();
    const receiptResponse = await checkedOut;
    assert.equal(receiptResponse.status(), 201);
    const receipt = (await receiptResponse.json()).invoice;
    assert.equal(receipt.total, '2580000'); assert.equal(receipt.service_total, '30000');
    assert.equal(receipt.lines.length, 3); assert.equal(receipt.payment.amount, receipt.total);
    assert.equal(receipt.lines[2].source_usage_id, Number(process.env.ROOM_MOVE_USAGE_ID));
    await page.getByText('Hóa đơn đã thanh toán', { exact: true }).waitFor(); await snap('invoice');
    assert.deepEqual(errors, []);
    console.log('PASS: Edge → real DRF → SQL Server test database: transfer with 600000 difference, same service and stay, two room segments, single final receipt.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
