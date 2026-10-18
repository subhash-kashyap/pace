# Pace for Chrome

A lightweight Manifest V3 extension that brings Pace's **Rectangle** reading-focus mode to the browser. The page is dimmed except for a full-width band that follows your mouse vertically.

- **Sizes:** S / M / L, giving a 200 / 300 / 450px band (same 1× / 1.5× / 2.25× multipliers as the Mac app)
- **Color:** dark or light dimming
- **Opacity:** 10–100%
- **Blur:** 0–20px (frosted dim area)
- **Global on/off:** applies to every tab, live, and persists across restarts

No build step and no runtime dependencies. The extension is plain JS, HTML and CSS. `node_modules` exists only for the tests.

## Load it in Chrome

1. Open `chrome://extensions` and turn on **Developer mode**.
2. Click **Load unpacked** and choose this `browser-extension/` folder.
3. Pin Pace from the puzzle-piece menu and click its icon to open the popup.

Any change to a setting in the popup also turns the overlay on, just like the Mac app.

## Analytics (optional)

Events go to the same PostHog project as the Mac app. Every event carries `platform: "chrome_extension"`; Mac events carry `platform: "macos"`.

```bash
cp config.example.json config.json   # gitignored
# then set "posthogApiKey" to the PostHog *project* key (phc_...), never a personal API key
```

If `config.json` is missing, its key is empty, or the host isn't `https`, analytics stays off. Users can switch it off in the popup ("Share anonymous usage"). URLs, page titles and page content are never sent. See `docs/analytics/README.md` for the event list.

## Tests

```bash
npm install
npx playwright install chromium   # first time only
npm test                          # unit (node:test) + e2e (Playwright, headless Chromium)
npm run test:unit
npm run test:e2e
```

The e2e tests load the unpacked extension into Playwright's bundled Chromium (branded Chrome ignores `--load-extension`). Fixture pages are served from `https://pace.test/*` via request routing, so no server is needed. `test/QA_CHECKLIST.md` is the manual script for a run in real Chrome.

## Layout

| Path | Role |
|---|---|
| `src/core.js` | Pure shared logic: settings, geometry, colors, URL checks, analytics diffing. Unit tested. |
| `src/content.js` | Overlay: two panels in a shadow root, moved with `transform` on `requestAnimationFrame` |
| `src/background.js` | Service worker: default settings, re-injection into open tabs, analytics |
| `src/popup/` | Popup UI |

## Permissions

- `storage`: settings.
- `scripting` + `<all_urls>`: the overlay has to appear on every page as soon as you turn it on, including tabs that were already open when the extension was installed or updated. The content script only reads mouse position and its own settings; it never reads page content.

## Known limitations

- Doesn't run on `chrome://` pages, the Chrome Web Store, or other extensions' pages. The popup says so.
- `file://` pages need **Allow access to file URLs** turned on in the extension's details.
- The band only follows the mouse in the top-level page. Over iframes (embeds, some editors) it pauses until the cursor leaves them. Chrome's built-in PDF viewer isn't supported.
- Fullscreen video and page `<dialog>`/popover top-layer elements render above the overlay.
- Large blur values over heavy pages can cost scroll smoothness. Blur defaults to 0.
