// Loads src/background.js in a vm sandbox with a fake `chrome`, `fetch` and clock.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const SRC = path.resolve(__dirname, '..', '..', 'src');
const EXT_ID = 'testextensionid';

function createHarness({ config = { posthogApiKey: 'phc_test', posthogHost: 'https://ph.test' }, storage = {}, tabs = [], captureFails = false } = {}) {
  const store = structuredClone(storage);
  const listeners = { installed: [], startup: [], changed: [], message: [] };
  const captures = [];
  const injected = [];
  let clock = 1_000_000;

  function emitChanged(changes) {
    for (const fn of listeners.changed) fn(changes, 'local');
  }

  const chrome = {
    runtime: {
      id: EXT_ID,
      getURL: (p) => `chrome-extension://${EXT_ID}/${p}`,
      getManifest: () => ({ version: '0.1.0' }),
      onInstalled: { addListener: (fn) => listeners.installed.push(fn) },
      onStartup: { addListener: (fn) => listeners.startup.push(fn) },
      onMessage: { addListener: (fn) => listeners.message.push(fn) }
    },
    storage: {
      local: {
        async get(keys) {
          if (keys == null) return structuredClone(store);
          const list = Array.isArray(keys) ? keys : [keys];
          const out = {};
          for (const k of list) if (k in store) out[k] = structuredClone(store[k]);
          return out;
        },
        async set(items) {
          const changes = {};
          for (const [k, v] of Object.entries(items)) {
            changes[k] = { oldValue: store[k], newValue: structuredClone(v) };
            store[k] = structuredClone(v);
          }
          emitChanged(changes);
        }
      },
      onChanged: { addListener: (fn) => listeners.changed.push(fn) }
    },
    tabs: { query: async () => tabs },
    scripting: {
      async executeScript({ target, files }) {
        const tab = tabs.find((t) => t.id === target.tabId);
        if (tab && tab.rejects) throw new Error('Cannot access contents of the page');
        injected.push({ tabId: target.tabId, files: [...files] });
        return [];
      }
    }
  };

  async function fetchImpl(url, init) {
    if (url.endsWith('/config.json')) {
      if (!config) throw new TypeError('Failed to fetch');
      return { ok: true, json: async () => config };
    }
    captures.push({ url, body: JSON.parse(init.body) });
    if (captureFails) throw new TypeError('network down');
    return { ok: true, status: 200 };
  }

  const sandbox = {
    chrome,
    fetch: fetchImpl,
    console,
    URL,
    crypto: globalThis.crypto,
    Date: class extends Date { static now() { return clock; } },
    Promise,
    setTimeout
  };
  sandbox.globalThis = sandbox;
  sandbox.self = sandbox;
  sandbox.importScripts = (...files) => {
    for (const f of files) vm.runInContext(fs.readFileSync(path.join(SRC, f), 'utf8'), sandbox, { filename: f });
  };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(SRC, 'background.js'), 'utf8'), sandbox, { filename: 'background.js' });

  const bg = sandbox.__paceBackground;
  return {
    store,
    captures,
    injected,
    events: () => captures.map((c) => c.body.event),
    advance: (ms) => { clock += ms; },
    now: () => clock,
    idle: async () => { for (let i = 0; i < 5; i++) await bg.idle(); },
    install: async (reason = 'install') => { listeners.installed.forEach((fn) => fn({ reason })); },
    startup: async () => { listeners.startup.forEach((fn) => fn()); },
    message: (msg, sender) => listeners.message.forEach((fn) => fn(msg, sender)),
    setSettings: (patch) => chrome.storage.local.set({ paceSettings: { ...(store.paceSettings || {}), ...patch } })
  };
}

test('first install writes defaults, creates an id, and sends app_opened once', async () => {
  const h = createHarness();
  await h.install('install');
  await h.idle();
  assert.deepEqual(h.store.paceSettings, { enabled: false, size: 'M', opacity: 0.7, blurRadius: 0, isDarkMode: true });
  assert.match(h.store.paceAnalyticsId, /^[0-9a-f-]{36}$/);
  assert.deepEqual(h.events(), ['app_opened']);
  assert.equal(h.captures[0].body.properties.is_new_user, true);
  assert.equal(h.captures[0].url, 'https://ph.test/i/v0/e/');
});

test('install never rewrites settings that already exist', async () => {
  const h = createHarness({ storage: { paceSettings: { enabled: true, size: 'L' } } });
  await h.install('install');
  await h.idle();
  assert.deepEqual(h.store.paceSettings, { enabled: true, size: 'L' });
});

test('update keeps existing settings and sends no app_opened', async () => {
  const h = createHarness({ storage: { paceSettings: { enabled: true, size: 'L', opacity: 0.4, blurRadius: 3, isDarkMode: false }, paceAnalyticsId: 'abc' } });
  await h.install('update');
  await h.idle();
  assert.deepEqual(h.store.paceSettings, { enabled: true, size: 'L', opacity: 0.4, blurRadius: 3, isDarkMode: false });
  assert.equal(h.store.paceAnalyticsId, 'abc');
  assert.deepEqual(h.events(), []);
});

test('install and update re-inject into http(s) tabs only, tolerating failures', async () => {
  const tabs = [
    { id: 1, url: 'https://a.test/' },
    { id: 2, url: 'chrome://extensions' },
    { id: 3, url: 'https://blocked.test/', rejects: true },
    { id: 4, url: 'http://localhost:3000/' },
    { id: 5, url: 'https://chromewebstore.google.com/detail/x' }
  ];
  const h = createHarness({ tabs });
  await h.install('update');
  await h.idle();
  assert.deepEqual(h.injected.map((i) => i.tabId), [1, 4]);
  assert.deepEqual(h.injected[0].files, ['src/core.js', 'src/content.js']);
});

test('enable then disable 90s later sends shown/activated then hidden/deactivated with durations', async () => {
  const h = createHarness({ storage: { paceSettings: { enabled: false } } });
  await h.setSettings({ enabled: true });
  await h.idle();
  assert.deepEqual(h.events(), ['pace_view_shown', 'mode_activated']);
  assert.equal(h.captures[1].body.properties.size, 'M');
  h.advance(90_000);
  await h.setSettings({ enabled: false });
  await h.idle();
  assert.deepEqual(h.events().slice(2), ['pace_view_hidden', 'mode_deactivated']);
  assert.equal(h.captures[2].body.properties.view_duration_seconds, 90);
  assert.equal(h.captures[3].body.properties.duration_seconds, 90);
});

test('every payload is tagged chrome_extension with one stable distinct_id', async () => {
  const h = createHarness();
  await h.install('install');
  await h.setSettings({ enabled: true });
  await h.setSettings({ size: 'L' });
  await h.idle();
  assert.ok(h.captures.length >= 5);
  const ids = new Set(h.captures.map((c) => c.body.distinct_id));
  assert.equal(ids.size, 1);
  for (const c of h.captures) {
    assert.equal(c.body.properties.platform, 'chrome_extension');
    assert.equal(c.body.properties.extension_version, '0.1.0');
    assert.equal(c.body.api_key, 'phc_test');
  }
});

test('display-only changes send nothing', async () => {
  const h = createHarness({ storage: { paceSettings: { enabled: true } } });
  await h.setSettings({ opacity: 0.3 });
  await h.setSettings({ blurRadius: 9 });
  await h.setSettings({ isDarkMode: false });
  await h.idle();
  assert.deepEqual(h.events(), []);
});

test('browser startup while enabled resets the session timer', async () => {
  const threeDaysAgo = 1_000_000 - 3 * 24 * 3600 * 1000;
  const h = createHarness({
    storage: { paceSettings: { enabled: true }, paceAnalyticsTimestamps: { viewShownAt: threeDaysAgo, modeShownAt: threeDaysAgo } }
  });
  await h.startup();
  await h.idle();
  assert.deepEqual(h.events(), ['app_opened', 'pace_view_shown', 'mode_activated']);
  assert.equal(h.captures[0].body.properties.is_new_user, false);
  assert.equal(h.store.paceAnalyticsTimestamps.viewShownAt, h.now());
  h.advance(60_000);
  await h.setSettings({ enabled: false });
  await h.idle();
  const hidden = h.captures.find((c) => c.body.event === 'pace_view_hidden');
  assert.equal(hidden.body.properties.view_duration_seconds, 60);
});

test('browser startup while disabled only sends app_opened', async () => {
  const h = createHarness({ storage: { paceSettings: { enabled: false } } });
  await h.startup();
  await h.idle();
  assert.deepEqual(h.events(), ['app_opened']);
});

test('opting out stops all sends', async () => {
  const h = createHarness({ storage: { analyticsEnabled: false } });
  await h.install('install');
  await h.setSettings({ enabled: true });
  await h.startup();
  h.message({ type: 'popup_opened' }, { id: EXT_ID });
  await h.idle();
  assert.deepEqual(h.captures, []);
});

test('missing config means zero network calls and no errors', async () => {
  const h = createHarness({ config: null });
  await h.install('install');
  await h.idle();
  await h.setSettings({ enabled: true });
  await h.idle();
  assert.deepEqual(h.captures, []);
  assert.equal(h.store.paceSettings.enabled, true);
});

test('non-https host disables analytics', async () => {
  const h = createHarness({ config: { posthogApiKey: 'phc', posthogHost: 'http://evil.test' } });
  await h.install('install');
  await h.setSettings({ enabled: true });
  await h.idle();
  assert.deepEqual(h.captures, []);
});

test('network failures are swallowed and timestamps still update', async () => {
  const h = createHarness({ captureFails: true });
  await h.setSettings({ enabled: true });
  await h.idle();
  assert.equal(h.captures.length, 2, 'sends were attempted');
  assert.equal(h.store.paceAnalyticsTimestamps.viewShownAt, h.now());
});

test('popup_opened is accepted only from the extension popup', async () => {
  const h = createHarness();
  h.message({ type: 'popup_opened' }, { id: EXT_ID, tab: { id: 9 } });
  h.message({ type: 'popup_opened' }, { id: 'someone-else' });
  await h.idle();
  assert.deepEqual(h.events(), []);
  h.message({ type: 'popup_opened' }, { id: EXT_ID });
  await h.idle();
  assert.deepEqual(h.events(), ['popup_opened']);
});

test('rapid toggles are processed in order', async () => {
  const h = createHarness({ storage: { paceSettings: { enabled: false } } });
  h.setSettings({ enabled: true });
  h.setSettings({ enabled: false });
  h.setSettings({ enabled: true });
  await h.idle();
  assert.deepEqual(h.events(), ['pace_view_shown', 'mode_activated', 'pace_view_hidden', 'mode_deactivated', 'pace_view_shown', 'mode_activated']);
});
