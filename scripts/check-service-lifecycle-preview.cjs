// Four service touchpoints with an isolated API; SQL behavior is tested separately.
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const paged = results => ({ count: results.length, next: null, previous: null, results });
const user = { id: 1, username: 'admin', display_name: 'Admin', role: 'admin', role_label: 'Quản trị viên' };
const type = { id: 1, name: 'Superior', capacity: 2, description: '', base_rate: '650000' };
const room = { id: 1, number: '101', floor: 1, room_type: type, condition: 'ready', display_status: 'ready', notes: '', images: [], amenities: [] };
const guest = { id: 1, full_name: 'Nguyễn Minh An', phone: '0901234567', email: '', notes: '' };
const catalog = [
  { id: 1, name: 'Nước suối', unit: 'chai', unit_price: '15000' },
  { id: 2, name: 'Ăn sáng', unit: 'suất', unit_price: '60000' },
  { id: 3, name: 'Giặt ủi', unit: 'kg', unit_price: '30000' },
].map(row => ({ ...row, is_active: true, unit_valid: true }));

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  let booking, plans = [], usages = [], invoice, cart;
  const amount = rows => rows.filter(row => row.status !== 'cancelled').reduce((sum, row) => sum + Number(row.total), 0);
  const line = (data, planned) => {
    const service = catalog.find(row => row.id === data.service_id);
    return { ...service, id: (planned ? plans.length + 1 : usages.length + 11), service_id: service.id,
      quantity: data.quantity, total: String(data.quantity * Number(service.unit_price)), status: planned ? 'reserved' : 'active', planned,
      created_at: '2026-10-31T08:00:00Z', created_by: 'Admin', cancelled_at: null, cancelled_by: null, cancel_reason: '' };
  };
  const rows = () => booking.status === 'confirmed' ? plans : usages;
  const quote = () => ({ booking_id: 1, booking_code: booking.code, guest_name: guest.full_name, room_number: '101',
    start_date: booking.start_date, end_date: booking.end_date, room_total: '650000', service_total: String(amount(usages)), total: String(650000 + amount(usages)),
    quote_token: `${usages.length}-${amount(usages)}`.padStart(64, 'a'), can_checkout: true, blocked_reason: '', billing_policy: 'Tính đủ số đêm đã đặt/gia hạn.',
    lines: [{ kind: 'room', name: 'Phòng 101', unit: 'đêm', quantity: 1, unit_price: '650000', total: '650000' },
      ...usages.filter(row => row.status !== 'cancelled').map(row => ({ ...row, kind: 'service' }))] });
  const snap = async name => { await page.mouse.move(1, 1); await page.waitForTimeout(300); await page.screenshot({ path: path.join(__dirname, `../.artifacts/service-lifecycle-${name}.png`) }); };
  const scroll = async n => { await page.mouse.move(190, 520); await page.mouse.wheel(0, n); await page.waitForTimeout(300); };
  const enter = async (field, text) => { await field.click(); await field.press('ControlOrMeta+A'); await field.pressSequentially(text, { delay: 12 }); await field.press('Tab'); };
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), url = new URL(request.url()), endpoint = url.pathname.split('/api/v1/')[1], method = request.method();
    const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers });
    let body, status = 200;
    if (endpoint === 'auth/login/') body = { access: 'fixture-access', refresh: 'fixture-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'dashboard/') body = { date: '2026-10-31', rooms: { total: 1, ready: 1, occupied: 0, reserved: 0, cleaning: 0, maintenance: 0 }, floors: [], attention_rooms: [], today_bookings: [], arrivals: 0, departures: 0, guests: 0 };
    else if (endpoint === 'customers/') body = paged([guest]);
    else if (endpoint === 'customers/1/') body = guest;
    else if (endpoint === 'rooms/availability/' || endpoint === 'rooms/') body = paged([room]);
    else if (endpoint === 'room-types/') body = paged([type]);
    else if (endpoint === 'services/') body = paged(catalog);
    else if (endpoint === 'bookings/' && method === 'POST') {
      cart = request.postDataJSON(); assert.deepEqual(cart.services, [{ service_id: 1, quantity: 2, expected_unit_price: 15000 }]);
      plans = cart.services.map(data => line(data, true));
      booking = { id: 1, code: 'BK-LIFECYCLE', room, customer: guest, start_date: cart.start_date, end_date: cart.end_date,
        guests: cart.guests, nightly_rate: '650000', room_total: '650000', estimated_total: '680000', status: 'confirmed', status_label: 'Đã đặt', checked_in_at: null };
      body = booking; status = 201;
    } else if (endpoint === 'bookings/') body = paged(booking ? [booking] : []);
    else if (endpoint === 'bookings/1/') body = booking;
    else if (endpoint === 'bookings/1/planned-services/') { const row = line(request.postDataJSON(), true); plans.push(row); body = row; status = 201; }
    else if (endpoint === 'bookings/1/check-in/') {
      if (booking.status === 'confirmed') usages = plans.filter(row => row.status !== 'cancelled').map((row, i) => ({ ...row, id: i + 11, planned: false, status: 'active' }));
      booking.status = 'checked_in'; booking.status_label = 'Đang ở'; booking.checked_in_at = '2026-10-31T08:00:00Z';
      body = booking;
    } else if (endpoint === 'bookings/1/services/' && method === 'POST') { const row = line(request.postDataJSON(), false); usages.push(row); body = row; status = 201; }
    else if (endpoint === 'bookings/1/services/') body = { ...paged(rows()), booking_status: booking.status,
      room_total: '650000', service_total: String(amount(rows())), estimated_total: String(650000 + amount(rows())), can_edit: !invoice };
    else if (/^bookings\/1\/services\/\d+\/cancel\/$/.test(endpoint)) {
      body = usages.find(row => row.id === Number(endpoint.split('/')[3])); body.status = 'cancelled';
      body.cancel_reason = request.postDataJSON().reason; body.cancelled_at = '2026-10-31T09:00:00Z'; body.cancelled_by = 'Admin';
    } else if (endpoint === 'bookings/1/folio/') body = { state: invoice ? 'closed' : 'open', folio: invoice ? null : quote(), invoice: invoice ?? null };
    else if (endpoint === 'bookings/1/check-out/') {
      const data = request.postDataJSON(); assert.equal(data.expected_total, '755000'); assert.equal(data.quote_token, quote().quote_token); assert(data.payment_received);
      const q = quote(); booking.status = 'checked_out'; booking.status_label = 'Đã trả'; room.condition = room.display_status = 'cleaning';
      invoice = { id: 1, code: 'HD-LIFECYCLE', booking_id: 1, booking_code: booking.code, guest_name: guest.full_name, guest_phone: guest.phone,
        room_number: '101', room_type: type.name, start_date: booking.start_date, end_date: booking.end_date, room_total: q.room_total,
        service_total: q.service_total, total: q.total, lines: q.lines, issued_at: '2026-10-31T09:00:00Z', issued_by: 'Admin',
        payment: { id: 1, code: 'PT-LIFECYCLE', amount: q.total, method: 'cash', method_label: 'Tiền mặt', reference: '', notes: '', received_at: '2026-10-31T09:00:00Z', received_by: 'Admin' } };
      body = { invoice, booking }; status = 201;
    } else throw new Error(`Unexpected fixture ${method} ${endpoint}`);
    await route.fulfill({ status, contentType: 'application/json', headers, body: JSON.stringify(body) });
  });
  const add = async name => {
    await page.getByRole('button', { name: /^(Ghi dịch vụ|Thêm dịch vụ đặt kèm)$/ }).click();
    await page.getByRole('button', { name: new RegExp('^' + name) }).click();
    const saved = page.waitForResponse(response => /bookings\/1\/(planned-services|services)\/$/.test(response.url()) && response.request().method() === 'POST');
    await page.getByRole('button', { name: 'Ghi nhận', exact: true }).click();
    assert.equal((await saved).status(), 201);
    await page.getByRole('button', { name: /^(Ghi dịch vụ|Thêm dịch vụ đặt kèm)$/ }).waitFor();
  };
  try {
    await page.goto('http://127.0.0.1:4173/#/bookings', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
    await enter(page.getByLabel('Tài khoản', { exact: true }), 'admin'); await enter(page.getByLabel('Mật khẩu', { exact: true }), 'preview');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: 'Đặt phòng mới', exact: true }).click();
    await page.getByRole('button', { name: /Chọn khách hàng/ }).click(); await page.getByRole('button', { name: /Nguyễn Minh An/ }).click();
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click(); await page.getByRole('button', { name: /^101/ }).click();
    await scroll(350); await page.getByRole('button', { name: 'Thêm dịch vụ đặt kèm', exact: true }).click();
    await page.getByRole('button', { name: /^Nước suối/ }).click();
    await enter(page.getByRole('textbox', { name: /Số lượng Nước suối/ }), '2'); await snap('booking-cart');
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click(); await snap('booking-review');
    await page.getByRole('button', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Nguyễn Minh An/ }).click(); await page.getByRole('button', { name: 'Nhận phòng', exact: true }).click();
    await page.getByText('Nhận phòng & dịch vụ', { exact: true }).waitFor();
    await add('Ăn sáng'); assert.equal(plans.length, 2); assert.equal(usages.length, 0); await snap('checkin-review');
    await page.getByRole('button', { name: 'Nhận phòng', exact: true }).click();
    await page.getByRole('button', { name: 'Trả phòng', exact: true }).waitFor(); assert.equal(usages.length, 2);
    await page.getByRole('button', { name: /^Dịch vụ(?:\s|$)/ }).first().click(); await add('Giặt ủi'); assert.equal(amount(usages), 120000); await snap('during-stay');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click(); await page.getByRole('button', { name: 'Trả phòng', exact: true }).click();
    await page.getByRole('button', { name: 'Bổ sung / hủy dịch vụ', exact: true }).click();
    await page.getByRole('button', { name: 'Hủy khoản', exact: true }).first().click();
    await enter(page.getByRole('textbox', { name: /Lý do/ }), 'Không dùng nước đặt trước');
    await page.getByRole('button', { name: 'Hủy khoản', exact: true }).click();
    await add('Nước suối'); assert.equal(amount(usages), 105000);
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click(); await snap('checkout-review');
    await scroll(1000);
    await page.getByRole('combobox', { name: /Hình thức thanh toán/ }).or(page.getByRole('button', { name: /Hình thức thanh toán/ })).first().click();
    await page.getByRole('menuitem', { name: 'Tiền mặt', exact: true }).click(); await scroll(600);
    await page.getByRole('checkbox', { name: /Đã nhận đủ/ }).click();
    await page.getByRole('button', { name: 'Chốt hóa đơn & trả phòng', exact: true }).click();
    await page.getByText('Hóa đơn đã thanh toán', { exact: true }).waitFor(); await snap('invoice');
    assert.equal(invoice.total, '755000'); assert.equal(invoice.service_total, '105000'); assert.deepEqual(errors, []);
    console.log('PASS: cart at room selection, review before check-in and one conversion, during-stay usage, checkout cancellation/addition, exact final receipt without duplicate preorders. Fixture only; no hotel records changed.');
  } catch (error) {
    await snap('failed'); console.error(JSON.stringify(await page.locator('[role]').evaluateAll(elements => elements.map(e => ({ role: e.getAttribute('role'), text: e.getAttribute('aria-label') || e.innerText })).slice(-25)))); throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
