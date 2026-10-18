const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test: base, expect, EXTENSION_DIR, FIXTURE_ORIGIN, launchWithExtension, setSettings } = require('../helpers/fixtures');

const FAKE_HOST = 'https://posthog.test';

// Copy the extension (without dev files) into a temp dir, optionally adding a test config.json.
function copyExtension(config) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pace-ext-'));
  for (const entry of ['manifest.json', 'src', 'icons']) {
    fs.cpSync(path.join(EXTENSION_DIR, entry), path.join(dir, entry), { recursive: true });
  }
  if (config) fs.writeFileSync(path.join(dir, 'config.json'), JSON.stringify(config));
  return dir;
}

async function launchCapturing(config) {
  const dir = copyExtension(config);
  const launched = await launchWithExtension(dir);
  const captured = [];
  const anyPosthog = [];
  await launched.context.route(/posthog/, async (route) => {
    const req = route.request();
    anyPosthog.push(req.url());
    if (req.url().startsWith(FAKE_HOST)) captured.push(JSON.parse(req.postData() || '{}'));
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{"status":"Ok"}' });
  });
  return { ...launched, dir, captured, anyPosthog };
}

async function cleanup(l) {
  await l.context.close();
  fs.rmSync(l.userDataDir, { recursive: true, force: true });
  fs.rmSync(l.dir, { recursive: true, force: true });
}

const test = base;
test.describe.configure({ mode: 'serial' });

test('with config: enabling sends tagged events and never the page URL', async () => {
  const l = await launchCapturing({ posthogApiKey: 'phc_test', posthogHost: FAKE_HOST });
  try {
    const page = await l.context.newPage();
    await page.goto(`${FIXTURE_ORIGIN}/article.html?secret=1`);
    await setSettings(l.context, { enabled: true });
    await expect.poll(() => l.captured.map((e) => e.event), { timeout: 10_000 })
      .toEqual(expect.arrayContaining(['pace_view_shown', 'mode_activated']));
    for (const e of l.captured) {
      expect(e.properties.platform).toBe('chrome_extension');
      expect(e.api_key).toBe('phc_test');
      expect(JSON.stringify(e)).not.toContain('pace.test');
    }
  } finally {
    await cleanup(l);
  }
});

test('without config.json: zero requests to any PostHog host', async () => {
  const l = await launchCapturing(null);
  try {
    const page = await l.context.newPage();
    await page.goto(`${FIXTURE_ORIGIN}/article.html`);
    await setSettings(l.context, { enabled: true });
    await page.waitForTimeout(1500);
    await setSettings(l.context, { enabled: false });
    await page.waitForTimeout(1500);
    expect(l.anyPosthog).toEqual([]);
  } finally {
    await cleanup(l);
  }
});
