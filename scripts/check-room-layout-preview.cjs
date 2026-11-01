// Visual checks with isolated bookings; no hotel records are written.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const output = path.join(__dirname, '../.artifacts');
const paged = results => ({ count: results.length, next: null, previous: null, results });
const user = { id: 1, username: 'admin', display_name: 'Admin', role: 'admin', role_label: 'Quản trị viên' };
const type = { id: 1, name: 'Superior', description: 'Phòng sáng, có cửa sổ.', capacity: 2, base_rate: '650000' };
const rooms = Array.from({ length: 30 }, (_, i) => ({ id: i + 1, number: String(101 + i), floor: 1, room_type: type, condition: 'ready', display_status: 'reserved', notes: '', images: [], description: '', area: null, bed_type: '', bed_count: null, view: '', amenities: [] }));
const customer = { id: 1, full_name: 'Khách đến hôm nay', phone: '0901234567', email: '', notes: '' };
const booking = { id: 1, code: 'BK-TODAY', room: rooms[0], customer: { id: 1, full_name: customer.full_name }, start_date: '2026-10-31', end_date: '2026-11-01', guests: 2, nightly_rate: '650000', room_total: '650000', status: 'confirmed', status_label: 'Đã đặt', checked_in_at: null, created_at: '2026-10-30T08:00:00Z' };
const bookings = [booking,
  { ...booking, id: 2, code: 'BK-CANCELLED-1', status: 'cancelled', status_label: 'Đã hủy', start_date: '2026-10-14', end_date: '2026-10-15', customer: { id: 1, full_name: 'Khách đã hủy' } },
  { ...booking, id: 3, code: 'BK-CANCELLED-2', status: 'cancelled', status_label: 'Đã hủy', start_date: '2026-10-14', end_date: '2026-10-15', customer: { id: 1, full_name: 'Khách đã hủy' } },
  { ...booking, id: 4, code: 'BK-TOMORROW', start_date: '2026-11-01', end_date: '2026-11-02', customer: { id: 1, full_name: 'Khách ngày mai' } },
];

async function install(page) {
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), url = new URL(request.url()), endpoint = url.pathname.split('/api/v1/')[1];
    const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
    let body;
    if (endpoint === 'auth/login/') body = { access: 'fixture-access', refresh: 'fixture-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'dashboard/') body = { date: '2026-10-31', rooms: { total: 30, ready: 29, occupied: 0, reserved: 1, cleaning: 0, maintenance: 0 }, floors: [], attention_rooms: [], arrivals: 1, departures: 0, guests: 0, today_bookings: [] };
    else if (endpoint === 'rooms/' || endpoint === 'rooms/availability/') body = paged(rooms);
    else if (endpoint === 'room-types/') body = paged([type]);
    else if (endpoint === 'bookings/') body = paged(bookings);
    else if (endpoint === 'customers/') body = paged([customer]);
    else if (endpoint === 'customers/1/') body = customer;
    else throw new Error(`Unexpected fixture request ${request.method()} ${endpoint}`);
    await route.fulfill({ contentType: 'application/json', headers, body: JSON.stringify(body) });
  });
}

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [], fonts = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => { if (request.url().includes('MaterialIcons-Regular.otf')) fonts.push(request.url()); });
  const snap = async name => {
    await page.mouse.move(1, 1); await page.waitForTimeout(350);
    await page.screenshot({ path: path.join(output, `room-layout-${name}.png`) });
  };
  const scrollSheet = async amount => {
    await page.mouse.move(180, 600); await page.mouse.wheel(0, amount);
    await page.waitForTimeout(300);
  };
  try {
    await install(page);
    await page.goto('http://127.0.0.1:4173/#/rooms', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    for (const [label, value] of [['Tài khoản', 'admin'], ['Mật khẩu', 'preview']]) {
      const input = page.getByLabel(label, { exact: true });
      await input.click(); await input.press('ControlOrMeta+A'); await input.pressSequentially(value, { delay: 12 }); await input.press('Tab');
    }
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101\b/ }).click();
    for (const text of ['Loại phòng: Superior', 'Sức chứa: 2 khách', 'Diện tích: Chưa cập nhật', 'Loại giường: Chưa cập nhật', 'Số giường: Chưa cập nhật', 'Hướng nhìn: Chưa cập nhật']) {
      await page.getByText(text, { exact: true }).waitFor();
    }
    await scrollSheet(350);
    await snap('information');
    await scrollSheet(200); await snap('description');
    await scrollSheet(470);
    await page.getByRole('button', { name: /Đến hôm nay/ }).waitFor(); await snap('history');
    await scrollSheet(-3000);
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('tab', { name: 'Đặt phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101.*Khách đến hôm nay/ }).click();
    await page.getByRole('button', { name: 'Thao tác khác', exact: true }).click();
    await page.getByRole('menuitem', { name: /Đổi lịch/ }).click();
    await page.getByRole('button', { name: /^101/ }).last().click();
    const save = page.getByRole('button', { name: 'Lưu', exact: true });
    const before = await save.boundingBox();
    assert(before && before.y + before.height < 844);
    await snap('reschedule');
    await page.mouse.move(185, 430); await page.mouse.wheel(0, 1300); await page.waitForTimeout(300);
    assert.equal((await save.boundingBox()).y, before.y);
    await snap('reschedule-scrolled');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Thao tác khác', exact: true }).click();
    await page.getByRole('menuitem', { name: 'Gia hạn', exact: true }).click();
    await page.getByRole('button', { name: /^(OK|Chọn|Lưu)$/ }).last().click();
    const extend = page.getByRole('button', { name: 'Gia hạn', exact: true });
    const extended = await extend.boundingBox();
    assert(extended && extended.y + extended.height < 844); await snap('extension');
    await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
    await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    await page.getByRole('button', { name: 'Đặt phòng mới', exact: true }).click();
    await page.getByRole('button', { name: /Chọn khách hàng/ }).click();
    await page.getByRole('button', { name: /Khách đến hôm nay/ }).click();
    await page.getByRole('button', { name: 'Tiếp tục', exact: true }).click();
    const next = page.getByRole('button', { name: 'Tiếp tục', exact: true });
    const nextBox = await next.boundingBox();
    assert(nextBox && nextBox.y + nextBox.height < 844); await snap('new-booking');
    assert(fonts.length > 0 && fonts.every(url => url.includes('/__build/')), 'Icon fonts must use the current build URL.');
    assert.deepEqual(errors, []);
    console.log('PASS: six inline room fields, description icon font, colored arrival/history cards, pinned reschedule, extension and new booking actions. No hotel records changed.');
  } catch (error) {
    await page.screenshot({ path: path.join(output, 'room-layout-failed.png') });
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
