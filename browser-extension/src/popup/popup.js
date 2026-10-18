// Pace popup: reads and writes settings; content scripts and the worker react via storage.onChanged.
(function () {
  'use strict';

  var Core = globalThis.PaceCore;
  var KEY = Core.SETTINGS_KEY;
  var ANALYTICS_ENABLED_KEY = 'analyticsEnabled';

  var settings = Core.normalizeSettings(null);
  var pendingWrite = 0;

  var els = {
    enabled: document.getElementById('enabled'),
    notice: document.getElementById('notice'),
    opacity: document.getElementById('opacity'),
    opacityValue: document.getElementById('opacity-value'),
    blur: document.getElementById('blur'),
    blurValue: document.getElementById('blur-value'),
    analytics: document.getElementById('analytics'),
    groups: document.querySelectorAll('.segmented')
  };

  function render() {
    els.enabled.checked = settings.enabled;
    var opacityPct = Math.round(settings.opacity * 100);
    els.opacity.value = String(opacityPct);
    els.opacityValue.textContent = opacityPct + '%';
    els.blur.value = String(settings.blurRadius);
    els.blurValue.textContent = settings.blurRadius + 'px';
    els.groups.forEach(function (group) {
      var current = String(settings[group.dataset.setting]);
      group.querySelectorAll('button').forEach(function (btn) {
        var on = btn.dataset.value === current;
        btn.setAttribute('aria-pressed', on ? 'true' : 'false');
        btn.tabIndex = on ? 0 : -1;
      });
    });
  }

  function write() {
    var update = {};
    update[KEY] = settings;
    return chrome.storage.local.set(update);
  }

  // Sliders write at most once per animation frame for a smooth live preview.
  function scheduleWrite() {
    if (pendingWrite) return;
    pendingWrite = requestAnimationFrame(function () {
      pendingWrite = 0;
      write();
    });
  }

  // Like the macOS apply* methods: changing any setting turns the overlay on.
  function change(patch, throttled) {
    var next = Object.assign({}, settings, patch);
    if (!Object.prototype.hasOwnProperty.call(patch, 'enabled')) next.enabled = true;
    settings = Core.normalizeSettings(next);
    render();
    return throttled ? scheduleWrite() : write();
  }

  function parseValue(setting, raw) {
    if (setting === 'isDarkMode') return raw === 'true';
    return raw;
  }

  els.enabled.addEventListener('change', function () {
    change({ enabled: els.enabled.checked });
  });

  els.opacity.addEventListener('input', function () {
    change({ opacity: Number(els.opacity.value) / 100 }, true);
  });

  els.blur.addEventListener('input', function () {
    change({ blurRadius: Number(els.blur.value) }, true);
  });

  els.analytics.addEventListener('change', function () {
    var update = {};
    update[ANALYTICS_ENABLED_KEY] = els.analytics.checked;
    chrome.storage.local.set(update);
  });

  els.groups.forEach(function (group) {
    var setting = group.dataset.setting;
    var buttons = Array.prototype.slice.call(group.querySelectorAll('button'));
    buttons.forEach(function (btn, index) {
      btn.addEventListener('click', function () {
        var patch = {};
        patch[setting] = parseValue(setting, btn.dataset.value);
        change(patch);
      });
      btn.addEventListener('keydown', function (event) {
        var delta = event.key === 'ArrowRight' || event.key === 'ArrowDown' ? 1
          : event.key === 'ArrowLeft' || event.key === 'ArrowUp' ? -1 : 0;
        if (!delta) return;
        event.preventDefault();
        var target = buttons[(index + delta + buttons.length) % buttons.length];
        target.focus();
        target.click();
      });
    });
  });

  function showNotice(text) {
    els.notice.textContent = text || '';
    els.notice.hidden = !text;
  }

  function checkActiveTab() {
    return chrome.tabs.query({ active: true, currentWindow: true }).then(function (tabs) {
      var tab = tabs[0];
      if (!tab || tab.id === undefined) return showNotice(cantShow());
      return Promise.resolve(chrome.extension.isAllowedFileSchemeAccess()).then(function (fileAccess) {
        return chrome.tabs.sendMessage(tab.id, { type: 'pace_ping' }).then(function (reply) {
          showNotice(reply ? '' : noReply(tab.url, fileAccess));
        }, function () {
          showNotice(noReply(tab.url, fileAccess));
        });
      });
    }).catch(function () { showNotice(''); });
  }

  function cantShow() {
    return "Pace can't show on this page. Your settings still apply to other tabs.";
  }

  function noReply(url, fileAccess) {
    return Core.isRestrictedUrl(url, fileAccess) ? cantShow() : 'Reload this tab to use Pace here.';
  }

  chrome.storage.local.get([KEY, ANALYTICS_ENABLED_KEY]).then(function (r) {
    settings = Core.normalizeSettings(r[KEY]);
    els.analytics.checked = r[ANALYTICS_ENABLED_KEY] !== false;
    render();
  });

  render();
  checkActiveTab();
  try { chrome.runtime.sendMessage({ type: 'popup_opened' }).catch(function () {}); } catch (e) { /* ignore */ }

  globalThis.__pacePopup = { checkActiveTab: checkActiveTab };
})();
