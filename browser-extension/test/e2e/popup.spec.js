const { test, expect, FIXTURE_ORIGIN, getStorage, overlayState } = require('../helpers/fixtures');

async function openPopup(context, extensionId) {
  const popup = await context.newPage();
  await popup.goto(`chrome-extension://${extensionId}/src/popup/popup.html`);
  await expect.poll(async () => (await getStorage(context, 'paceSettings')).paceSettings).toBeTruthy();
  return popup;
}

const power = (popup, label) => popup.getByRole('group', { name: 'Pace' }).getByRole('button', { name: label, exact: true });

const settings = async (context) => (await getStorage(context, 'paceSettings')).paceSettings;

test('fresh install shows default controls', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await expect(power(popup, 'Off')).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('button', { name: 'Medium' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('button', { name: 'Dark' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('slider', { name: 'Opacity' })).toHaveValue('70');
  await expect(popup.locator('#opacity-value')).toHaveText('70%');
  await expect(popup.getByRole('slider', { name: 'Blur' })).toHaveValue('0');
  await expect(popup.locator('#blur-value')).toHaveText('0px');
  await expect(popup.getByRole('checkbox')).toHaveCount(0); // no analytics toggle
});

test('turning Pace on from the popup shows the overlay in an open tab', async ({ context, extensionId, page }) => {
  await page.goto(`${FIXTURE_ORIGIN}/article.html`);
  const popup = await openPopup(context, extensionId);
  await power(popup, 'On').click();
  await expect.poll(async () => (await settings(context)).enabled).toBe(true);
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
  await power(popup, 'Off').click();
  await expect.poll(async () => (await overlayState(page)).count).toBe(0);
});

test('picking a size while off also turns Pace on', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await popup.getByRole('button', { name: 'Large' }).click();
  await expect.poll(() => settings(context)).toMatchObject({ size: 'L', enabled: true });
  await expect(popup.getByRole('button', { name: 'Large' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('button', { name: 'Medium' })).toHaveAttribute('aria-pressed', 'false');
  await expect(power(popup, 'On')).toHaveAttribute('aria-pressed', 'true');
});

test('color, opacity and blur controls write settings and labels', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await popup.getByRole('button', { name: 'Light' }).click();
  await expect.poll(async () => (await settings(context)).isDarkMode).toBe(false);
  await popup.getByRole('slider', { name: 'Opacity' }).fill('40');
  await expect(popup.locator('#opacity-value')).toHaveText('40%');
  await expect.poll(async () => (await settings(context)).opacity).toBe(0.4);
  await popup.getByRole('slider', { name: 'Blur' }).fill('12');
  await expect(popup.locator('#blur-value')).toHaveText('12px');
  await expect.poll(async () => (await settings(context)).blurRadius).toBe(12);
});

test('reopening the popup reflects saved values', async ({ context, extensionId }) => {
  let popup = await openPopup(context, extensionId);
  await popup.getByRole('button', { name: 'Small' }).click();
  await popup.getByRole('slider', { name: 'Opacity' }).fill('55');
  await expect.poll(async () => (await settings(context)).opacity).toBe(0.55);
  await popup.close();
  popup = await openPopup(context, extensionId);
  await expect(popup.getByRole('button', { name: 'Small' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('slider', { name: 'Opacity' })).toHaveValue('55');
  await expect(power(popup, 'On')).toHaveAttribute('aria-pressed', 'true');
});

test('preview mirrors size, color and on/off', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  const band = () => popup.evaluate(() => {
    const top = document.querySelector('.dim-top').getBoundingClientRect();
    const bottom = document.querySelector('.dim-bottom').getBoundingClientRect();
    return Math.round(bottom.top - top.bottom);
  });
  await expect.poll(band).toBe(38); // M: 300px * 0.125, rounded
  await expect(popup.locator('.panel')).not.toHaveClass(/is-on/);
  await popup.getByRole('button', { name: 'Large' }).click();
  await expect.poll(band).toBe(56); // L: 450px * 0.125, rounded
  await expect(popup.locator('.panel')).toHaveClass(/is-on/);
  await popup.getByRole('button', { name: 'Light' }).click();
  await expect.poll(() => popup.evaluate(() => getComputedStyle(document.querySelector('.dim-top')).backgroundColor))
    .toBe('rgba(255, 255, 255, 0.7)');
});

test('hovering the preview moves its band', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  const box = await popup.locator('#preview').boundingBox();
  await popup.mouse.move(box.x + 40, box.y + 30);
  await expect.poll(() => popup.evaluate(() => {
    const p = document.getElementById('preview').getBoundingClientRect();
    const t = document.querySelector('.dim-top').getBoundingClientRect();
    return Math.round(t.bottom - p.top);
  })).toBe(Math.round(30 - 37.5 / 2));
});

test('arrow keys move through segmented controls', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await popup.getByRole('button', { name: 'Medium' }).focus();
  await popup.keyboard.press('ArrowRight');
  await expect.poll(async () => (await settings(context)).size).toBe('L');
  await expect(popup.getByRole('button', { name: 'Large' })).toBeFocused();
  await popup.keyboard.press('ArrowRight');
  await expect.poll(async () => (await settings(context)).size).toBe('S');
});

test('notice: shown on restricted pages, hidden on live pages', async ({ context, extensionId, page }) => {
  await page.goto(`${FIXTURE_ORIGIN}/article.html`);
  const popup = await openPopup(context, extensionId);
  // Opened as a tab, the popup's active tab is itself (chrome-extension://) -> restricted.
  await expect(popup.locator('#notice')).toHaveText("Chrome doesn't let extensions run on this page. Pace still works in your other tabs.");
  await page.bringToFront();
  await popup.evaluate(() => globalThis.__pacePopup.checkActiveTab());
  await expect(popup.locator('#notice')).toBeHidden();
});

test('on/off control lights exactly one state and works from the keyboard', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await power(popup, 'On').click();
  await expect.poll(async () => (await settings(context)).enabled).toBe(true);
  await expect(power(popup, 'On')).toHaveAttribute('aria-pressed', 'true');
  await expect(power(popup, 'Off')).toHaveAttribute('aria-pressed', 'false');
  await popup.keyboard.press('ArrowLeft');
  await expect.poll(async () => (await settings(context)).enabled).toBe(false);
  await expect(power(popup, 'Off')).toBeFocused();
});

test('notice: tab without a content script gets one injected instead of a reload prompt', async ({ context, extensionId, page }) => {
  await page.goto(`${FIXTURE_ORIGIN}/article.html`);
  // Make the tab look like it predates install: no live content script answers pings.
  await page.evaluate(() => document.querySelectorAll('pace-focus-overlay').forEach((h) => h.remove()));
  const popup = await openPopup(context, extensionId);
  await page.bringToFront();
  await popup.evaluate(() => globalThis.__pacePopup.checkActiveTab());
  await expect(popup.locator('#notice')).toBeHidden();
});

test('notice: PDFs explain why Pace is not shown', async ({ context, extensionId, page }) => {
  await page.goto(`${FIXTURE_ORIGIN}/doc.pdf`);
  const popup = await openPopup(context, extensionId);
  await power(popup, 'On').click();
  await expect.poll(async () => (await settings(context)).enabled).toBe(true);
  await page.bringToFront();
  await popup.evaluate(() => globalThis.__pacePopup.checkActiveTab());
  await expect(popup.locator('#notice')).toHaveText("Chrome's PDF viewer hides the mouse from extensions, so Pace can't follow it on PDFs.");
});

test('every control has an accessible name', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  const unnamed = await popup.evaluate(() =>
    [...document.querySelectorAll('button, input')]
      .filter((el) => !el.closest('[hidden]'))
      .filter((el) => !(el.getAttribute('aria-label') || el.labels?.length || el.textContent.trim()))
      .map((el) => el.outerHTML));
  expect(unnamed).toEqual([]);
});

test('slider change commits immediately without waiting for a frame', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await popup.evaluate(() => {
    const el = document.getElementById('blur');
    el.value = '7';
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  });
  await popup.close();
  await expect.poll(async () => (await settings(context)).blurRadius).toBe(7);
});

test('a change made before stored settings load keeps the other saved values', async ({ context, extensionId }) => {
  await expect.poll(() => settings(context)).toBeTruthy(); // install has seeded defaults
  await context.serviceWorkers()[0].evaluate(() => chrome.storage.local.set({
    paceSettings: { enabled: false, size: 'M', opacity: 0.35, blurRadius: 6, isDarkMode: false }
  }));
  const popup = await context.newPage();
  // Click as early as possible after the DOM exists.
  await popup.goto(`chrome-extension://${extensionId}/src/popup/popup.html`, { waitUntil: 'commit' });
  await popup.getByRole('button', { name: 'Large' }).click();
  await expect.poll(() => settings(context)).toEqual({ enabled: true, size: 'L', opacity: 0.35, blurRadius: 6, isDarkMode: false });
});

test('a failed initial settings read still lets changes save', async ({ context, extensionId }) => {
  await expect.poll(() => settings(context)).toBeTruthy();
  const popup = await context.newPage();
  await popup.addInitScript(() => {
    const area = chrome.storage.local;
    const get = area.get.bind(area);
    let failed = false;
    area.get = (...args) => (failed ? get(...args) : (failed = true, Promise.reject(new Error('boom'))));
  });
  await popup.goto(`chrome-extension://${extensionId}/src/popup/popup.html`);
  await expect.poll(() => popup.evaluate(() => chrome.storage.local.get.toString().includes('boom'))).toBe(true);
  await popup.getByRole('button', { name: 'Small' }).click();
  await expect.poll(async () => (await settings(context)).size).toBe('S');
});

test('a failed write resyncs the controls with stored settings', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await expect(popup.getByRole('button', { name: 'Medium' })).toHaveAttribute('aria-pressed', 'true');
  await popup.evaluate(() => {
    const area = chrome.storage.local;
    const set = area.set.bind(area);
    let failed = false;
    area.set = (...args) => (failed ? set(...args) : (failed = true, Promise.reject(new Error('quota'))));
  });
  await popup.getByRole('button', { name: 'Large' }).click();
  await expect(popup.getByRole('button', { name: 'Medium' })).toHaveAttribute('aria-pressed', 'true');
  expect((await settings(context)).size).toBe('M');
});
