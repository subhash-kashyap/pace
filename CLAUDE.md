# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Pace is a reading-focus overlay: everything on screen is dimmed except a "spotlight" that follows the mouse. The repo holds two independent products that share behavior and an analytics project, but no code:

- **macOS app** (`pace/`, Swift, SwiftUI + AppKit, Xcode project `pace.xcodeproj`). Menu-bar utility with four shapes (Rectangle, Center Column, Square, Circle), S/M/L sizes, dark/light, opacity, blur, global hotkeys, Sparkle auto-updates.
- **Chrome extension** (`browser-extension/`, MV3, plain JS, no build step). Rectangle mode only.

## Commands

### Chrome extension (run from `browser-extension/`)

```bash
npm install && npx playwright install chromium   # first time
npm test                                         # unit + e2e
npm run test:unit                                # node:test, test/unit/*.test.js
node --test test/unit/core.test.js               # one unit file
npm run test:e2e                                 # Playwright, headless bundled Chromium
npx playwright test test/e2e/overlay.spec.js     # one e2e file
npx playwright test -g "band keeps its on-screen height"   # one e2e test by name
npm run package                                  # runs all tests, writes dist/pace-chrome-<version>.zip
npm run store:assets                             # regenerates store/images/
```

Load for manual testing via `chrome://extensions` → Developer mode → Load unpacked → `browser-extension/`. Manual QA script: `test/QA_CHECKLIST.md`. Store publishing checklist: `PUBLISHING.md`.

### macOS app (run from repo root)

```bash
./scripts/run.sh             # xcodebuild Debug into ./build, kill old instance, run with logs in terminal
./scripts/build_release.sh   # release zip into releases/
./scripts/create_release.sh  # signed Sparkle release; appcast.xml is the update feed
```

Or open `pace.xcodeproj` in Xcode (scheme `pace`). Tests in `paceTests/` and `paceUITests/` are Xcode template stubs.

## Chrome extension architecture

- **`src/core.js` is the only place for logic.** It's a classic script (no modules, no bundler) that attaches `globalThis.PaceCore` and also `module.exports`, so the same file loads in the content script, popup, service worker (`importScripts`) and Node tests. Settings normalization, band geometry, colors, restricted-URL rules and the analytics transition function (`analyticsEventsFor`) live here and are unit tested. Keep it pure.
- **Settings in `chrome.storage.local` under `paceSettings` are the single source of truth.** The popup only writes storage; content scripts and the service worker react through `storage.onChanged`. There is no popup→content messaging for settings. Changing any setting also sets `enabled: true` (mirrors the Mac app).
- **Messages that do exist:** `pace_ping` (popup → content, reports mounted/pdf/unsupported for the notice), `popup_opened` (popup → worker, analytics), `pace_get_zoom` (content → worker; content scripts can't call `chrome.tabs.getZoom`) and `pace_zoom` (worker → content on `tabs.onZoomChange`). Band height and blur are divided by the tab's zoom so the spotlight keeps its on-screen size.
- **Content script (`src/content.js`)** draws two full-viewport panels inside an open shadow root on a `<pace-focus-overlay>` host, moved with `translate3d` on `requestAnimationFrame`. It must survive hostile pages and extension reloads: it re-attaches the host if a page removes it, tears itself down when `chrome.runtime.id` disappears (orphaned after an update), removes stale hosts left by orphans, and refuses to run twice in one world (`globalThis.__paceContent`). It doesn't mount on non-HTML documents or PDFs.
- **Async races are guarded with counters, not flags.** `changeCount` (settings reads), `zoomPushes` (zoom lookups) and `checkCount` (popup tab checks) all let an older async result be dropped when a newer one has landed. Follow the same pattern for new async state.
- **Service worker (`src/background.js`)** seeds defaults without overwriting existing settings, re-injects `core.js` + `content.js` into already-open tabs on install/update, and sends analytics through a serialized promise queue. It exposes `globalThis.__paceBackground` for tests.
- **Analytics is opt-in at build time.** It's active only when a gitignored `config.json` (copied from `config.example.json`) holds a real PostHog project key (`phc_…`). `package.sh` refuses the placeholder key. `buildCapturePayload` strips URL and title fields; `PRIVACY.md` promises that, so don't add page data to events.

### Tests

- Unit tests load `background.js` in a `node:vm` sandbox with a fake `chrome` (`test/unit/background.test.js`'s `createHarness`). Objects coming out of the sandbox are from another realm, so `assert.deepEqual` against them fails; compare a `JSON.parse(JSON.stringify(...))` copy.
- E2E tests launch Playwright's bundled Chromium with the unpacked extension (branded Chrome ignores `--load-extension`). Fixture pages are served from `https://pace.test/*` via request routing (`test/helpers/fixtures.js`); no server needed. Use `settledOverlay(page, predicate)` to wait for panel transitions to finish before asserting geometry.

## macOS app architecture

- **`pace/paceApp.swift` holds most of the app**: the `GlobalHotkeyManager` (Carbon `RegisterEventHotKey`, ⌃⌥ + O/P/K/L/S, no accessibility permission), `AppDelegate` (menu bar, window lifecycle, all `apply*`/`cycle*` actions), and the three windows: `OverlayWindow` (`.screenSaver` level, ignores mouse), `SidePanelWindow` (max window level, right-edge panel mirroring the menu), and `OnboardingWindow`.
- **`FocusShape.swift`**: `FocusMode`, `FocusSize` (multipliers 1 / 1.5 / 2.25 on a 200px base, the same numbers the extension uses), shape mask paths, and `FocusConfiguration.current`, which persists to UserDefaults and migrates the legacy `PaceBackgroundStyle` and `"small"`/`"big"` mode values inside its getter.
- **`ContentView.swift`**: the overlay view masks a dim layer with the focus shape. `GlobalMouseTracker` polls `NSEvent.mouseLocation` at 60 Hz instead of using a global event monitor, again to avoid the accessibility permission.
- **Overlay visibility is implicit state.** `overlayWindow.isVisible`, `overlayShownTime`, the menu checkmark and the status icon are updated by hand in many `AppDelegate` methods, and the copies have drifted (some show the overlay without analytics timestamps). Change them together.
- **Secrets**: `Config.swift` reads `POSTHOG_API_KEY` / `POSTHOG_HOST` from Info.plist (xcconfig) or a bundled `Config.plist`. Every Mac event is tagged `platform: macos`, extension events `platform: chrome_extension`, in the same PostHog project.

## Gotchas

- When writing Swift through a shell heredoc, quote the delimiter (`<<'EOF'`). An unquoted one expanded `$0` to `zsh` in `paceApp.swift` once and broke the build.
- Keep the extension `version` identical in `manifest.json` and `package.json`; `package.sh` checks, and the Web Store rejects a re-used version.
- Deeper Mac app docs: `docs/CODEBASE_DOC.md`. Extension design plan: `docs/plans/`. Analytics events: `docs/analytics/README.md`.
