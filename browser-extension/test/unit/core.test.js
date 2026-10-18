const test = require('node:test');
const assert = require('node:assert/strict');
const Core = require('../../src/core.js');

const DEFAULTS = { enabled: false, size: 'M', opacity: 0.7, blurRadius: 0, isDarkMode: true };

test('normalizeSettings returns defaults for missing input', () => {
  assert.deepEqual(Core.normalizeSettings(undefined), DEFAULTS);
  assert.deepEqual(Core.normalizeSettings(null), DEFAULTS);
  assert.deepEqual(Core.normalizeSettings({}), DEFAULTS);
  assert.deepEqual(Core.normalizeSettings('garbage'), DEFAULTS);
  assert.deepEqual(Core.normalizeSettings([1, 2]), DEFAULTS);
});

test('normalizeSettings repairs invalid values', () => {
  assert.equal(Core.normalizeSettings({ size: 'XL' }).size, 'M');
  assert.equal(Core.normalizeSettings({ opacity: 5 }).opacity, 1);
  assert.equal(Core.normalizeSettings({ opacity: 0 }).opacity, 0.1);
  assert.equal(Core.normalizeSettings({ opacity: 'abc' }).opacity, 0.7);
  assert.equal(Core.normalizeSettings({ opacity: NaN }).opacity, 0.7);
  assert.equal(Core.normalizeSettings({ opacity: '0.4' }).opacity, 0.4);
  assert.equal(Core.normalizeSettings({ blurRadius: -3 }).blurRadius, 0);
  assert.equal(Core.normalizeSettings({ blurRadius: 99 }).blurRadius, 20);
  assert.equal(Core.normalizeSettings({ enabled: 'yes' }).enabled, false);
  assert.equal(Core.normalizeSettings({ enabled: 1 }).enabled, false);
  assert.equal(Core.normalizeSettings({ isDarkMode: null }).isDarkMode, true);
  assert.equal(Core.normalizeSettings({ isDarkMode: false }).isDarkMode, false);
});

test('normalizeSettings keeps valid values and drops unknown keys', () => {
  const input = { enabled: true, size: 'L', opacity: 0.4, blurRadius: 8, isDarkMode: false, extra: 'x', mode: 'circle' };
  assert.deepEqual(Core.normalizeSettings(input), { enabled: true, size: 'L', opacity: 0.4, blurRadius: 8, isDarkMode: false });
});

test('bandHeight follows macOS multipliers on a 200px base', () => {
  assert.equal(Core.bandHeight('S'), 200);
  assert.equal(Core.bandHeight('M'), 300);
  assert.equal(Core.bandHeight('L'), 450);
  assert.equal(Core.bandHeight('nope'), 300);
  assert.equal(Core.bandHeight(undefined), 300);
});

test('panelOffsets centers the band on y', () => {
  const o = Core.panelOffsets(400, 300);
  assert.equal(o.bandTop, 250);
  assert.equal(o.bandBottom, 550);
  assert.equal(o.topTranslate, 250, 'top panel (anchored above viewport) bottom edge at 250');
  assert.equal(o.bottomTranslate, 550, 'bottom panel top edge at 550');
});

test('panelOffsets does not clamp at the viewport edges', () => {
  const atTop = Core.panelOffsets(0, 300);
  assert.equal(atTop.topTranslate, -150, 'top panel bottom edge at -150');
  assert.equal(atTop.bottomTranslate, 150);
  assert.equal(Core.panelOffsets(1000, 300).bottomTranslate, 1150);
});

test('panelOffsets keeps band height exact even when taller than the viewport', () => {
  const o = Core.panelOffsets(300, 900);
  assert.equal(o.bottomTranslate - o.topTranslate, 900);
});

test('dimColor and blurFilter', () => {
  assert.equal(Core.dimColor(true, 0.7), 'rgba(0, 0, 0, 0.7)');
  assert.equal(Core.dimColor(false, 1), 'rgba(255, 255, 255, 1)');
  assert.equal(Core.blurFilter(0), 'none');
  assert.equal(Core.blurFilter(8), 'blur(8px)');
});

test('isRestrictedUrl flags pages Chrome will not script', () => {
  for (const url of [
    'chrome://extensions', 'chrome-extension://abc/popup.html', 'https://chromewebstore.google.com/detail/x',
    'https://chrome.google.com/webstore/detail/x', 'edge://settings', 'about:blank',
    'view-source:https://a.com', 'devtools://devtools/x', 'data:text/html,hi', undefined, '', 'not a url'
  ]) {
    assert.equal(Core.isRestrictedUrl(url), true, String(url));
  }
  for (const url of ['https://example.com', 'http://localhost:3000', 'https://chrome.google.com/search']) {
    assert.equal(Core.isRestrictedUrl(url), false, url);
  }
});

test('isRestrictedUrl treats file:// as restricted unless file access is allowed', () => {
  assert.equal(Core.isRestrictedUrl('file:///Users/me/a.html'), true);
  assert.equal(Core.isRestrictedUrl('file:///Users/me/a.html', false), true);
  assert.equal(Core.isRestrictedUrl('file:///Users/me/a.html', true), false);
});

test('nextSize cycles S -> M -> L -> S', () => {
  assert.equal(Core.nextSize('S'), 'M');
  assert.equal(Core.nextSize('M'), 'L');
  assert.equal(Core.nextSize('L'), 'S');
});

const on = (size = 'M') => ({ ...DEFAULTS, enabled: true, size });
const off = (size = 'M') => ({ ...DEFAULTS, enabled: false, size });
const names = (r) => r.events.map((e) => e.event);

test('analytics: enabling emits view shown + mode activated and records timestamps', () => {
  const r = Core.analyticsEventsFor(off(), on('L'), {}, 1000);
  assert.deepEqual(names(r), ['pace_view_shown', 'mode_activated']);
  assert.deepEqual(r.events[1].properties, { mode: 'rectangle', size: 'L' });
  assert.equal(r.timestamps.viewShownAt, 1000);
  assert.equal(r.timestamps.modeShownAt, 1000);
});

test('analytics: first ever enable (no old value) counts as enable', () => {
  assert.deepEqual(names(Core.analyticsEventsFor(undefined, on(), {}, 0)), ['pace_view_shown', 'mode_activated']);
});

test('analytics: disabling emits hidden + deactivated with durations', () => {
  const r = Core.analyticsEventsFor(on(), off(), { viewShownAt: 0, modeShownAt: 30_000 }, 90_000);
  assert.deepEqual(names(r), ['pace_view_hidden', 'mode_deactivated']);
  assert.equal(r.events[0].properties.view_duration_seconds, 90);
  assert.deepEqual(r.events[1].properties, { mode: 'rectangle', size: 'M', duration_seconds: 60 });
  assert.equal(r.timestamps.viewShownAt, undefined);
});

test('analytics: missing timestamps omit durations instead of NaN', () => {
  const r = Core.analyticsEventsFor(on(), off(), {}, 90_000);
  assert.equal('view_duration_seconds' in r.events[0].properties, false);
  assert.equal('duration_seconds' in r.events[1].properties, false);
});

test('analytics: size change while enabled swaps modes', () => {
  const r = Core.analyticsEventsFor(on('S'), on('L'), { viewShownAt: 0, modeShownAt: 0 }, 10_000);
  assert.deepEqual(names(r), ['mode_deactivated', 'mode_activated']);
  assert.equal(r.events[0].properties.size, 'S');
  assert.equal(r.events[0].properties.duration_seconds, 10);
  assert.equal(r.events[1].properties.size, 'L');
  assert.equal(r.timestamps.viewShownAt, 0, 'view timer keeps running');
  assert.equal(r.timestamps.modeShownAt, 10_000);
});

test('analytics: display-only changes and disabled size changes emit nothing', () => {
  assert.deepEqual(names(Core.analyticsEventsFor(on(), { ...on(), opacity: 0.3, blurRadius: 5, isDarkMode: false }, {}, 0)), []);
  assert.deepEqual(names(Core.analyticsEventsFor(off('S'), off('L'), {}, 0)), []);
});

test('buildCapturePayload tags platform and strips page identifiers', () => {
  const p = Core.buildCapturePayload({
    apiKey: 'phc_x', event: 'mode_activated', distinctId: 'id-1', extensionVersion: '0.1.0', now: 0,
    properties: { size: 'M', url: 'https://secret.example', title: 'Secret', $current_url: 'https://x' }
  });
  assert.equal(p.api_key, 'phc_x');
  assert.equal(p.event, 'mode_activated');
  assert.equal(p.distinct_id, 'id-1');
  assert.equal(p.timestamp, '1970-01-01T00:00:00.000Z');
  assert.equal(p.properties.platform, 'chrome_extension');
  assert.equal(p.properties.extension_version, '0.1.0');
  assert.equal(p.properties.size, 'M');
  assert.equal('url' in p.properties, false);
  assert.equal('title' in p.properties, false);
  assert.equal('$current_url' in p.properties, false);
});

test('validAnalyticsConfig requires a key and an https host', () => {
  assert.equal(Core.validAnalyticsConfig(null), null);
  assert.equal(Core.validAnalyticsConfig({ posthogApiKey: '' }), null);
  assert.equal(Core.validAnalyticsConfig({ posthogApiKey: '  ' }), null);
  assert.equal(Core.validAnalyticsConfig({ posthogApiKey: 'phc', posthogHost: 'http://evil.test' }), null);
  assert.equal(Core.validAnalyticsConfig({ posthogApiKey: 'phc', posthogHost: 'not a url' }), null);
  assert.deepEqual(Core.validAnalyticsConfig({ posthogApiKey: 'phc' }), { apiKey: 'phc', endpoint: 'https://us.i.posthog.com/i/v0/e/' });
  assert.deepEqual(Core.validAnalyticsConfig({ posthogApiKey: 'phc', posthogHost: 'https://eu.i.posthog.com/' }), { apiKey: 'phc', endpoint: 'https://eu.i.posthog.com/i/v0/e/' });
});
