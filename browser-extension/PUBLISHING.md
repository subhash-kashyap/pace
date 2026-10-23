# Publishing Pace to the Chrome Web Store

A step-by-step checklist. Listing copy, permission justifications and privacy answers are ready to paste in [`store/STORE_LISTING.md`](store/STORE_LISTING.md).

## 0. One-time setup

- [ ] Register a developer account at <https://chrome.google.com/webstore/devconsole>. There's a one-time **$5 fee**. Use the Google account that should own Pace long-term (moving ownership later is painful). A Google Group account works if you want teammates to share access.
- [ ] Under **Account**, set and **verify a contact email**. You can't publish until it's verified.
- [ ] Turn on 2-Step Verification on that Google account. Chrome Web Store requires it to publish.

## 1. Before every release

- [ ] Replace `CONTACT_EMAIL` in [`PRIVACY.md`](PRIVACY.md) with the public support address (first release only).
- [ ] Merge to `main` so the privacy policy URL resolves (first release only).
- [ ] Bump `version` in **both** `manifest.json` and `package.json`. The store rejects re-uploads of a version it has already seen. Use `1.0.1`, `1.1.0` and so on.
- [ ] **Analytics decision:**
  - On: `cp config.example.json config.json` and set `posthogApiKey` to the PostHog **project** key (`phc_…`). The packaging script refuses to build with the placeholder key.
  - Off: make sure there is no `config.json`. Then the privacy tab needs no data categories ticked.
- [ ] Run the manual pass in [`test/QA_CHECKLIST.md`](test/QA_CHECKLIST.md) in real Chrome (load unpacked).

## 2. Build the zip

```bash
cd browser-extension
npm install                      # first time
npx playwright install chromium  # first time
npm run package                  # runs all tests, then writes dist/pace-chrome-<version>.zip
```

The zip contains only `manifest.json`, `src/`, `icons/` and (if present) `config.json`. Use `SKIP_TESTS=1 npm run package` only if you have just run the tests.

To refresh the store images after a UI change: `npm run store:assets` writes them to `store/images/`.

## 3. Upload

1. Developer Dashboard → **Items** → **New item** → upload `dist/pace-chrome-<version>.zip`.
2. **Store listing** tab: paste from `store/STORE_LISTING.md` and upload the icon, screenshots and promo tiles.
3. **Privacy practices** tab: paste the single purpose and the permission justifications, answer the remote code and data usage questions, and add the privacy policy URL.
4. **Distribution** tab: visibility, regions, free.
5. **Submit for review**. Leave **"Publish automatically after approval"** on unless you want to time the launch yourself.

## 4. Review: what to expect

- Because Pace asks for access to **all sites** (`<all_urls>`), review is the slower, in-depth kind: usually a few days, sometimes up to a few weeks for a first submission. The justification text in the listing doc is written for this reviewer.
- The install prompt will say **"Read and change all your data on all websites"**. Chrome shows this for any extension that can draw on pages, and there's no narrower permission that still lets the overlay appear in every tab. The description and privacy policy explain it in plain words.
- Common rejection reasons, and why Pace avoids them:
  - *Unused permissions*: every permission is used (`storage` for settings, `scripting` + hosts for the overlay and for injecting into already-open tabs).
  - *Remote code*: none.
  - *Missing privacy disclosure*: covered by `PRIVACY.md` and the data-usage answers.
  - *Misleading description*: the listing only claims what the extension does.
- If it's rejected, the email names the policy. Fix it, bump the version, rebuild, and resubmit.

## 5. Updates

Bump the version, run `npm run package`, then in the Dashboard open Pace → **Package** → **Upload new package** → **Submit for review**. Updates that don't add permissions are usually reviewed faster. Adding a permission later shows existing users a re-approval prompt and disables the extension until they accept, so avoid it if you can.

## After it's live

- Put the store link in the main `readme.md` and on the Mac app's site.
- Your first listing URL will look like `https://chromewebstore.google.com/detail/<id>`. The item ID is fixed from the first upload.
