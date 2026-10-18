const { test, expect, FIXTURE_ORIGIN, getStorage, overlayState } = require('../helpers/fixtures');

async function openPopup(context, extensionId) {
  const popup = await context.newPage();
  await popup.goto(`chrome-extension://${extensionId}/src/popup/popup.html`);
  await expect.poll(async () => (await getStorage(context, 'paceSettings')).paceSettings).toBeTruthy();
  return popup;
}

const settings = async (context) => (await getStorage(context, 'paceSettings')).paceSettings;

test('fresh install shows default controls', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await expect(popup.getByRole('switch', { name: 'Focus overlay' })).not.toBeChecked();
  await expect(popup.getByRole('button', { name: 'Medium' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('button', { name: 'Dark' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('slider', { name: 'Opacity' })).toHaveValue('70');
  await expect(popup.locator('#opacity-value')).toHaveText('70%');
  await expect(popup.getByRole('slider', { name: 'Blur' })).toHaveValue('0');
  await expect(popup.locator('#blur-value')).toHaveText('0px');
  await expect(popup.getByRole('checkbox', { name: 'Share anonymous usage' })).toBeChecked();
});

test('toggling the switch turns the overlay on in an open tab', async ({ context, extensionId, page }) => {
  await page.goto(`${FIXTURE_ORIGIN}/article.html`);
  const popup = await openPopup(context, extensionId);
  await popup.getByRole('switch', { name: 'Focus overlay' }).check();
  await expect.poll(async () => (await settings(context)).enabled).toBe(true);
  await expect.poll(async () => (await overlayState(page)).count).toBe(1);
  await popup.getByRole('switch', { name: 'Focus overlay' }).uncheck();
  await expect.poll(async () => (await overlayState(page)).count).toBe(0);
});

test('picking a size while off also turns Pace on', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await popup.getByRole('button', { name: 'Large' }).click();
  await expect.poll(() => settings(context)).toMatchObject({ size: 'L', enabled: true });
  await expect(popup.getByRole('button', { name: 'Large' })).toHaveAttribute('aria-pressed', 'true');
  await expect(popup.getByRole('button', { name: 'Medium' })).toHaveAttribute('aria-pressed', 'false');
  await expect(popup.getByRole('switch', { name: 'Focus overlay' })).toBeChecked();
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
  await expect(popup.getByRole('switch', { name: 'Focus overlay' })).toBeChecked();
});

test('analytics opt-out is stored', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  await popup.getByRole('checkbox', { name: 'Share anonymous usage' }).uncheck();
  await expect.poll(async () => (await getStorage(context, 'analyticsEnabled')).analyticsEnabled).toBe(false);
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
  await expect(popup.locator('#notice')).toHaveText("Pace can't show on this page. Your settings still apply to other tabs.");
  await page.bringToFront();
  await popup.evaluate(() => globalThis.__pacePopup.checkActiveTab());
  await expect(popup.locator('#notice')).toBeHidden();
});

test('every control has an accessible name', async ({ context, extensionId }) => {
  const popup = await openPopup(context, extensionId);
  const unnamed = await popup.evaluate(() =>
    [...document.querySelectorAll('button, input')]
      .filter((el) => !(el.getAttribute('aria-label') || el.labels?.length || el.textContent.trim()))
      .map((el) => el.outerHTML));
  expect(unnamed).toEqual([]);
});
