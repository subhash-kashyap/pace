// Pace popup: reads and writes settings; content scripts and the worker react via storage.onChanged.
(function () {
  'use strict';

  var Core = globalThis.PaceCore;
  var KEY = Core.SETTINGS_KEY;
  // The preview is a ~1:8 miniature of the page, so the band shrinks with it.
  var PREVIEW_SCALE = 0.125;

  var settings = Core.normalizeSettings(null);
  var pendingWrite = 0;
  var loaded = false;
  var earlyPatch = null; // changes made before stored settings finished loading

  var els = {
    enabled: document.getElementById('enabled'),
    notice: document.getElementById('notice'),
    opacity: document.getElementById('opacity'),
    opacityValue: document.getElementById('opacity-value'),
    blur: document.getElementById('blur'),
    blurValue: document.getElementById('blur-value'),
    panel: document.querySelector('.panel'),
    preview: document.getElementById('preview'),
    groups: document.querySelectorAll('.segmented')
  };

  function render() {
    els.enabled.checked = settings.enabled;
    var opacityPct = Math.round(settings.opacity * 100);
    els.opacity.value = String(opacityPct);
    els.opacityValue.textContent = opacityPct + '%';
    els.blur.value = String(settings.blurRadius);
    els.blurValue.textContent = settings.blurRadius + 'px';
    // Filled portion of each slider track.
    els.opacity.style.setProperty('--fill', ((opacityPct - 10) / 90) * 100 + '%');
    els.blur.style.setProperty('--fill', (settings.blurRadius / 20) * 100 + '%');
    renderPreview();
    els.groups.forEach(function (group) {
      var current = String(settings[group.dataset.setting]);
      group.querySelectorAll('button').forEach(function (btn) {
        var on = btn.dataset.value === current;
        btn.setAttribute('aria-pressed', on ? 'true' : 'false');
        btn.tabIndex = on ? 0 : -1;
      });
    });
  }

  // Mirror the overlay in the miniature page so every control shows its effect.
  function renderPreview() {
    var style = els.panel.style;
    els.panel.classList.toggle('is-on', settings.enabled);
    style.setProperty('--dim', Core.dimColor(settings.isDarkMode, settings.opacity));
    style.setProperty('--dim-blur', Core.blurFilter(settings.blurRadius * PREVIEW_SCALE * 2));
    style.setProperty('--band', Core.bandHeight(settings.size) * PREVIEW_SCALE + 'px');
  }

  function write() {
    if (!loaded) return Promise.resolve();
    var update = {};
    update[KEY] = settings;
    // A failed write would leave the controls showing values that were never saved; resync from storage.
    return chrome.storage.local.set(update).catch(function () {
      return chrome.storage.local.get(KEY).then(function (r) {
        settings = Core.normalizeSettings(r[KEY]);
        render();
      });
    }).catch(function () {});
  }

  // Sliders write at most once per animation frame for a smooth live preview.
  function scheduleWrite() {
    if (pendingWrite) return;
    pendingWrite = requestAnimationFrame(function () {
      pendingWrite = 0;
      write();
    });
  }

  function flushWrite() {
    if (!pendingWrite) return;
    cancelAnimationFrame(pendingWrite);
    pendingWrite = 0;
    write();
  }

  // Like the macOS apply* methods: changing any setting turns the overlay on.
  function change(patch, throttled) {
    patch = Object.assign({}, patch);
    if (!Object.prototype.hasOwnProperty.call(patch, 'enabled')) patch.enabled = true;
    if (!loaded) earlyPatch = Object.assign(earlyPatch || {}, patch);
    var next = Object.assign({}, settings, patch);
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

  // Commit the final slider value immediately (rAF may never run if the popup closes).
  els.opacity.addEventListener('change', flushWrite);
  els.blur.addEventListener('change', flushWrite);
  window.addEventListener('pagehide', flushWrite);
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') flushWrite();
  });

  // Hovering the preview moves its band, like moving the mouse over a page.
  els.preview.addEventListener('pointermove', function (event) {
    var rect = els.preview.getBoundingClientRect();
    els.panel.style.setProperty('--band-y', (event.clientY - rect.top) + 'px');
  });
  els.preview.addEventListener('pointerleave', function () {
    els.panel.style.removeProperty('--band-y');
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
          if (!reply) return showNotice(noReply(tab.url, fileAccess));
          if (reply.unsupported) return showNotice(cantShow());
          showNotice(reply.enabled && !reply.mounted ? "Pace isn't showing here. Try reloading this tab." : '');
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

  function onLoaded(r) {
    settings = Core.normalizeSettings(Object.assign({}, r[KEY], earlyPatch));
    loaded = true;
    render();
    if (earlyPatch) write();
    earlyPatch = null;
  }

  // If the read fails, fall back to defaults so the controls still save instead of silently dropping writes.
  chrome.storage.local.get(KEY).then(onLoaded, function () { onLoaded({}); });

  render();
  checkActiveTab();
  try { chrome.runtime.sendMessage({ type: 'popup_opened' }).catch(function () {}); } catch (e) { /* ignore */ }

  globalThis.__pacePopup = { checkActiveTab: checkActiveTab };
})();
