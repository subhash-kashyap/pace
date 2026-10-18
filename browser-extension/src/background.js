// Pace service worker: installs defaults, re-injects into open tabs, and sends analytics.
/* global importScripts, PaceCore */
importScripts('core.js');

(function (root) {
  'use strict';

  var Core = root.PaceCore;
  var ANALYTICS_ID_KEY = 'paceAnalyticsId';
  var ANALYTICS_ENABLED_KEY = 'analyticsEnabled';
  var TIMESTAMPS_KEY = 'paceAnalyticsTimestamps';

  var configPromise = null;
  var queue = Promise.resolve();

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

  function getDistinctId() {
    return chrome.storage.local.get(ANALYTICS_ID_KEY).then(function (r) {
      if (r[ANALYTICS_ID_KEY]) return r[ANALYTICS_ID_KEY];
      var id = uuid();
      var update = {};
      update[ANALYTICS_ID_KEY] = id;
      return chrome.storage.local.set(update).then(function () { return id; });
    });
  }

  function send(events) {
    if (!events.length) return Promise.resolve();
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
        return fetch(config.endpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          keepalive: true
        }).catch(function () { /* analytics must never break the extension */ });
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

  function reinjectOpenTabs() {
    return chrome.tabs.query({}).then(function (tabs) {
      return Promise.all(tabs.map(function (tab) {
        if (!tab.id || Core.isRestrictedUrl(tab.url, false)) return null;
        return chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ['src/core.js', 'src/content.js']
        }).catch(function () { /* tab may be discarded, restricted or closed */ });
      }));
    }).catch(function () { /* ignore */ });
  }

  function onInstalled(details) {
    return enqueue(function () {
      return chrome.storage.local.get(Core.SETTINGS_KEY).then(function (r) {
        // Only seed defaults; never rewrite existing settings (avoids clobbering a concurrent change).
        if (r[Core.SETTINGS_KEY] !== undefined) return;
        var update = {};
        update[Core.SETTINGS_KEY] = Core.normalizeSettings(null);
        return chrome.storage.local.set(update);
      })
        .then(getDistinctId)
        .then(function () {
          if (details && (details.reason === 'install' || details.reason === 'update')) return reinjectOpenTabs();
        })
        .then(function () {
          if (details && details.reason === 'install') {
            return send([{ event: 'app_opened', properties: { is_new_user: true } }]);
          }
        });
    });
  }

  function onStartup() {
    return enqueue(function () {
      return chrome.storage.local.get(Core.SETTINGS_KEY).then(function (r) {
        var settings = Core.normalizeSettings(r[Core.SETTINGS_KEY]);
        var events = [{ event: 'app_opened', properties: { is_new_user: false } }];
        var t = now();
        if (!settings.enabled) return send(events);
        events.push({ event: 'pace_view_shown', properties: {} });
        events.push({ event: 'mode_activated', properties: { mode: Core.MODE, size: settings.size } });
        return writeTimestamps({ viewShownAt: t, modeShownAt: t }).then(function () { return send(events); });
      });
    });
  }

  function onStorageChanged(changes, area) {
    if (area !== 'local' || !changes[Core.SETTINGS_KEY]) return;
    var change = changes[Core.SETTINGS_KEY];
    return enqueue(function () {
      return readTimestamps().then(function (ts) {
        var result = Core.analyticsEventsFor(change.oldValue, change.newValue, ts, now());
        if (!result.events.length) return;
        return writeTimestamps(result.timestamps).then(function () { return send(result.events); });
      });
    });
  }

  function onMessage(message, sender) {
    if (!message || message.type !== 'popup_opened') return;
    if (!sender || sender.id !== chrome.runtime.id || sender.tab) return;
    enqueue(function () { return send([{ event: 'popup_opened', properties: {} }]); });
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
    idle: function () { return queue; },
    resetConfigCache: function () { configPromise = null; }
  };
})(typeof globalThis !== 'undefined' ? globalThis : self);
