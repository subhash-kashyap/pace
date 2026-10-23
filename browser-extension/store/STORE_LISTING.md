# Chrome Web Store listing: copy and paste

Everything the Developer Dashboard asks for, in the order it asks. Images are in `store/images/` (regenerate with `npm run store:assets`).

---

## Store listing tab

**Name** (from manifest, max 75 chars)
```
Pace — Reading Focus
```

**Summary** (from manifest `description`, max 132 chars)
```
Dim the page and keep a focus band under your cursor while you read.
```

**Description**
```
Pace helps you read on the web without losing your place.

It dims everything on the page except a soft band that follows your mouse. Your eyes stay on the lines you're reading, and the rest of the page fades out of the way.

• One tap: turn Pace on and it works in every tab, including ones already open.
• Three band sizes: small, medium and large.
• Dark or light dimming, with adjustable opacity.
• Optional blur to frost the dimmed parts of the page.
• Works on articles, docs, email, and local files.
• Links, text selection and typing all keep working through the dimmed area.

Private by design: Pace never reads the text of your pages and never collects your URLs or browsing history. It only uses your mouse's vertical position, inside the tab, to place the band.

Pace is also available as a Mac app.
```

**Category:** `Tools` (alternatives: `Accessibility`, `Education`)

**Language:** English

**Graphic assets**

| Field | File |
|---|---|
| Store icon (128×128) | `icons/icon128.png` |
| Screenshots (1280×800, up to 5) | `store/images/screenshot-1-focus-band.png`, `screenshot-2-popup.png`, `screenshot-3-light.png`, `screenshot-4-blur.png` |
| Small promo tile (440×280) | `store/images/promo-small-440x280.png` |
| Marquee promo tile (1400×560, optional) | `store/images/promo-marquee-1400x560.png` |

**Official URL:** none (needs a verified domain in Search Console; skip it)
**Homepage URL:** `https://github.com/subhash-kashyap/pace`
**Support URL:** `https://github.com/subhash-kashyap/pace/issues`

---

## Privacy practices tab

**Single purpose**
```
Pace dims web pages except for a horizontal reading band that follows the user's mouse, to help them focus while reading.
```

**Permission justification: `storage`**
```
Saves the user's Pace settings (on/off, band size, color, opacity, blur) locally so they persist and apply across all tabs.
```

**Permission justification: `scripting`**
```
When the user turns Pace on or installs/updates it, Pace injects its overlay script into tabs that were already open, so the reading band appears immediately without the user having to reload every tab.
```

**Permission justification: host permission (`<all_urls>`)**
```
Pace's only feature is an overlay drawn on top of the web pages the user reads, on any site they choose to read. It needs access to all sites to place that overlay. The script adds its own element to the page and listens for the mouse's vertical position; it never reads, stores or transmits page content, URLs or titles.
```

**Remote code:** `No, I am not using remote code.`
(All JavaScript ships in the package. The analytics endpoint receives JSON over `fetch`; nothing is downloaded and executed.)

**Data usage: what the extension collects**

Leave **every** category unchecked if you ship with analytics off (no `config.json`).

If you ship with analytics on, the events are anonymous product-usage counts (on/off, band size, durations, a random install ID). None of Chrome's categories describe them exactly. The closest is **"User activity"**, whose examples include clicks and mouse position. Pace sends neither, but ticking it is the cautious choice and costs nothing. Do **not** tick "Web history" or "Website content", because Pace never sends either.

Then tick all three certifications:
- I do not sell or transfer user data to third parties, outside of the approved use cases
- I do not use or transfer user data for purposes that are unrelated to my item's single purpose
- I do not use or transfer user data to determine creditworthiness or for lending purposes

**Privacy policy URL**
```
https://github.com/subhash-kashyap/pace/blob/main/browser-extension/PRIVACY.md
```
(This link only works once this branch is merged to `main`. Before that, use `/blob/features/…`.)

---

## Distribution tab

- **Visibility:** Public (or Unlisted for a soft launch: only people with the link can install)
- **Regions:** All regions
- **Pricing:** Free
