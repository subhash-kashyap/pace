// Pace shared core: pure logic used by the content script, popup, service worker and Node tests.
// Classic script (no modules) so it can load anywhere without a build step.
(function (root) {
  'use strict';

  var SETTINGS_KEY = 'paceSettings';
  var BASE_BAND_HEIGHT = 200; // matches FocusConfiguration.baseRectangleHeight on macOS

  // Mirrors FocusSize multipliers in pace/FocusShape.swift
  var SIZES = { S: 1.0, M: 1.5, L: 2.25 };

  var OPACITY_MIN = 0.1;
  var OPACITY_MAX = 1.0;
  var BLUR_MIN = 0;
  var BLUR_MAX = 20;

  var DEFAULTS = Object.freeze({
    enabled: false,
    size: 'M',
    opacity: 0.7,
    blurRadius: 0,
    isDarkMode: true
  });

  var MODE = 'rectangle';

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function toFiniteNumber(value) {
    if (typeof value === 'number') return Number.isFinite(value) ? value : null;
    if (typeof value === 'string' && value.trim() !== '') {
      var n = Number(value);
      return Number.isFinite(n) ? n : null;
    }
    return null;
  }

  function normalizeSettings(raw) {
    var src = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    var opacity = toFiniteNumber(src.opacity);
    var blur = toFiniteNumber(src.blurRadius);
    return {
      enabled: src.enabled === true,
      size: typeof src.size === 'string' && Object.prototype.hasOwnProperty.call(SIZES, src.size) ? src.size : DEFAULTS.size,
      opacity: opacity === null ? DEFAULTS.opacity : clamp(opacity, OPACITY_MIN, OPACITY_MAX),
      blurRadius: blur === null ? DEFAULTS.blurRadius : clamp(blur, BLUR_MIN, BLUR_MAX),
      isDarkMode: typeof src.isDarkMode === 'boolean' ? src.isDarkMode : DEFAULTS.isDarkMode
    };
  }

  function bandHeight(size) {
    var multiplier = Object.prototype.hasOwnProperty.call(SIZES, size) ? SIZES[size] : SIZES[DEFAULTS.size];
    return BASE_BAND_HEIGHT * multiplier;
  }

  // Each panel is a full-viewport-height element moved with translateY. The top panel is anchored
  // just above the viewport (bottom: 100%) and the bottom panel at the top (top: 0), so neither offset
  // depends on viewport height: top panel's bottom edge lands at y - h/2, bottom panel's top edge at y + h/2.
  // Like the macOS RectangleShape, the band is not clamped to the viewport.
  function panelOffsets(y, h) {
    return { topTranslate: y - h / 2, bottomTranslate: y + h / 2 };
  }

  function dimColor(isDarkMode, opacity) {
    var channel = isDarkMode ? 0 : 255;
    return 'rgba(' + channel + ', ' + channel + ', ' + channel + ', ' + opacity + ')';
  }

  function blurFilter(radius) {
    return radius > 0 ? 'blur(' + radius + 'px)' : 'none';
  }

  var RESTRICTED_PREFIXES = [
    'chrome://', 'chrome-extension://', 'chrome-untrusted://', 'chrome-search://',
    'edge://', 'about:', 'view-source:', 'devtools://', 'data:', 'javascript:', 'blob:'
  ];
  var RESTRICTED_HOSTS = [
    { host: 'chromewebstore.google.com', path: '' },
    { host: 'chrome.google.com', path: '/webstore' }
  ];

  function isRestrictedUrl(url, fileAccessAllowed) {
    if (typeof url !== 'string' || url === '') return true;
    var lower = url.toLowerCase();
    for (var i = 0; i < RESTRICTED_PREFIXES.length; i++) {
      if (lower.indexOf(RESTRICTED_PREFIXES[i]) === 0) return true;
    }
    if (lower.indexOf('file://') === 0) return fileAccessAllowed !== true;
    var parsed;
    try { parsed = new URL(url); } catch (e) { return true; }
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return true;
    for (var j = 0; j < RESTRICTED_HOSTS.length; j++) {
      var rule = RESTRICTED_HOSTS[j];
      if (parsed.hostname === rule.host && parsed.pathname.indexOf(rule.path) === 0) return true;
    }
    return false;
  }

  // ---- Analytics ----

  function secondsBetween(startMs, nowMs) {
    if (typeof startMs !== 'number' || !Number.isFinite(startMs)) return undefined;
    return Math.max(0, Math.round((nowMs - startMs) / 1000));
  }

  function withDuration(props, key, seconds) {
    if (seconds !== undefined) props[key] = seconds;
    return props;
  }

  // Returns { events: [{event, properties}], timestamps: {viewShownAt, modeShownAt} }.
  // Only enable/disable and size changes are tracked; opacity/blur/color are not (matches macOS).
  function analyticsEventsFor(oldRaw, newRaw, timestamps, now) {
    var prev = normalizeSettings(oldRaw);
    var next = normalizeSettings(newRaw);
    var ts = {
      viewShownAt: timestamps && timestamps.viewShownAt,
      modeShownAt: timestamps && timestamps.modeShownAt
    };
    var events = [];

    if (!prev.enabled && next.enabled) {
      events.push({ event: 'pace_view_shown', properties: {} });
      events.push({ event: 'mode_activated', properties: { mode: MODE, size: next.size } });
      ts.viewShownAt = now;
      ts.modeShownAt = now;
    } else if (prev.enabled && !next.enabled) {
      events.push({
        event: 'pace_view_hidden',
        properties: withDuration({}, 'view_duration_seconds', secondsBetween(ts.viewShownAt, now))
      });
      events.push({
        event: 'mode_deactivated',
        properties: withDuration({ mode: MODE, size: prev.size }, 'duration_seconds', secondsBetween(ts.modeShownAt, now))
      });
      ts.viewShownAt = undefined;
      ts.modeShownAt = undefined;
    } else if (prev.enabled && next.enabled && prev.size !== next.size) {
      events.push({
        event: 'mode_deactivated',
        properties: withDuration({ mode: MODE, size: prev.size }, 'duration_seconds', secondsBetween(ts.modeShownAt, now))
      });
      events.push({ event: 'mode_activated', properties: { mode: MODE, size: next.size } });
      ts.modeShownAt = now;
    }

    return { events: events, timestamps: ts };
  }

  var FORBIDDEN_PROPERTY_KEYS = ['url', 'title', '$current_url', '$pathname', '$host', 'href', 'page_title'];

  function buildCapturePayload(opts) {
    var properties = {};
    var extra = opts.properties || {};
    Object.keys(extra).forEach(function (key) {
      if (FORBIDDEN_PROPERTY_KEYS.indexOf(key) === -1) properties[key] = extra[key];
    });
    properties.platform = 'chrome_extension';
    properties.browser = 'chrome';
    properties.extension_version = opts.extensionVersion;
    properties.$lib = 'pace-chrome-extension';
    return {
      api_key: opts.apiKey,
      event: opts.event,
      distinct_id: opts.distinctId,
      properties: properties,
      timestamp: new Date(opts.now).toISOString()
    };
  }

  function validAnalyticsConfig(config) {
    if (!config || typeof config !== 'object') return null;
    var key = typeof config.posthogApiKey === 'string' ? config.posthogApiKey.trim() : '';
    if (!key) return null;
    var hostRaw = typeof config.posthogHost === 'string' && config.posthogHost.trim()
      ? config.posthogHost.trim() : 'https://us.i.posthog.com';
    var host;
    try { host = new URL(hostRaw); } catch (e) { return null; }
    if (host.protocol !== 'https:') return null;
    return { apiKey: key, endpoint: host.origin + '/i/v0/e/' };
  }

  var PaceCore = {
    SETTINGS_KEY: SETTINGS_KEY,
    DEFAULTS: DEFAULTS,
    MODE: MODE,
    normalizeSettings: normalizeSettings,
    bandHeight: bandHeight,
    panelOffsets: panelOffsets,
    dimColor: dimColor,
    blurFilter: blurFilter,
    isRestrictedUrl: isRestrictedUrl,
    analyticsEventsFor: analyticsEventsFor,
    buildCapturePayload: buildCapturePayload,
    validAnalyticsConfig: validAnalyticsConfig
  };

  root.PaceCore = PaceCore;
  if (typeof module !== 'undefined' && module.exports) module.exports = PaceCore;
})(typeof globalThis !== 'undefined' ? globalThis : this);
