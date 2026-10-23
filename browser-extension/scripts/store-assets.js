// Renders Chrome Web Store images into store/images/ using the real extension.
// Usage: npm run store:assets   (needs: npx playwright install chromium)
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { chromium } = require('@playwright/test');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'store', 'assets-src');
const OUT = path.join(ROOT, 'store', 'images');
const ORIGIN = 'https://pace.test';

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pace-store-'));
  const context = await chromium.launchPersistentContext(userDataDir, {
    channel: 'chromium',
    headless: true,
    viewport: { width: 1280, height: 800 },
    args: [`--disable-extensions-except=${ROOT}`, `--load-extension=${ROOT}`]
  });
  try {
    await context.route(`${ORIGIN}/**`, (route) => {
      const file = path.join(SRC, path.basename(new URL(route.request().url()).pathname));
      if (!fs.existsSync(file)) return route.fulfill({ status: 404, body: '' });
      return route.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: fs.readFileSync(file) });
    });
    let [worker] = context.serviceWorkers();
    if (!worker) worker = await context.waitForEvent('serviceworker');
    const extensionId = new URL(worker.url()).host;
    const setSettings = (s) => worker.evaluate((s) => chrome.storage.local.set({ paceSettings: s }), s);
    const base = { enabled: true, size: 'M', opacity: 0.7, blurRadius: 0, isDarkMode: true };

    const page = context.pages()[0] || (await context.newPage());
    await page.goto(`${ORIGIN}/article.html`);

    async function articleShot(settings, y, file) {
      await setSettings(settings);
      await page.mouse.move(640, y - 20);
      await page.mouse.move(640, y);
      await page.waitForTimeout(700);
      const buf = await page.screenshot();
      if (file) fs.writeFileSync(path.join(OUT, file), buf);
      return buf;
    }

    async function popupShot(settings) {
      await setSettings(settings);
      const popup = await context.newPage();
      await popup.setViewportSize({ width: 320, height: 430 });
      await popup.goto(`chrome-extension://${extensionId}/src/popup/popup.html`);
      // Opened as a tab the popup's "active tab" is itself; hide the notice that causes.
      await popup.addStyleTag({ content: '#notice { display: none !important; }' });
      await popup.waitForTimeout(500);
      const buf = await popup.screenshot({ fullPage: true });
      await popup.close();
      return buf;
    }

    async function composite(shotBuf, popupBuf, file) {
      // The frame page is itself a web page: keep Pace's overlay off it.
      await setSettings({ ...base, enabled: false });
      const frame = await context.newPage();
      await frame.setViewportSize({ width: 1280, height: 800 });
      await frame.goto(`${ORIGIN}/frame.html`);
      await frame.evaluate(([shot, pop]) => {
        document.getElementById('shot').style.backgroundImage = `url(data:image/png;base64,${shot})`;
        document.getElementById('popup').src = `data:image/png;base64,${pop}`;
      }, [shotBuf.toString('base64'), popupBuf.toString('base64')]);
      await frame.waitForTimeout(300);
      await frame.screenshot({ path: path.join(OUT, file) });
      await frame.close();
    }

    await articleShot(base, 470, 'screenshot-1-focus-band.png');
    await composite(await articleShot(base, 470), await popupShot(base), 'screenshot-2-popup.png');
    const light = { ...base, isDarkMode: false, opacity: 0.85, size: 'L' };
    await composite(await articleShot(light, 520), await popupShot(light), 'screenshot-3-light.png');
    const frosted = { ...base, size: 'S', opacity: 0.55, blurRadius: 6 };
    await articleShot(frosted, 500, 'screenshot-4-blur.png');

    await setSettings({ ...base, enabled: false });
    for (const [w, h, file] of [[440, 280, 'promo-small-440x280.png'], [1400, 560, 'promo-marquee-1400x560.png']]) {
      const promo = await context.newPage();
      await promo.setViewportSize({ width: w, height: h });
      await promo.goto(`${ORIGIN}/promo.html`);
      await promo.addStyleTag({ content: `body { --w: ${w}px; --h: ${h}px; }` });
      await promo.waitForTimeout(200);
      await promo.screenshot({ path: path.join(OUT, file) });
      await promo.close();
    }
    console.log('wrote', fs.readdirSync(OUT).join(', '));
  } finally {
    await context.close();
    fs.rmSync(userDataDir, { recursive: true, force: true });
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
