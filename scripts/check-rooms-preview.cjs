// Room editor and native browser file chooser, using an isolated API fixture.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const output = path.join(__dirname, '../.artifacts');
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'room-upload-fixture.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACgAAAAeCAIAAADRv8uKAAAAR0lEQVR4nO3QMREAIBTD0E/9D0hAARpZqYF0aQy8u6x9zyRSRJ3CYCKxv8JY4iivMJY4yiuMJY7yCmOJo7zCWOIorzBWbPUDL04CGnAEE84AAAAASUVORK5CYII=', 'base64'));
const paged = results => ({ count: results.length, next: null, previous: null, results });
const staff = { id: 1, username: 'admin', display_name: 'Admin', role: 'admin', role_label: 'Quản trị viên' };
const type = { id: 1, name: 'Deluxe', description: 'Phòng rộng thoáng', capacity: 2, base_rate: '950000' };

async function install(page, role = 'admin') {
  const state = { saves: 0, room: { id: 1, number: '101', floor: 1, room_type: type, condition: 'ready', display_status: 'ready', notes: '', description: 'Phòng có ban công', area: '32.50', bed_type: 'queen', bed_count: 1, view: 'Vườn', amenities: ['Wi-Fi', 'Điều hòa'], images: [] } };
  await page.route('**/media/rooms/**', route => route.fulfill({ path: path.join(output, 'room-upload-fixture.png'), contentType: 'image/png', headers: { 'access-control-allow-origin': '*' } }));
  await page.route('**/api/v1/**', async route => {
    const request = route.request();
    const endpoint = new URL(request.url()).pathname.split('/api/v1/')[1];
    const user = { ...staff, role };
    const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
    let body;
    if (endpoint === 'auth/login/') body = { access: 'fixture-access', refresh: 'fixture-refresh', user };
    else if (endpoint === 'auth/refresh/') body = { access: 'fixture-access', refresh: 'fixture-refresh' };
    else if (endpoint === 'me/') body = user;
    else if (endpoint === 'dashboard/') body = { date: '2026-10-31', rooms: { total: 1, ready: 1, occupied: 0, reserved: 0, cleaning: 0, maintenance: 0 }, floors: [], attention_rooms: [], arrivals: 0, departures: 0, guests: 0, today_bookings: [] };
    else if (endpoint === 'rooms/') body = paged([state.room]);
    else if (endpoint === 'room-types/') body = paged([type]);
    else if (endpoint === 'bookings/') body = paged([]);
    else if (endpoint === 'rooms/1/' && request.method() === 'PATCH') {
      assert.equal(role, 'admin');
      state.saves++;
      const multipart = request.headers()['content-type'].startsWith('multipart/');
      let data;
      if (multipart) {
        const raw = request.postDataBuffer().toString('latin1');
        const json = raw.match(/name="data"\r\n\r\n([^\r]*)/)[1];
        data = JSON.parse(Buffer.from(json, 'latin1').toString('utf8'));
        assert(raw.includes('name="upload_images"; filename='));
        assert.equal(data.description, 'Mô tả cập nhật từ admin');
        state.room.images = [{ id: 9, url: '/media/rooms/1/photo.png', position: 0 }];
      } else {
        data = request.postDataJSON();
        if (data.image_ids.length === 0) state.room.images = [];
      }
      Object.assign(state.room, data);
      body = state.room;
    } else throw new Error(`Unmocked API: ${request.method()} ${endpoint}`);
    await route.fulfill({ contentType: 'application/json', headers, body: JSON.stringify(body) });
  });
  return state;
}

async function login(page) {
  await page.goto('http://127.0.0.1:4173', { waitUntil: 'networkidle' });
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  for (const [label, value] of [['Tài khoản', 'admin'], ['Mật khẩu', 'preview']]) {
    const input = page.getByLabel(label, { exact: true });
    await input.click(); await input.press('ControlOrMeta+A'); await input.pressSequentially(value, { delay: 12 }); await input.press('Tab');
  }
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
  await page.getByRole('button', { name: /^101/ }).click();
}

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  let page;
  const errors = [];
  try {
    page = await browser.newPage({ viewport: { width: 390, height: 844 } });
    page.on('pageerror', error => errors.push(error.message));
    const state = await install(page);
    await login(page);
    await page.getByRole('button', { name: 'Sửa phòng', exact: true }).click();
    const chooser = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: 'Chọn ảnh phòng', exact: true }).click();
    await (await chooser).setFiles(path.join(output, 'room-upload-fixture.png'));
    await page.getByText('Ảnh bìa', { exact: true }).waitFor();
    const description = page.getByRole('textbox', { name: /Mô tả phòng/ });
    await description.click(); await description.press('ControlOrMeta+A');
    await description.pressSequentially('Mô tả cập nhật từ admin', { delay: 12 }); await description.press('Tab');
    await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click();
    await page.getByRole('button', { name: 'Sửa phòng', exact: true }).waitFor();
    assert.equal(state.saves, 1);
    assert.equal(state.room.images.length, 1);
    await page.screenshot({ path: path.join(output, 'rooms-detail-preview.png') });
    await page.getByRole('img', { name: 'Ảnh phòng', exact: true }).first().click();
    await page.getByRole('button', { name: 'Đóng ảnh', exact: true }).click();
    await page.getByRole('button', { name: 'Sửa phòng', exact: true }).click();
    await page.getByRole('button', { name: 'Xóa ảnh 1', exact: true }).click();
    await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click();
    await page.getByRole('button', { name: 'Sửa phòng', exact: true }).waitFor();
    assert.equal(state.saves, 2);
    assert.equal(state.room.images.length, 0);
    await page.close();
    page = await browser.newPage({ viewport: { width: 320, height: 700 } });
    await install(page, 'manager'); await login(page);
    assert.equal(await page.getByRole('button', { name: 'Sửa phòng', exact: true }).count(), 0);
    assert.deepEqual(errors, []);
    console.log('PASS: room edit, browser photo selection, multipart upload, updated detail, enlarged photo, removal, manager read-only. No business DB writes.');
  } catch (error) {
    if (page && !page.isClosed()) await page.screenshot({ path: path.join(output, 'rooms-preview-failed.png') });
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
