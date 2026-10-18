const {
  test, expect, FIXTURE_ORIGIN, setSettings, setRawStorage, overlayState, settledOverlay, launchWithExtension
} = require('../helpers/fixtures');
const fs = require('node:fs');

const ARTICLE = `${FIXTURE_ORIGIN}/article.html`;
const near = (a, b, tol = 1) => Math.abs(a - b) <= tol;

async function enabledPage(context, page, settings = {}) {
  await setSettings(context, { enabled: true, ...settings });
  await page.goto(ARTICLE);
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
}

async function bandAt(page, y, height) {
  await page.mouse.move(400, y);
  return settledOverlay(page, (s) => s.mounted && near(s.topBottomEdge, y - height / 2) && near(s.bottomTopEdge, y + height / 2));
}

test('mounts exactly one overlay when enabled', async ({ context, page }) => {
  await enabledPage(context, page);
  const s = await overlayState(page);
  expect(s.count).toBe(1);
  expect(s.ariaHidden).toBe('true');
});

test('band centers on the mouse at the default M size (300px)', async ({ context, page }) => {
  await enabledPage(context, page);
  const s = await bandAt(page, 400, 300);
  expect(s.topBottomEdge).toBeCloseTo(250, 0);
  expect(s.bottomTopEdge).toBeCloseTo(550, 0);
  expect(s.topWidth).toBe(s.viewportWidth);
  expect(s.bottomWidth).toBe(s.viewportWidth);
});

test('starts centered in the viewport before any mouse move', async ({ context, page }) => {
  await enabledPage(context, page);
  const s = await settledOverlay(page, (s) => near(s.topBottomEdge, 400 - 150));
  expect(s.topBottomEdge).toBeCloseTo(250, 0);
  expect(s.bottomTopEdge).toBeCloseTo(550, 0);
});

for (const [size, height] of [['S', 200], ['M', 300], ['L', 450]]) {
  test(`size ${size} gives a ${height}px band, updated live`, async ({ context, page }) => {
    await enabledPage(context, page);
    await page.mouse.move(400, 400);
    await setSettings(context, { size });
    const s = await settledOverlay(page, (s) => near(s.bottomTopEdge - s.topBottomEdge, height));
    expect(s.bottomTopEdge - s.topBottomEdge).toBeCloseTo(height, 0);
  });
}

test('dark/light and opacity drive the panel color', async ({ context, page }) => {
  await enabledPage(context, page);
  expect((await overlayState(page)).background).toBe('rgba(0, 0, 0, 0.7)');
  await setSettings(context, { isDarkMode: false, opacity: 0.4 });
  const s = await settledOverlay(page, (s) => s.background === 'rgba(255, 255, 255, 0.4)');
  expect(s.background).toBe('rgba(255, 255, 255, 0.4)');
});

test('blur maps to backdrop-filter', async ({ context, page }) => {
  await enabledPage(context, page);
  expect((await overlayState(page)).backdropFilter).toBe('none');
  await setSettings(context, { blurRadius: 8 });
  const s = await settledOverlay(page, (s) => s.backdropFilter === 'blur(8px)');
  expect(s.backdropFilter).toBe('blur(8px)');
});

test('page stays interactive under the dimmed area', async ({ context, page }) => {
  await enabledPage(context, page);
  await page.mouse.move(400, 400); // band in the middle; button (top) and input (bottom) are dimmed
  await settledOverlay(page, (s) => near(s.topBottomEdge, 250));
  await page.click('#top-button');
  expect(await page.evaluate(() => window.__clicks)).toBe(1);
  await page.click('#bottom-input');
  await page.keyboard.type('hello');
  await expect(page.locator('#bottom-input')).toHaveValue('hello');
  await page.mouse.move(400, 400);
  await page.mouse.wheel(0, 600);
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
});

test('only vertical mouse movement moves the band', async ({ context, page }) => {
  await enabledPage(context, page);
  const before = await bandAt(page, 300, 300);
  await page.mouse.move(1100, 300);
  await page.waitForTimeout(250);
  const after = await overlayState(page);
  expect(after.topBottomEdge).toBeCloseTo(before.topBottomEdge, 0);
});

test('band can run off the top of the viewport', async ({ context, page }) => {
  await enabledPage(context, page);
  await page.mouse.move(400, 0);
  const s = await settledOverlay(page, (s) => near(s.bottomTopEdge, 150));
  expect(s.bottomTopEdge).toBeCloseTo(150, 0);
  expect(s.topBottomEdge).toBeLessThanOrEqual(0);
});

test('viewport resize keeps panels full width and consistent', async ({ context, page }) => {
  await enabledPage(context, page);
  await bandAt(page, 300, 300);
  await page.setViewportSize({ width: 800, height: 600 });
  const s = await settledOverlay(page, (s) => s.topWidth === 800);
  expect(s.topWidth).toBe(800);
  expect(s.bottomWidth).toBe(800);
  expect(s.bottomTopEdge - s.topBottomEdge).toBeCloseTo(300, 0);
});

test('survives hostile page CSS and transformed body', async ({ context, page }) => {
  await setSettings(context, { enabled: true });
  await page.goto(`${FIXTURE_ORIGIN}/hostile.html`);
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
  await page.mouse.move(400, 400);
  const s = await settledOverlay(page, (s) => near(s.topBottomEdge, 250));
  expect(s.topBottomEdge).toBeCloseTo(250, 0);
  expect(s.topWidth).toBe(s.viewportWidth);
  const visible = await page.evaluate(() => {
    const host = document.querySelector('pace-focus-overlay');
    const cs = getComputedStyle(host);
    return cs.display !== 'none' && cs.opacity !== '0';
  });
  expect(visible).toBe(true);
});

test('disable removes the overlay; re-enable mounts exactly one', async ({ context, page }) => {
  await enabledPage(context, page);
  await setSettings(context, { enabled: false });
  await expect.poll(async () => (await overlayState(page)).count).toBe(0);
  await setSettings(context, { enabled: true });
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
});

test('enabling once applies to every open tab, and size changes propagate', async ({ context, page }) => {
  await page.goto(ARTICLE);
  const second = await context.newPage();
  await second.goto(`${FIXTURE_ORIGIN}/second.html`);
  expect((await overlayState(page)).count).toBe(0);
  await setSettings(context, { enabled: true });
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
  await expect.poll(async () => (await overlayState(second)).count).toBe(1);
  await setSettings(context, { size: 'S' });
  for (const p of [page, second]) {
    const s = await settledOverlay(p, (s) => near(s.bottomTopEdge - s.topBottomEdge, 200));
    expect(s.bottomTopEdge - s.topBottomEdge).toBeCloseTo(200, 0);
  }
});

test('persists across reloads and new tabs', async ({ context, page }) => {
  await enabledPage(context, page);
  await page.reload();
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
  const fresh = await context.newPage();
  await fresh.goto(ARTICLE);
  await expect.poll(async () => (await overlayState(fresh)).count).toBe(1);
});

test('corrupted stored settings fall back to defaults without page errors', async ({ context, page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await setRawStorage(context, { paceSettings: 'garbage' });
  await page.goto(ARTICLE);
  await page.waitForTimeout(300);
  expect((await overlayState(page)).count).toBe(0); // defaults => disabled
  await setRawStorage(context, { paceSettings: { enabled: true, size: 'nope', opacity: 'x' } });
  const s = await settledOverlay(page, (s) => s.mounted && s.background === 'rgba(0, 0, 0, 0.7)');
  expect(s.bottomTopEdge - s.topBottomEdge).toBeCloseTo(300, 0);
  expect(errors).toEqual([]);
});

test('unrelated storage writes do not remount the overlay', async ({ context, page }) => {
  await enabledPage(context, page);
  await page.evaluate(() => { document.querySelector('pace-focus-overlay').dataset.marker = 'original'; });
  await setRawStorage(context, { paceAnalyticsTimestamps: { viewShownAt: 1 } });
  await page.waitForTimeout(200);
  const marker = await page.evaluate(() => document.querySelector('pace-focus-overlay')?.dataset.marker);
  expect(marker).toBe('original');
});

test('300 rapid mouse moves: no errors and final position wins', async ({ context, page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await enabledPage(context, page);
  for (let i = 0; i < 300; i++) await page.mouse.move(400, 100 + (i % 600));
  await page.mouse.move(400, 500);
  const s = await settledOverlay(page, (s) => near(s.topBottomEdge, 350));
  expect(s.topBottomEdge).toBeCloseTo(350, 0);
  expect(errors).toEqual([]);
});

test('reduced motion disables transitions', async () => {
  const launched = await launchWithExtension(undefined, { reducedMotion: 'reduce' });
  try {
    const page = await launched.context.newPage();
    await enabledPage(launched.context, page);
    expect((await overlayState(page)).transitionDuration).toMatch(/^0s(, 0s)*$/);
  } finally {
    await launched.context.close();
    fs.rmSync(launched.userDataDir, { recursive: true, force: true });
  }
});

// Note: in automation, chrome.runtime.reload() unloads an unpacked --load-extension build for good,
// so the full "update -> re-inject" cycle is covered manually in test/QA_CHECKLIST.md.
test('orphaned overlay removes itself once the extension context is gone', async ({ context, page }) => {
  await enabledPage(context, page);
  const worker = context.serviceWorkers()[0];
  await worker.evaluate(() => { setTimeout(() => chrome.runtime.reload(), 10); });
  await page.waitForTimeout(1000);
  await page.mouse.move(400, 300);
  await expect.poll(async () => (await overlayState(page)).count, { timeout: 5_000 }).toBe(0);
});

test('re-injection on update keeps exactly one live overlay', async ({ context, page }) => {
  await enabledPage(context, page);
  const worker = context.serviceWorkers()[0];
  await worker.evaluate(() => globalThis.__paceBackground.onInstalled({ reason: 'update' }));
  await page.waitForTimeout(300);
  expect((await overlayState(page)).count).toBe(1);
  await setSettings(context, { size: 'L' });
  await page.mouse.move(400, 400);
  const s = await settledOverlay(page, (s) => near(s.bottomTopEdge - s.topBottomEdge, 450));
  expect(s.count).toBe(1);
  expect(s.bottomTopEdge - s.topBottomEdge).toBeCloseTo(450, 0);
  await setSettings(context, { enabled: false });
  await expect.poll(async () => (await overlayState(page)).count).toBe(0);
});

test('overlay re-attaches after a page script removes it', async ({ context, page }) => {
  await enabledPage(context, page);
  await page.evaluate(() => document.documentElement.replaceChildren(document.createElement('body')));
  expect((await overlayState(page)).count).toBe(0);
  await page.mouse.move(400, 420);
  await page.mouse.move(400, 400);
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
  const s = await settledOverlay(page, (s) => near(s.topBottomEdge, 250));
  expect(s.topBottomEdge).toBeCloseTo(250, 0);
});

test('turning Pace off also clears a leftover host from an orphaned instance', async ({ context, page }) => {
  await enabledPage(context, page);
  // Simulate a stale host left by an orphaned script in addition to the live one.
  await page.evaluate(() => document.documentElement.appendChild(document.createElement('pace-focus-overlay')));
  expect((await overlayState(page)).count).toBe(2);
  await setSettings(context, { enabled: false });
  await expect.poll(async () => (await overlayState(page)).count).toBe(0);
});

test('does not mount over PDFs (the viewer swallows mouse events)', async ({ context, page }) => {
  await setSettings(context, { enabled: true });
  await page.goto(`${FIXTURE_ORIGIN}/doc.pdf`);
  await page.waitForTimeout(1500);
  expect((await overlayState(page)).count).toBe(0);
});
