// Pace service worker: installs defaults, re-injects into open tabs, and sends analytics.
/* global importScripts, PaceCore */
importScripts('core.js');

(function (root) {
  'use strict';

  var Core = root.PaceCore;
  var ANALYTICS_ID_KEY = 'paceAnalyticsId';
  var ANALYTICS_ENABLED_KEY = 'analyticsEnabled';
  var TIMESTAMPS_KEY = 'paceAnalyticsTimestamps';

  var CAPTURE_TIMEOUT_MS = 5000;

  var configPromise = null;
  var distinctIdPromise = null;
  var queue = Promise.resolve();
  // In-flight analytics sends. Network work runs outside the queue so a stalled
  // request never delays later bookkeeping; tracked so tests can await it.
  var pendingSends = new Set();

  function noop() {}

  // Serialize async handlers so rapid toggles don't interleave timestamp writes.
  function enqueue(task) {
    queue = queue.then(task, task).catch(function () { /* never break the chain */ });
    return queue;
  }

  function now() {
    return Date.now();
  }

  function loadConfig() {
    if (!configPromise) {
      configPromise = fetch(chrome.runtime.getURL('config.json'))
        .then(function (res) { return res.ok ? res.json() : null; })
        .then(Core.validAnalyticsConfig)
        .catch(function () { return null; });
    }
    return configPromise;
  }

  function uuid() {
    if (root.crypto && typeof root.crypto.randomUUID === 'function') return root.crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = (Math.random() * 16) | 0;
      return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
    });
  }

  // Memoized so concurrent (unqueued) sends can't each mint a different id.
  function getDistinctId() {
    if (!distinctIdPromise) {
      distinctIdPromise = chrome.storage.local.get(ANALYTICS_ID_KEY).then(function (r) {
        if (r[ANALYTICS_ID_KEY]) return r[ANALYTICS_ID_KEY];
        var id = uuid();
        var update = {};
        update[ANALYTICS_ID_KEY] = id;
        return chrome.storage.local.set(update).then(function () { return id; });
      });
      distinctIdPromise.catch(function () { distinctIdPromise = null; });
    }
    return distinctIdPromise;
  }

  // Abort a capture that hasn't completed in CAPTURE_TIMEOUT_MS.
  function timeoutSignal() {
    if (typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function') {
      return AbortSignal.timeout(CAPTURE_TIMEOUT_MS);
    }
    if (typeof AbortController === 'function') {
      var controller = new AbortController();
      setTimeout(function () { controller.abort(); }, CAPTURE_TIMEOUT_MS);
      return controller.signal;
    }
    return undefined;
  }

  // Fire-and-forget: callers inside the queue must NOT return this promise.
  function send(events) {
    if (!events.length) return Promise.resolve();
    var p = deliver(events);
    pendingSends.add(p);
    p.then(function () { pendingSends.delete(p); });
    return p;
  }

  function deliver(events) {
    return Promise.all([
      loadConfig(),
      chrome.storage.local.get(ANALYTICS_ENABLED_KEY),
      getDistinctId()
    ]).then(function (results) {
      var config = results[0];
      var optedOut = results[1][ANALYTICS_ENABLED_KEY] === false;
      var distinctId = results[2];
      if (!config || optedOut) return;
      var version = chrome.runtime.getManifest().version;
      return Promise.all(events.map(function (e) {
        var payload = Core.buildCapturePayload({
          apiKey: config.apiKey,
          event: e.event,
          distinctId: distinctId,
          properties: e.properties,
          extensionVersion: version,
          now: now()
        });
        var init = {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          keepalive: true
        };
        var signal = timeoutSignal();
        if (signal) init.signal = signal;
        return fetch(config.endpoint, init).catch(function () { /* analytics must never break the extension */ });
      }));
    }).catch(function () { /* swallow */ });
  }

  function readTimestamps() {
    return chrome.storage.local.get(TIMESTAMPS_KEY).then(function (r) {
      return r[TIMESTAMPS_KEY] || {};
    });
  }

  function writeTimestamps(ts) {
    var update = {};
    update[TIMESTAMPS_KEY] = { viewShownAt: ts.viewShownAt, modeShownAt: ts.modeShownAt };
    return chrome.storage.local.set(update);
  }

  // Resolves true only when the user enabled "Allow access to file URLs".
  function fileSchemeAccessAllowed() {
    if (typeof chrome.extension === 'undefined' || typeof chrome.extension.isAllowedFileSchemeAccess !== 'function') {
      return Promise.resolve(false);
    }
    try {
      return Promise.resolve(chrome.extension.isAllowedFileSchemeAccess())
        .then(function (allowed) { return allowed === true; })
        .catch(function () { return false; });
    } catch (e) {
      return Promise.resolve(false);
    }
  }

  function reinjectOpenTabs() {
    return Promise.all([chrome.tabs.query({}), fileSchemeAccessAllowed()]).then(function (results) {
      var tabs = results[0];
      var fileAccess = results[1];
      return Promise.all(tabs.map(function (tab) {
        if (!tab.id || Core.isRestrictedUrl(tab.url, fileAccess)) return null;
        return chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ['src/core.js', 'src/content.js']
        }).catch(function () { /* tab may be discarded, restricted or closed */ });
      }));
    }).catch(function () { /* ignore */ });
  }

  function seedDefaults() {
    return chrome.storage.local.get(Core.SETTINGS_KEY).then(function (r) {
      // Only seed defaults; never rewrite existing settings (avoids clobbering a concurrent change).
      if (r[Core.SETTINGS_KEY] !== undefined) return;
      var update = {};
      update[Core.SETTINGS_KEY] = Core.normalizeSettings(null);
      return chrome.storage.local.set(update);
    });
  }

  // Each step catches its own failure so one broken step can't skip re-injection or app_opened.
  function onInstalled(details) {
    var reason = details && details.reason;
    return enqueue(function () {
      return seedDefaults().catch(noop)
        .then(function () { return getDistinctId(); }).catch(noop)
        .then(function () {
          if (reason === 'install' || reason === 'update') return reinjectOpenTabs();
        }).catch(noop)
        .then(function () {
          if (reason === 'install') send([{ event: 'app_opened', properties: { is_new_user: true } }]);
        });
    });
  }

  function onStartup() {
    return enqueue(function () {
      return chrome.storage.local.get(Core.SETTINGS_KEY).then(function (r) {
        var settings = Core.normalizeSettings(r[Core.SETTINGS_KEY]);
        var events = [{ event: 'app_opened', properties: { is_new_user: false } }];
        var t = now();
        if (!settings.enabled) {
          send(events);
          return;
        }
        events.push({ event: 'pace_view_shown', properties: {} });
        events.push({ event: 'mode_activated', properties: { mode: Core.MODE, size: settings.size } });
        return writeTimestamps({ viewShownAt: t, modeShownAt: t }).then(function () { send(events); });
      });
    });
  }

  function onStorageChanged(changes, area) {
    if (area !== 'local' || !changes[Core.SETTINGS_KEY]) return;
    var change = changes[Core.SETTINGS_KEY];
    // Slider/theme changes can't produce events; skip the queue and the storage read entirely.
    var prev = Core.normalizeSettings(change.oldValue);
    var next = Core.normalizeSettings(change.newValue);
    if (prev.enabled === next.enabled && prev.size === next.size) return;
    return enqueue(function () {
      return readTimestamps().then(function (ts) {
        var result = Core.analyticsEventsFor(change.oldValue, change.newValue, ts, now());
        if (!result.events.length) return;
        return writeTimestamps(result.timestamps).then(function () { send(result.events); });
      });
    });
  }

  function onMessage(message, sender) {
    if (!message || message.type !== 'popup_opened') return;
    if (!sender || sender.id !== chrome.runtime.id || sender.tab) return;
    enqueue(function () { send([{ event: 'popup_opened', properties: {} }]); });
  }

  chrome.runtime.onInstalled.addListener(onInstalled);
  chrome.runtime.onStartup.addListener(onStartup);
  chrome.storage.onChanged.addListener(onStorageChanged);
  chrome.runtime.onMessage.addListener(onMessage);

  // Exposed for tests (Node vm harness and e2e).
  root.__paceBackground = {
    onInstalled: onInstalled,
    onStartup: onStartup,
    onStorageChanged: onStorageChanged,
    onMessage: onMessage,
    idleQueue: function () { return queue; },
    // Resolves once the queue drains and every send it fired has settled.
    idle: function () {
      return queue.then(function () {
        var inFlight = [];
        pendingSends.forEach(function (p) { inFlight.push(p); });
        return Promise.all(inFlight);
      });
    },
    resetConfigCache: function () { configPromise = null; }
  };
})(typeof globalThis !== 'undefined' ? globalThis : self);
