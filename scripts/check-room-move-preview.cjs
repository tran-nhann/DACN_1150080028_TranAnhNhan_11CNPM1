// End-to-end room move using isolated HTTP fixtures. No real hotel records change.
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const user = { id: 1, username: 'admin', display_name: 'Admin', role: 'admin', role_label: 'Quản trị viên' };
const type = { id: 1, name: 'Superior', description: '', capacity: 2, base_rate: '650000' };
const suite = { id: 2, name: 'Suite', description: '', capacity: 4, base_rate: '950000' };
const oldRoom = { id: 1, number: '101', floor: 1, room_type: type, condition: 'ready', display_status: 'occupied', notes: '', images: [], amenities: [] };
const target = { ...oldRoom, id: 2, number: '202', floor: 2, room_type: suite, display_status: 'ready' };
const guest = { id: 1, full_name: 'Khách chuyển phòng', phone: '0901234567', notes: '', email: '' };
const paged = results => ({ count: results.length, next: null, previous: null, results });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  let booking = { id: 1, code: 'BK-MOVE', customer: guest, room: oldRoom, status: 'checked_in', status_label: 'Đang ở',
    start_date: '2026-10-30', end_date: '2026-11-02', guests: 2, nightly_rate: '650000', room_total: '1950000', estimated_total: '1980000',
    checked_in_at: '2026-10-30T07:00:00Z', room_moves: [], room_segments: [] };
  let quoteReads = 0, transfers = 0, confirmed;
  const keys = [], errors = [];
  const quote = data => ({ quote_token: `${data.price_mode}-${quoteReads}`.padStart(64, 'a'), effective_date: '2026-10-31',
    from_number: '101', to_number: '202', old_rate: '650000', new_rate: data.price_mode === 'keep' ? '650000' : '950000', remaining_nights: 2,
    current_room_total: '1950000', new_room_total: data.price_mode === 'keep' ? '1950000' : '2550000',
    difference: data.price_mode === 'keep' ? '0' : '600000', service_total: '30000', total: data.price_mode === 'keep' ? '1980000' : '2580000',
    policy: 'Giá mới tính từ đêm của ngày chuyển; giữ giá các đêm trước.' });
  const snap = async name => { await page.waitForTimeout(250); await page.screenshot({ path: path.join(__dirname, `../.artifacts/room-move-${name}.png`) }); };
  const enter = async (field, value) => { await field.click(); await field.press('ControlOrMeta+A'); await field.pressSequentially(value, { delay: 12 }); await field.press('Tab'); };
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), method = request.method(), endpoint = new URL(request.url()).pathname.split('/api/v1/')[1];
    const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers });
    let data, status = 200;
    if (endpoint === 'auth/login/') data = { user, access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'auth/refresh/') data = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') data = user;
    else if (endpoint === 'bookings/') data = paged([booking]);
    else if (endpoint === 'bookings/1/') data = booking;
    else if (endpoint === 'rooms/' || endpoint === 'rooms/availability/') data = paged([oldRoom, target]);
    else if (endpoint === 'room-types/') data = paged([type, suite]);
    else if (endpoint === 'dashboard/') data = { date: '2026-10-31', rooms: { total: 2, occupied: 1, reserved: 0, ready: 1, cleaning: 0, maintenance: 0 }, floors: [], attention_rooms: [], today_bookings: [] };
    else if (endpoint === 'bookings/1/services/') data = { ...paged([]), booking_status: 'checked_in', room_total: booking.room_total, service_total: '30000', estimated_total: booking.estimated_total, can_edit: true };
    else if (endpoint === 'bookings/1/transfer-options/') data = { effective_date: '2026-10-31', policy: 'Giá mới tính từ đêm của ngày chuyển.', rooms: [target] };
    else if (endpoint === 'bookings/1/transfer-quote/') {
      const input = request.postDataJSON(); assert.equal(input.room_id, 2); assert(input.reason.trim());
      quoteReads++; data = confirmed = quote(input);
    } else if (endpoint === 'bookings/1/transfer/') {
      const input = request.postDataJSON(); keys.push(request.headers()['idempotency-key']);
      assert.equal(input.quote_token, confirmed.quote_token);
      assert.equal(input.price_mode, 'keep'); assert.equal(input.old_room_condition, 'maintenance');
      transfers++;
      if (transfers === 1) return route.abort('failed'); // Lost connection: preserve the key/quote for retry.
      assert.equal(keys[0], keys[1]);
      oldRoom.condition = oldRoom.display_status = 'maintenance'; target.display_status = 'occupied';
      booking = { ...booking, room: target, nightly_rate: '650000', room_total: '1950000', estimated_total: '1980000',
        room_segments: [
          { room_number: '101', room_type: 'Superior', start_date: '2026-10-30', end_date: '2026-10-31', nights: 1, nightly_rate: '650000', total: '650000' },
          { room_number: '202', room_type: 'Suite', start_date: '2026-10-31', end_date: '2026-11-02', nights: 2, nightly_rate: '650000', total: '1300000' }],
        room_moves: [{ from_number: '101', to_number: '202', old_rate: '650000', new_rate: '650000', reason: input.reason,
          old_room_condition: 'maintenance', price_mode: 'keep', effective_date: '2026-10-31', created_at: '2026-10-31T08:00:00Z', created_by: 'Admin' }] };
      status = 201; data = { move_id: 1, booking };
    } else if (endpoint === 'bookings/1/folio/') data = { state: 'open', invoice: null, folio: {
      booking_id: 1, booking_code: booking.code, guest_name: guest.full_name, room_number: '202', start_date: booking.start_date, end_date: booking.end_date,
      room_total: '1950000', service_total: '30000', total: '1980000', quote_token: 'f'.repeat(64), can_checkout: true, blocked_reason: '', billing_policy: 'Theo từng phòng đã ở.',
      lines: [{ kind: 'room', name: 'Phòng 101 · 30/10 → 31/10', unit: 'đêm', quantity: 1, unit_price: '650000', total: '650000' },
        { kind: 'room', name: 'Phòng 202 · 31/10 → 02/11', unit: 'đêm', quantity: 2, unit_price: '650000', total: '1300000' },
        { kind: 'service', name: 'Nước suối', unit: 'chai', quantity: 2, unit_price: '15000', total: '30000' }] } };
    else throw new Error(`Unexpected fixture ${method} ${endpoint}`);
    await route.fulfill({ status, headers, contentType: 'application/json', body: JSON.stringify(data) });
  });
  try {
    await page.goto('http://127.0.0.1:4173/#/bookings', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await enter(page.getByLabel('Tài khoản', { exact: true }), 'admin'); await enter(page.getByLabel('Mật khẩu', { exact: true }), 'fixture');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Khách chuyển phòng/ }).click();
    await page.getByRole('button', { name: 'Chuyển phòng', exact: true }).click();
    await page.getByRole('button', { name: /^202\s/ }).click();
    await enter(page.getByRole('textbox', { name: 'Lý do chuyển phòng', exact: true }), 'Máy lạnh hỏng, giữ giá đã thỏa thuận');
    await page.getByRole('button', { name: 'Xem chênh lệch', exact: true }).click();
    await page.getByText(/600.000/).waitFor(); await snap('upgrade-preview');
    assert.equal(transfers, 0);
    await page.getByRole('button', { name: 'Chọn lại / cập nhật chênh lệch', exact: true }).click();
    await page.getByRole('combobox', { name: /Cách tính giá/ }).or(page.getByRole('button', { name: /Cách tính giá/ })).first().click();
    await page.getByRole('menuitem', { name: 'Giữ giá hiện tại', exact: true }).click();
    await page.getByRole('combobox', { name: /Phòng cũ sau chuyển/ }).or(page.getByRole('button', { name: /Phòng cũ sau chuyển/ })).first().click();
    await page.getByRole('menuitem', { name: 'Bảo trì', exact: true }).click();
    await page.getByRole('button', { name: 'Xem chênh lệch', exact: true }).click();
    await page.getByRole('button', { name: 'Xác nhận chuyển phòng', exact: true }).waitFor(); await snap('keep-price-preview');
    await page.getByRole('button', { name: 'Xác nhận chuyển phòng', exact: true }).click();
    await page.getByLabel('Hộp thoại').getByText(/Không kết nối|kết nối|mạng/).waitFor(); await snap('retry');
    await page.getByRole('button', { name: 'Xác nhận chuyển phòng', exact: true }).click();
    await page.getByText('Phòng 202', { exact: true }).waitFor(); await snap('moved');
    assert.equal(transfers, 2); assert.equal(booking.room_moves.length, 1);
    await page.getByRole('button', { name: 'Trả phòng', exact: true }).click();
    await page.getByText('Phòng 101 · 30/10 → 31/10', { exact: true }).waitFor();
    await page.getByText('Phòng 202 · 31/10 → 02/11', { exact: true }).waitFor(); await snap('segmented-folio');
    assert.deepEqual(errors, []);
    console.log('PASS: upgrade preview, keep price/maintenance, lost-connection retry with same key, new room and segmented folio. Fixture only; no hotel records changed.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
