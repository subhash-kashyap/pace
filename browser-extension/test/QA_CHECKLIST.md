# Pace for Chrome — manual QA checklist

Run this in **real Google Chrome** with the unpacked extension loaded (see `../README.md`). Record pass/fail and notes for each step.

## Setup
- [ ] Before loading, open 2–3 tabs on regular sites (e.g. a Wikipedia article, a news site).
- [ ] Load unpacked `browser-extension/`. No errors appear on `chrome://extensions`; the service worker shows as active.

## Core overlay
- [ ] Open the popup and turn on **Focus overlay**. The overlay appears in the **already-open tabs without reloading them**.
- [ ] On a long article, the band follows the mouse up and down smoothly and stays full width; moving left and right doesn't move it.
- [ ] Sizes S / M / L visibly change the band height (about 200 / 300 / 450px).
- [ ] Dark and Light both work; opacity at 10% and 100% looks right.
- [ ] Blur at 0, 10 and 20: text in the dim area is frosted. Scrolling stays smooth (note any jank).
- [ ] Links in the dim area are clickable, text selection works through the dim area, and typing in inputs works.
- [ ] Open a new tab to another site: the overlay is already on there.
- [ ] Turn the switch off: the overlay disappears in all tabs.
- [ ] Quit and reopen Chrome with Pace on: the overlay is back on regular pages.

## Edge cases
- [ ] `chrome://extensions` → popup notice reads "Pace can't show on this page. Your settings still apply to other tabs."
- [ ] A `file://` HTML page with file access off → the same notice.
- [ ] A YouTube embed or other cross-origin iframe page: note how the band behaves over the iframe (expected: it pauses).
- [ ] A same-origin iframe page: note the behavior.
- [ ] A PDF opened in Chrome's viewer: note the behavior (expected: no overlay, and the popup shows the "can't show on this page" notice).
- [ ] Fullscreen a video: note that the overlay isn't drawn over browser fullscreen.
- [ ] Print preview (Cmd+P): no overlay in the preview.
- [ ] Click **reload** on the extension card in `chrome://extensions` with Pace on and tabs open: each tab ends with exactly one working overlay (or none until the next mouse move, then one). Turning Pace off afterwards removes it everywhere.
- [ ] Zoom the popup to 200% (Cmd+plus while it's open): it's still usable.
- [ ] Keyboard only in the popup: Tab through every control; arrow keys change Size and Color; focus rings are visible.

## Analytics (needs a real PostHog project key in `config.json`)
- [ ] Toggle Pace on and off and change size. Within about a minute, PostHog shows `pace_view_shown`, `mode_activated`, `pace_view_hidden` and `mode_deactivated` with `platform = chrome_extension`.
- [ ] The service worker console (`chrome://extensions` → Pace → "service worker") shows **no CORS errors**.
- [ ] Turn off **Share anonymous usage**: no further events arrive.
