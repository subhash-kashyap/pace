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
      return !!(globalThis.chrome && chrome.runtime && chrome.runtime.id);
    } catch (e) {
      return false;
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
    applyPosition();
  }

  function mount() {
    if (host && host.isConnected) return;
    // Replace any host left behind by an orphaned script (extension update/reload).
    var stale = document.querySelectorAll(HOST_TAG);
    for (var i = 0; i < stale.length; i++) stale[i].remove();

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

    (document.documentElement || document.body).appendChild(host);
    window.addEventListener('mousemove', onMouseMove, { capture: true, passive: true });
    window.addEventListener('resize', onResize, { passive: true });
    applyStyle();
  }

  function unmount() {
    window.removeEventListener('mousemove', onMouseMove, { capture: true });
    window.removeEventListener('resize', onResize);
    if (rafId) cancelAnimationFrame(rafId);
    rafId = 0;
    if (host) host.remove();
    host = null;
    panels = null;
  }

  function teardown() {
    dead = true;
    unmount();
    try { chrome.storage.onChanged.removeListener(onStorageChanged); } catch (e) { /* context gone */ }
    try { chrome.runtime.onMessage.removeListener(onMessage); } catch (e) { /* context gone */ }
  }

  function render(next) {
    settings = Core.normalizeSettings(next);
    if (dead) return;
    if (settings.enabled) {
      if (!host || !host.isConnected) {
        host = null;
        mount();
      } else {
        applyStyle();
      }
    } else {
      unmount();
    }
  }

  function onStorageChanged(changes, area) {
    if (area !== 'local' || !changes[Core.SETTINGS_KEY]) return;
    if (!contextAlive()) return teardown();
    render(changes[Core.SETTINGS_KEY].newValue);
  }

  function onMessage(message, sender, sendResponse) {
    if (message && message.type === 'pace_ping') {
      sendResponse({ mounted: !!(host && host.isConnected), enabled: settings.enabled });
    }
  }

  globalThis.__paceContent = { alive: function () { return !dead && contextAlive(); } };

  try {
    chrome.storage.onChanged.addListener(onStorageChanged);
    chrome.runtime.onMessage.addListener(onMessage);
    chrome.storage.local.get(Core.SETTINGS_KEY).then(function (result) {
      render(result[Core.SETTINGS_KEY]);
    }, function () {
      render(null);
    });
  } catch (e) {
    teardown();
  }
})();
