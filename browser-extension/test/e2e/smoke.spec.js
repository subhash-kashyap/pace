const { test, expect, getStorage } = require('../helpers/fixtures');

test('extension loads and its service worker registers', async ({ launched }) => {
  expect(launched.extensionId).toMatch(/^[a-p]{32}$/);
  expect(launched.worker.url()).toContain('/src/background.js');
});

test('install seeds default settings', async ({ context }) => {
  await expect.poll(async () => (await getStorage(context, 'paceSettings')).paceSettings).toEqual({
    enabled: false, size: 'M', opacity: 0.7, blurRadius: 0, isDarkMode: true
  });
});

test('popup opens without errors', async ({ context, extensionId }) => {
  const errors = [];
  const popup = await context.newPage();
  popup.on('pageerror', (e) => errors.push(e.message));
  popup.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  await popup.goto(`chrome-extension://${extensionId}/src/popup/popup.html`);
  await expect(popup.getByRole('switch', { name: 'Reading focus' })).toBeVisible();
  expect(errors).toEqual([]);
});
