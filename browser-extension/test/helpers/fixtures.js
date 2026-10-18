// Shared Playwright fixtures: launch Chromium with the unpacked extension loaded.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const base = require('@playwright/test');

const EXTENSION_DIR = path.resolve(__dirname, '..', '..');
const FIXTURE_DIR = path.resolve(__dirname, '..', 'e2e', 'fixtures');
const FIXTURE_ORIGIN = 'https://pace.test';
const SETTINGS_KEY = 'paceSettings';

async function routeFixtures(context) {
  await context.route(`${FIXTURE_ORIGIN}/**`, async (route) => {
    const { pathname } = new URL(route.request().url());
    const file = path.join(FIXTURE_DIR, path.basename(pathname) || 'article.html');
    if (!fs.existsSync(file)) return route.fulfill({ status: 404, body: 'not found' });
    return route.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: fs.readFileSync(file) });
  });
}

async function launchWithExtension(extensionDir = EXTENSION_DIR, options = {}) {
  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pace-e2e-'));
  const context = await base.chromium.launchPersistentContext(userDataDir, {
    channel: 'chromium',
    headless: options.headless ?? true,
    viewport: { width: 1280, height: 800 },
    reducedMotion: options.reducedMotion,
    args: [`--disable-extensions-except=${extensionDir}`, `--load-extension=${extensionDir}`]
  });
  await routeFixtures(context);
  let [worker] = context.serviceWorkers();
  if (!worker) worker = await context.waitForEvent('serviceworker');
  const extensionId = new URL(worker.url()).host;
  return { context, worker, extensionId, userDataDir };
}

// Fetch the live service worker (it may have been restarted since launch).
async function getWorker(context) {
  const workers = context.serviceWorkers();
  if (workers.length) return workers[workers.length - 1];
  return context.waitForEvent('serviceworker');
}

async function setSettings(context, patch) {
  const worker = await getWorker(context);
  await worker.evaluate(async ({ key, patch }) => {
    const current = (await chrome.storage.local.get(key))[key] || {};
    await chrome.storage.local.set({ [key]: { ...current, ...patch } });
  }, { key: SETTINGS_KEY, patch });
}

async function getStorage(context, keys) {
  const worker = await getWorker(context);
  return worker.evaluate((keys) => chrome.storage.local.get(keys), keys ?? null);
}

async function setRawStorage(context, items) {
  const worker = await getWorker(context);
  await worker.evaluate((items) => chrome.storage.local.set(items), items);
}

// Panel geometry and styles live in the overlay's open shadow root.
async function overlayState(page) {
  return page.evaluate(() => {
    const hosts = document.querySelectorAll('pace-focus-overlay');
    const host = hosts[0];
    if (!host || !host.shadowRoot) return { count: hosts.length, mounted: false };
    const top = host.shadowRoot.querySelector('.top');
    const bottom = host.shadowRoot.querySelector('.bottom');
    const t = top.getBoundingClientRect();
    const b = bottom.getBoundingClientRect();
    const cs = getComputedStyle(top);
    return {
      count: hosts.length,
      mounted: true,
      ariaHidden: host.getAttribute('aria-hidden'),
      topBottomEdge: t.bottom,
      bottomTopEdge: b.top,
      topWidth: t.width,
      bottomWidth: b.width,
      background: cs.backgroundColor,
      backdropFilter: cs.backdropFilter,
      transitionDuration: cs.transitionDuration,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight
    };
  });
}

// Wait until the predicate holds and geometry is stable across two reads (transitions finished).
async function settledOverlay(page, predicate, timeout = 3000) {
  const deadline = Date.now() + timeout;
  let prev = null;
  let state;
  do {
    state = await overlayState(page);
    const stable = prev && state.topBottomEdge === prev.topBottomEdge && state.bottomTopEdge === prev.bottomTopEdge
      && state.background === prev.background && state.topWidth === prev.topWidth;
    if (stable && predicate(state)) return state;
    prev = state;
    await page.waitForTimeout(60);
  } while (Date.now() < deadline);
  return state;
}

const test = base.test.extend({
  launched: async ({}, use) => {
    const launched = await launchWithExtension();
    await use(launched);
    await launched.context.close();
    fs.rmSync(launched.userDataDir, { recursive: true, force: true });
  },
  context: async ({ launched }, use) => use(launched.context),
  extensionId: async ({ launched }, use) => use(launched.extensionId),
  page: async ({ context }, use) => {
    const page = context.pages()[0] || (await context.newPage());
    await use(page);
  }
});

module.exports = {
  test,
  expect: base.expect,
  EXTENSION_DIR,
  FIXTURE_ORIGIN,
  SETTINGS_KEY,
  launchWithExtension,
  getWorker,
  setSettings,
  setRawStorage,
  getStorage,
  overlayState,
  settledOverlay
};
