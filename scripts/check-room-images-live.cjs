// Inspect every real room image, exercise a reversible upload, then use the admin UI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../.tools/ui-check/node_modules/playwright');
const root = path.join(__dirname, '..');
const api = 'http://127.0.0.1:8000/api/v1/';
const preview = 'http://127.0.0.1:4173';
const screenshot = name => path.join(root, `.artifacts/${name}.png`);

(async () => {
  const password = fs.readFileSync(path.join(root, 'backend/.env'), 'utf8').match(/^DEMO_PASSWORD=(.+)$/m)?.[1].trim();
  assert(password, 'Missing local demo credentials.');
  const login = await fetch(api + 'auth/login/', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password }),
  });
  assert.equal(login.status, 200);
  const session = await login.json();
  assert.equal(session.user.role, 'admin');
  const headers = { Authorization: `Bearer ${session.access}` };
  const jsonHeaders = { ...headers, 'Content-Type': 'application/json' };
  const get = async url => {
    const response = await fetch(url, { headers });
    assert.equal(response.status, 200, url);
    return response.json();
  };
  const rooms = [];
  for (let next = api + 'rooms/'; next;) {
    const data = await get(next);
    rooms.push(...data.results); next = data.next;
  }
  assert(rooms.length > 0);
  assert(rooms.every(room => room.images.length >= 3), 'Every room should have a complete gallery.');
  const photos = rooms.flatMap(room => room.images);
  for (let start = 0; start < photos.length; start += 10) {
    await Promise.all(photos.slice(start, start + 10).map(async photo => {
      const response = await fetch(new URL(photo.url, api));
      assert.equal(response.status, 200, photo.url);
      assert(response.headers.get('content-type').startsWith('image/'));
      assert((await response.arrayBuffer()).byteLength > 10000, 'Photo must contain an actual interior image.');
    }));
  }

  const target = rooms.find(room => room.number === '101') ?? rooms[0];
  const originalIds = target.images.map(photo => photo.id);
  let uploadedId;
  try {
    const form = new FormData();
    form.append('data', JSON.stringify({ image_ids: originalIds, cover_upload_index: 0 }));
    const file = fs.readFileSync(path.join(root, 'backend/hotel/demo_assets/rooms/superior-bedroom.jpg'));
    form.append('upload_images', new Blob([file], { type: 'image/jpeg' }), 'test-room.jpg');
    const response = await fetch(api + `rooms/${target.id}/`, { method: 'PATCH', headers, body: form });
    assert.equal(response.status, 200, await response.clone().text());
    const saved = await response.json();
    uploadedId = saved.images.find(photo => !originalIds.includes(photo.id))?.id;
    assert(uploadedId);
    assert.equal(saved.images[0].id, uploadedId, 'New upload can be the cover.');
    assert.equal(saved.images.length, originalIds.length + 1);
    for (const field of ['number', 'floor', 'description', 'area', 'bed_type', 'bed_count', 'view', 'amenities', 'notes', 'room_type']) {
      assert.deepEqual(saved[field], target[field], `Upload must preserve ${field}.`);
    }
  } finally {
    if (uploadedId) {
      const restored = await fetch(api + `rooms/${target.id}/`, {
        method: 'PATCH', headers: jsonHeaders, body: JSON.stringify({ image_ids: originalIds }),
      });
      assert.equal(restored.status, 200);
      assert.deepEqual((await restored.json()).images.map(photo => photo.id), originalIds);
    }
  }

  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 480, height: 940 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (response.url().includes('/media/') && response.status() !== 200) errors.push(`Image HTTP ${response.status()}`);
  });
  try {
    await page.goto(preview + '/#/rooms', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    for (const [label, value] of [['Tài khoản', 'admin'], ['Mật khẩu', password]]) {
      const input = page.getByLabel(label, { exact: true });
      await input.click(); await input.press('ControlOrMeta+A');
      await input.pressSequentially(value, { delay: 12 }); await input.press('Tab');
    }
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await page.getByRole('tab', { name: 'Phòng', exact: true }).click();
    await page.getByRole('button', { name: /^101\b/ }).waitFor();
    await page.waitForLoadState('networkidle');
    await page.mouse.move(1, 1);
    await page.waitForTimeout(400);
    await page.screenshot({ path: screenshot('rooms-with-photos') });
    for (const number of ['101', '102', '103', '104']) {
      await page.getByRole('button', { name: new RegExp('^' + number + '(?:[^0-9]|$)') }).click();
      await page.getByText('Ảnh 1/3 · Chạm để phóng to', { exact: true }).waitFor();
      const images = page.getByRole('img', { name: 'Ảnh phòng', exact: true });
      await images.nth(2).click();
      await page.getByText('Ảnh 2/3 · Chạm để phóng to', { exact: true }).waitFor();
      await images.first().click();
      await page.getByRole('button', { name: 'Đóng ảnh', exact: true }).click();
      await page.getByRole('button', { name: 'Đóng ảnh', exact: true }).waitFor({ state: 'hidden' });
      await page.mouse.move(1, 1);
      await page.waitForTimeout(350);
      await page.screenshot({ path: screenshot(`room-${number}-photos`) });
      await page.getByRole('button', { name: 'Sửa phòng', exact: true }).click();
      await page.getByRole('button', { name: 'Xóa ảnh 3', exact: true }).waitFor();
      await page.getByRole('button', { name: 'Quay lại', exact: true }).click();
      await page.getByRole('button', { name: 'Đóng', exact: true }).click();
    }
    assert.deepEqual(errors, []);
    console.log(`PASS: ${rooms.length} rooms, ${photos.length} image URLs, reversible real upload/cover/removal, four room-type galleries, enlargement and admin editor. Original galleries preserved.`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
