// @ts-check
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './test/e2e',
  // Each test launches its own persistent Chromium context with the extension loaded.
  workers: 2,
  fullyParallel: true,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  retries: 0,
  reporter: [['list']],
  use: { trace: 'retain-on-failure' }
});
