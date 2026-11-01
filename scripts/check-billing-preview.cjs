// Isolated browser workflow; SQL Server behavior is checked by test_billing.py.
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const base = 'http://127.0.0.1:4173';
const paged = results => ({ count: results.length, next: null, previous: null, results });
const user = { id: 1, username: 'admin', display_name: 'Thu ngân thử', role: 'admin', role_label: 'Quản trị viên' };
const type = { id: 1, name: 'Superior', description: '', capacity: 2, base_rate: '650000' };
const room = { id: 1, number: '101', floor: 1, room_type: type, condition: 'ready', display_status: 'occupied', notes: '', images: [],
  updated_at: '2026-10-31T07:00:00Z', description: '', amenities: [], area: 28, bed_type: 'queen', bed_count: 1, view: 'Vườn' };
const guest = { id: 1, full_name: 'Khách kiểm tra checkout', phone: '0901234567', email: '', notes: '' };
const booking = { id: 1, code: 'BK-CHECKOUT', room, customer: guest, start_date: '2026-10-29', end_date: '2026-10-31', guests: 2,
  nightly_rate: '650000', room_total: '1300000', nights: 2, status: 'checked_in', status_label: 'Đang ở',
  checked_in_at: '2026-10-29T08:00:00Z', checked_out_at: null, created_at: '2026-10-28T08:00:00Z' };
const lines = [
  { kind: 'room', source_usage_id: null, name: 'Phòng 101', quantity: 2, unit: 'đêm', unit_price: '650000', total: '1300000' },
  { kind: 'service', source_usage_id: 3, name: 'Nước suối', quantity: 2, unit: 'chai', unit_price: '15000', total: '30000' },
];
const folio = { booking_id: 1, booking_code: booking.code, guest_name: guest.full_name, guest_phone: guest.phone,
  room_number: '101', room_type: type.name, start_date: booking.start_date, end_date: booking.end_date,
  nights: 2, room_total: '1300000', service_total: '30000', total: '1330000', currency: 'VND',
  lines, quote_token: 'a'.repeat(64), can_checkout: true, blocked_reason: '', billing_policy: 'Tính đủ số đêm đã đặt/gia hạn, kể cả trả sớm.' };

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [], keys = [], payloads = [];
  let invoice, writes = 0, cleanWrites = 0, timelineReads = 0;
  page.on('pageerror', error => errors.push(error.message));
  const snap = async name => { await page.mouse.move(1, 1); await page.waitForTimeout(350); await page.screenshot({ path: path.join(__dirname, `../.artifacts/billing-${name}.png`) }); };
  const scroll = async amount => { await page.mouse.move(190, 540); await page.mouse.wheel(0, amount); await page.waitForTimeout(300); };
  const typeInput = async (input, value) => { await input.click(); await input.press('ControlOrMeta+A'); await input.pressSequentially(value, { delay: 12 }); await input.press('Tab'); };
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), url = new URL(request.url()), endpoint = url.pathname.split('/api/v1/')[1];
    const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
    let body, status = 200;
    if (endpoint === 'auth/login/') body = { access: 'fixture-access', refresh: 'fixture-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'dashboard/') body = { date: '2026-10-31', rooms: { total: 1, ready: room.display_status === 'ready' ? 1 : 0,
      occupied: booking.status === 'checked_in' ? 1 : 0, reserved: 0, cleaning: room.condition === 'cleaning' ? 1 : 0, maintenance: 0 },
      floors: [{ floor: 1, total: 1, ready: room.display_status === 'ready' ? 1 : 0 }], attention_rooms: [], today_bookings: [], arrivals: 0, departures: 1, guests: 2 };
    else if (endpoint === 'rooms/' || endpoint === 'rooms/availability/') body = paged([room]);
    else if (endpoint === 'rooms/1/') body = room;
    else if (endpoint === 'room-types/') body = paged([type]);
    else if (endpoint === 'bookings/') body = paged([booking]);
    else if (endpoint === 'bookings/1/') body = booking;
    else if (endpoint === 'customers/1/') body = guest;
    else if (endpoint === 'bookings/1/services/') body = { ...paged([]), room_total: '1300000', service_total: '30000', estimated_total: '1330000', can_edit: !invoice };
    else if (endpoint === 'bookings/1/folio/') body = { state: invoice ? 'closed' : 'open', folio: invoice ? null : folio, invoice: invoice ?? null };
    else if (endpoint === 'bookings/1/check-out/') {
      keys.push(request.headers()['idempotency-key']); payloads.push(request.postDataJSON());
      assert.equal(payloads.at(-1).expected_total, '1330000');
      assert.equal(payloads.at(-1).method, 'bank_transfer');
      assert.equal(payloads.at(-1).payment_received, true);
      if (!invoice) {
        writes++;
        room.condition = room.display_status = 'cleaning'; room.updated_at = '2026-10-31T09:00:00Z';
        booking.status = 'checked_out'; booking.status_label = 'Đã trả'; booking.checked_out_at = '2026-10-31T09:00:00Z';
        invoice = { id: 1, code: 'HD-CHECKOUT', booking_id: 1, booking_code: booking.code,
          guest_name: guest.full_name, guest_phone: guest.phone, room_number: '101', room_type: type.name,
          start_date: booking.start_date, end_date: booking.end_date, room_total: '1300000', service_total: '30000', total: '1330000',
          issued_at: booking.checked_out_at, checked_out_at: booking.checked_out_at, issued_by: user.display_name,
          lines: lines.map((line, index) => ({ id: index + 1, position: index + 1, ...line })),
          payment: { id: 1, code: 'PT-CHECKOUT', amount: '1330000', method: 'bank_transfer', method_label: 'Chuyển khoản', reference: 'BANK-TEST',
            notes: '', received_at: booking.checked_out_at, received_by: user.display_name } };
        status = 503; body = { error: { message: 'Mất phản hồi, thử lại với cùng yêu cầu.', code: 'service_unavailable', fields: {} } };
      } else { assert.equal(keys[0], keys.at(-1)); assert.deepEqual(payloads[0], payloads.at(-1)); body = { invoice, booking }; }
      await new Promise(resolve => setTimeout(resolve, 300));
    } else if (endpoint === 'rooms/1/confirm-cleaned/') {
      assert.equal(new Date(request.postDataJSON().expected_updated_at).getTime(), new Date(room.updated_at).getTime());
      assert.equal(room.condition, 'cleaning'); cleanWrites++;
      room.condition = room.display_status = 'ready'; room.updated_at = '2026-10-31T09:05:00Z'; body = room;
    } else if (endpoint === 'rooms/timeline/') {
      timelineReads++;
      const start = url.searchParams.get('start_date') || '2026-10-31', days = Number(url.searchParams.get('days') || 7);
      const dates = Array.from({ length: days }, (_, index) => { const d = new Date(start + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + index); return d.toISOString().slice(0, 10); });
      body = { start_date: start, end_date: dates.at(-1), days, dates,
        rooms: [{ id: 1, number: '101', floor: 1, type_name: type.name, rate: 650000, condition: room.condition,
          schedule: dates.map(date => ({ date, status: date === '2026-10-31' && room.condition === 'cleaning' ? 'cleaning' : 'ready', booking: null })) }] };
    } else if (endpoint === 'invoices/') body = paged(invoice ? [invoice] : []);
    else throw new Error(`Unexpected fixture request ${request.method()} ${endpoint}`);
    await route.fulfill({ status, contentType: 'application/json', headers, body: JSON.stringify(body) });
  });
  try {
    await page.goto(base + '/#/bookings', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await typeInput(page.getByLabel('Tài khoản', { exact: true }), 'admin');
    await typeInput(page.getByLabel('Mật khẩu', { exact: true }), 'preview');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Khách kiểm tra checkout/ }).click();
    await page.getByRole('button', { name: 'Trả phòng', exact: true }).click();
    await page.getByText('Quyết toán lưu trú', { exact: true }).waitFor();
    const submit = page.getByRole('button', { name: 'Chốt hóa đơn & trả phòng', exact: true });
    assert(await submit.isDisabled()); await snap('folio');
    await scroll(700);
    await page.getByRole('combobox', { name: /Hình thức thanh toán/ }).or(page.getByRole('button', { name: /Hình thức thanh toán/ })).first().click();
    await page.getByRole('menuitem', { name: 'Chuyển khoản', exact: true }).click();
    await typeInput(page.getByRole('textbox', { name: /Mã giao dịch/ }), 'BANK-TEST');
    await scroll(420);
    await page.getByRole('checkbox', { name: /Đã nhận đủ/ }).click();
    await snap('payment');
    const before = await submit.boundingBox(); await scroll(150);
    assert.equal((await submit.boundingBox()).y, before.y);
    await submit.click();
    await page.getByText('Mất phản hồi, thử lại với cùng yêu cầu.', { exact: true }).last().waitFor();
    await submit.click();
    await page.getByText('Hóa đơn đã thanh toán', { exact: true }).waitFor();
    assert.equal(writes, 1); assert.equal(keys.length, 2);
    await snap('invoice');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Cần dọn/ }).waitFor(); await snap('room-cleaning');
    await page.getByRole('button', { name: 'Sơ đồ lịch', exact: true }).click();
    await page.getByRole('button', { name: /Phòng cần dọn vệ sinh/ }).click();
    await page.getByRole('button', { name: 'Xác nhận đã dọn', exact: true }).click();
    await page.getByRole('button', { name: 'Xác nhận đã dọn', exact: true }).last().click();
    await page.waitForTimeout(400); assert.equal(cleanWrites, 1); assert.equal(room.condition, 'ready');
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    assert(timelineReads >= 2); await snap('timeline-ready');
    await page.getByRole('button', { name: 'Thẻ phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Sẵn sàng/ }).waitFor(); await snap('room-ready');
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByText('Hóa đơn & phiếu thu', { exact: true }).click();
    await page.getByRole('button', { name: /HD-CHECKOUT.*Phòng 101/ }).click();
    await page.getByText('Hóa đơn đã thanh toán', { exact: true }).waitFor();
    await snap('invoice-history');
    assert.deepEqual(errors, []);
    console.log('PASS: folio, manual bank payment confirmation, lost-response retry with one invoice, check-out to cleaning, clean from timeline, ready card/timeline, frozen invoice history. Fixture only; no hotel records or receipts created.');
  } catch (error) {
    await snap('failed');
    console.error(JSON.stringify(await page.locator('[role]').evaluateAll(elements => elements.map(e => ({ role: e.getAttribute('role'), name: e.getAttribute('aria-label') || e.innerText })).slice(-22))));
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
