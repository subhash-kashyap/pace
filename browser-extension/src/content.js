// Pace content script: renders the rectangle focus overlay on the page.
(function () {
  'use strict';

  var Core = globalThis.PaceCore;
  // A live instance already runs in this world (e.g. manifest injection raced with re-injection).
  if (globalThis.__paceContent && globalThis.__paceContent.alive()) return;
  var HOST_TAG = 'pace-focus-overlay';
  var MOVE_THRESHOLD = 0.5; // px, same as GlobalMouseTracker on macOS

  var settings = Core.normalizeSettings(null);
  var host = null;
  var panels = null;
  var mouseY = null;
  var pendingY = null;
  var rafId = 0;
  var dead = false;
  var changeCount = 0; // bumped per settings change so a slower storage read can't overwrite a newer render
  // Captured once: an orphaned instance keeps its own (now invalid) runtime even if the world is reused.
  var runtime = null;
  try { runtime = chrome.runtime; } catch (e) { /* no extension context */ }

  var STYLE = [
    ':host { all: initial; }',
    '.panel {',
    '  position: absolute; left: 0; width: 100%; height: 100%;',
    '  pointer-events: none; will-change: transform;',
    '  background: var(--pace-color);',
    '  -webkit-backdrop-filter: var(--pace-blur); backdrop-filter: var(--pace-blur);',
    '  transition: transform 120ms ease-out, background-color 300ms ease-out,',
    '    backdrop-filter 300ms ease-out, -webkit-backdrop-filter 300ms ease-out;',
    '}',
    '.top { bottom: 100%; }',
    '.bottom { top: 0; }',
    '@media (prefers-reduced-motion: reduce) { .panel { transition: none !important; } }',
    '@media print { .panel { display: none !important; } }'
  ].join('\n');

  var HOST_STYLE = [
    'all: initial !important',
    'position: fixed !important',
    'inset: 0 !important',
    'width: 100vw !important',
    'height: 100vh !important',
    'pointer-events: none !important',
    'z-index: 2147483647 !important',
    'display: block !important',
    'contain: strict !important'
  ].join('; ');

  function contextAlive() {
    try {
      return !!(runtime && runtime.id);
    } catch (e) {
      return false;
    }
  }

  // Only HTML documents can host the overlay (not SVG/XML).
  function unsupportedDocument() {
    var root = document.documentElement;
    return !root || root.namespaceURI !== 'http://www.w3.org/1999/xhtml';
  }

  // Chrome's PDF viewer swallows mouse events, so on PDFs the band stays at a fixed reading
  // position (viewport center) and the text is scrolled through it.
  function isPdf() {
    return document.contentType === 'application/pdf';
  }

  function removeAllHosts() {
    var hosts = document.querySelectorAll(HOST_TAG);
    for (var i = 0; i < hosts.length; i++) hosts[i].remove();
  }

  // Page scripts (hydration fallbacks, replaceChildren, document.write) can drop our host; put it back.
  function ensureAttached() {
    if (settings.enabled && host && !host.isConnected && document.documentElement) {
      document.documentElement.appendChild(host);
    }
  }

  function viewportHeight() {
    return window.innerHeight || document.documentElement.clientHeight || 0;
  }

  function applyStyle() {
    if (!host) return;
    host.style.setProperty('--pace-color', Core.dimColor(settings.isDarkMode, settings.opacity));
    host.style.setProperty('--pace-blur', Core.blurFilter(settings.blurRadius));
    applyPosition();
  }

  function applyPosition() {
    if (!panels) return;
    if (mouseY === null) mouseY = viewportHeight() / 2;
    var o = Core.panelOffsets(mouseY, Core.bandHeight(settings.size));
    panels.top.style.transform = 'translate3d(0,' + o.topTranslate + 'px,0)';
    panels.bottom.style.transform = 'translate3d(0,' + o.bottomTranslate + 'px,0)';
  }

  function frame() {
    rafId = 0;
    if (!contextAlive()) return teardown();
    ensureAttached();
    if (pendingY === null) return;
    if (mouseY !== null && Math.abs(pendingY - mouseY) < MOVE_THRESHOLD) return;
    mouseY = pendingY;
    applyPosition();
  }

  function onMouseMove(event) {
    pendingY = event.clientY;
    if (!rafId) rafId = requestAnimationFrame(frame);
  }

  function onResize() {
    if (!contextAlive()) return teardown();
    ensureAttached();
    applyPosition();
  }

  function refresh() {
    if (!contextAlive()) return teardown();
    var seen = changeCount;
    chrome.storage.local.get(Core.SETTINGS_KEY).then(function (r) {
      if (changeCount === seen) render(r[Core.SETTINGS_KEY]);
    }, function () {});
  }

  // bfcache restores can miss storage events while frozen; re-read settings.
  function onPageShow(event) {
    if (!contextAlive()) return teardown();
    ensureAttached();
    if (event.persisted) refresh();
  }

  function onVisibilityChange() {
    if (document.visibilityState !== 'visible') return;
    if (!contextAlive()) return teardown();
    ensureAttached();
  }

  function mount() {
    if (host && host.isConnected) return;
    if (unsupportedDocument()) return;
    var root = document.documentElement;
    // Replace any host left behind by an orphaned script (extension update/reload).
    removeAllHosts();

    host = document.createElement(HOST_TAG);
    host.setAttribute('aria-hidden', 'true');
    host.setAttribute('style', HOST_STYLE);
    var shadow = host.attachShadow({ mode: 'open' });
    var style = document.createElement('style');
    style.textContent = STYLE;
    var top = document.createElement('div');
    top.className = 'panel top';
    top.setAttribute('part', 'top');
    var bottom = document.createElement('div');
    bottom.className = 'panel bottom';
    bottom.setAttribute('part', 'bottom');
    shadow.append(style, top, bottom);
    panels = { top: top, bottom: bottom };

    root.appendChild(host);
    window.addEventListener('mousemove', onMouseMove, { capture: true, passive: true });
    window.addEventListener('resize', onResize, { passive: true });
    applyStyle();
  }

  function unmount() {
    window.removeEventListener('mousemove', onMouseMove, { capture: true });
    window.removeEventListener('resize', onResize);
    if (rafId) cancelAnimationFrame(rafId);
    rafId = 0;
    // Only our own host: an orphan tearing down must not remove a re-injected live instance's overlay.
    if (host) host.remove();
    host = null;
    panels = null;
  }

  function teardown() {
    dead = true;
    unmount();
    window.removeEventListener('pageshow', onPageShow);
    document.removeEventListener('visibilitychange', onVisibilityChange);
    try { chrome.storage.onChanged.removeListener(onStorageChanged); } catch (e) { /* context gone */ }
    try { chrome.runtime.onMessage.removeListener(onMessage); } catch (e) { /* context gone */ }
  }

  function render(next) {
    settings = Core.normalizeSettings(next);
    if (dead) return;
    if (settings.enabled) {
      if (!host || !host.isConnected) {
        host = null;
        try { mount(); } catch (e) { unmount(); }
      } else {
        applyStyle();
      }
    } else {
      unmount();
      removeAllHosts(); // also clears a stale host from an orphaned instance
    }
  }

  function onStorageChanged(changes, area) {
    if (area !== 'local' || !changes[Core.SETTINGS_KEY]) return;
    if (!contextAlive()) return teardown();
    changeCount++;
    render(changes[Core.SETTINGS_KEY].newValue);
  }

  function onMessage(message, sender, sendResponse) {
    if (message && message.type === 'pace_ping') {
      sendResponse({ mounted: !!(host && host.isConnected), enabled: settings.enabled, unsupported: unsupportedDocument(), pdf: isPdf() });
    }
  }

  globalThis.__paceContent = { alive: function () { return !dead && contextAlive(); } };

  try {
    removeAllHosts(); // a fresh instance never inherits an orphan's overlay
    chrome.storage.onChanged.addListener(onStorageChanged);
    chrome.runtime.onMessage.addListener(onMessage);
    window.addEventListener('pageshow', onPageShow);
    document.addEventListener('visibilitychange', onVisibilityChange);
    var seen = changeCount;
    chrome.storage.local.get(Core.SETTINGS_KEY).then(function (result) {
      if (changeCount === seen) render(result[Core.SETTINGS_KEY]);
    }, function () {
      if (changeCount === seen) render(null);
    });
  } catch (e) {
    teardown();
  }
})();
