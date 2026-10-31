// Deterministic UI check. All API calls are fulfilled locally by Playwright.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');

const output = path.join(__dirname, '../docs/screenshots');
const type = { id: 1, name: 'Deluxe', description: 'Hướng thành phố · Giường đôi', capacity: 2, base_rate: '950000' };
const guest = { id: 1, full_name: 'Nguyễn Minh An', phone: '0901234567', email: 'an@example.test', notes: 'Ưu tiên phòng yên tĩnh', created_at: '2026-10-01T08:00:00Z' };
const staff = { id: 1, username: 'admin', display_name: 'Anh Nhân', role: 'admin', role_label: 'Quản trị viên' };
const room = (id, number, condition = 'ready') => ({ id, number, floor: 1, room_type: type, condition, display_status: condition, notes: '', is_active: true, updated_at: '2026-10-14T08:00:00Z' });
const rooms = [room(1, '101'), room(2, '102', 'reserved'), room(3, '103', 'cleaning'), room(4, '104'), room(5, '105', 'occupied'), room(6, '106', 'maintenance')];
const paged = results => ({ count: results.length, next: null, previous: null, results });
const booking = (id, hotelRoom, customer = guest) => ({
  id, code: `BK-${id}`, room: hotelRoom, customer,
  start_date: '2026-10-14', end_date: '2026-10-15', guests: 1,
  nightly_rate: '950000', room_total: '950000', status: 'confirmed', status_label: 'Đã đặt', checked_in_at: null, created_at: '2026-10-01T08:00:00Z',
});

async function installApi(page, user = staff) {
  const state = { guests: [guest], bookings: [booking(11, rooms[1])], guestAttempts: 0, bookingPosts: 0, reschedules: [], cancels: 0 };
  await page.route('**/api/v1/**', async route => {
    const request = route.request();
    const url = new URL(request.url());
    const endpoint = url.pathname.split('/api/v1/')[1];
    const method = request.method();
    let body = {}, status = 200;
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });
    if (endpoint === 'auth/login/') body = { access: 'ui-access', refresh: 'ui-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'ui-access', refresh: 'ui-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'auth/logout/') body = {};
    else if (endpoint === 'dashboard/') body = {
      date: '2026-10-14', rooms: { total: 30, ready: 21, occupied: 3, reserved: 2, cleaning: 3, maintenance: 1 },
      arrivals: 2, departures: 1, guests: 6, floors: [{ floor: 1, total: 10, ready: 7 }], attention_rooms: [rooms[2], rooms[5]], today_bookings: [state.bookings[0]],
    };
    else if (endpoint === 'room-types/') body = paged([type]);
    else if (endpoint === 'rooms/availability/') body = paged([rooms[0], rooms[3]]);
    else if (endpoint === 'rooms/') body = paged(rooms.filter(item => (!url.searchParams.get('status') || item.display_status === url.searchParams.get('status')) && item.number.includes(url.searchParams.get('search') || '')));
    else if (endpoint === 'customers/' && method === 'POST') {
      const data = request.postDataJSON();
      state.guestAttempts++;
      if (state.guestAttempts === 1) { status = 400; body = { error: { message: 'Điện thoại đã tồn tại.', fields: { phone: ['Điện thoại đã tồn tại.'] } } }; }
      else { body = { id: 100, ...data }; status = 201; state.guests.unshift(body); }
    }
    else if (endpoint === 'customers/') body = paged(state.guests.filter(item => (item.full_name + item.phone).toLowerCase().includes((url.searchParams.get('search') || '').toLowerCase())));
    else if (/^customers\/\d+\/$/.test(endpoint)) {
      const item = state.guests.find(item => item.id === Number(endpoint.split('/')[1]));
      if (method === 'PATCH') Object.assign(item, request.postDataJSON());
      body = item;
    }
    else if (endpoint === 'bookings/' && method === 'POST') {
      const data = request.postDataJSON();
      assert.equal(data.expected_nightly_rate, 950000);
      assert(request.headers()['idempotency-key']);
      state.bookingPosts++;
      body = { ...booking(99, rooms.find(item => item.id === data.room_id), state.guests.find(item => item.id === data.customer_id)), start_date: data.start_date, end_date: data.end_date, guests: data.guests };
      state.bookings.unshift(body); status = 201;
    }
    else if (endpoint === 'bookings/') body = paged(state.bookings.filter(item =>
      (!url.searchParams.get('status') || item.status === url.searchParams.get('status')) &&
      (!url.searchParams.get('room') || item.room.id === Number(url.searchParams.get('room'))) &&
      (!url.searchParams.get('customer') || item.customer.id === Number(url.searchParams.get('customer'))) &&
      (!url.searchParams.get('arrival_on') || item.start_date === url.searchParams.get('arrival_on')) &&
      (!url.searchParams.get('departure_on') || item.end_date === url.searchParams.get('departure_on'))));
    else if (/bookings\/\d+\/reschedule\/$/.test(endpoint)) {
      const data = request.postDataJSON(); state.reschedules.push(data);
      const id = Number(endpoint.split('/')[1]);
      body = state.bookings.find(item => item.id === id);
      Object.assign(body, { room: rooms.find(item => item.id === data.room_id), start_date: data.start_date, end_date: data.end_date });
    }
    else if (/bookings\/\d+\/cancel\/$/.test(endpoint)) {
      const id = Number(endpoint.split('/')[1]); state.cancels++;
      body = state.bookings.find(item => item.id === id); Object.assign(body, { status: 'cancelled', status_label: 'Đã hủy' });
    }
    else throw new Error(`Unmocked API ${method} ${endpoint}`);
    await route.fulfill({ status, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' }, body: JSON.stringify(body) });
  });
  return state;
}

async function launchApp(page) {
  await page.goto('http://127.0.0.1:4173', { waitUntil: 'networkidle' });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor(); await placeholder.evaluate(element => element.click());
  await typeInto(page.getByLabel('Tài khoản', { exact: true }), 'admin');
  await typeInto(page.getByLabel('Mật khẩu', { exact: true }), 'ui-preview');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.getByRole('button', { name: /Phòng sẵn sàng/ }).waitFor();
}

async function typeInto(locator, value) {
  await locator.click(); await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value, { delay: 5 }); await locator.press('Tab');
}

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const errors = [];
  let page;
  try {
    page = await browser.newPage({ viewport: { width: 390, height: 844 } });
    page.on('pageerror', error => errors.push(error.message));
    const state = await installApi(page);
    await launchApp(page);
    const snap = async name => {
      await page.mouse.move(1, 1); await page.waitForTimeout(400);
      await page.screenshot({ path: path.join(output, `ui-${name}.png`) });
    };
    await snap('dashboard-mobile');
    await page.getByRole('button', { name: /Đến$/ }).click();
    await page.getByText('Khách đến', { exact: true }).waitFor();
    await page.getByRole('button', { name: /^102.*Nguyễn Minh An/ }).click();
    await page.getByText('BK-11', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101/ }).waitFor(); await snap('rooms-mobile');
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: 'Đặt phòng mới', exact: true }).click();
    await page.getByRole('button', { name: /Chọn khách hàng/ }).click();
    await page.getByRole('button', { name: 'Thêm khách hàng', exact: true }).click();
    await typeInto(page.getByLabel('Họ và tên', { exact: true }), 'Trần Minh Ngọc');
    await typeInto(page.getByLabel('Số điện thoại', { exact: true }), '0901234999');
    await snap('guest-form');
    await page.getByRole('button', { name: 'Lưu', exact: true }).click();
    await page.getByText('Điện thoại đã tồn tại.', { exact: true }).waitFor(); await snap('guest-inline-error');
    await typeInto(page.getByRole('textbox', { name: /Số điện thoại/ }), '0901234888');
    await page.getByRole('button', { name: 'Lưu', exact: true }).click();
    await page.getByRole('button', { name: /Trần Minh Ngọc/ }).click();
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click();
    await page.getByRole('button', { name: /^101/ }).click();
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click(); await snap('booking-review');
    await page.getByRole('button', { name: 'Sửa lịch và khách', exact: true }).click();
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click();
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click();
    await page.getByRole('button', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Trần Minh Ngọc/ }).click(); await snap('booking-detail');
    await page.getByRole('button', { name: 'Thao tác khác', exact: true }).click();
    await page.getByRole('menuitem', { name: 'Đổi lịch / phòng', exact: true }).or(page.getByRole('button', { name: 'Đổi lịch / phòng', exact: true })).first().click();
    await page.getByRole('button', { name: /^101/ }).click(); await snap('reschedule');
    await page.getByRole('button', { name: 'Lưu', exact: true }).click();
    await page.getByRole('button', { name: 'Thao tác khác', exact: true }).click();
    await page.getByRole('menuitem', { name: 'Hủy đặt phòng', exact: true }).or(page.getByRole('button', { name: 'Hủy đặt phòng', exact: true })).first().click(); await snap('cancel-confirm');
    await page.getByRole('button', { name: 'Hủy đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    assert.equal(state.bookingPosts, 1); assert.equal(state.guestAttempts, 2); assert.equal(state.cancels, 1);
    assert.equal(state.reschedules.length, 1); assert.equal(state.reschedules[0].expected_nightly_rate, undefined);
    await page.getByRole('tab', { name: 'Thêm', exact: true }).click();
    await page.getByRole('button', { name: /Khách hàng/ }).click(); await snap('customers');
    await page.getByRole('button', { name: /Nguyễn Minh An/ }).click();
    await page.getByText('Hồ sơ khách', { exact: true }).waitFor(); await snap('guest-profile');
    await page.getByText('an@example.test', { exact: true }).waitFor();
    await page.getByRole('button', { name: /^102.*Nguyễn Minh An/ }).click();
    await page.getByText('BK-11', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Sửa khách hàng', exact: true }).click();
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('tab', { name: 'Hôm nay', exact: true }).click();
    for (const width of [320, 360, 430, 480]) {
      await page.setViewportSize({ width, height: 844 });
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    }
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101/ }).click(); await snap('room-detail');
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    assert.deepEqual(errors, []);
    console.log('PASS: rendered Flutter UI; guest field error/retry, same-sheet guest creation, review edit, booking create, same-rate reschedule, cancel confirmation, all tabs and reduced motion. API calls stayed inside Playwright.');
  } catch (error) {
    if (page) console.error(JSON.stringify(await page.locator('[role]').evaluateAll(elements => elements.map(element => ({role: element.getAttribute('role'), label: element.getAttribute('aria-label')})).slice(-20))));
    if (page) await page.screenshot({ path: path.join(__dirname, '../.artifacts/workflow-preview-failed.png') });
    throw error;
  } finally {
    if (errors.length) console.error(errors.join('\n'));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
