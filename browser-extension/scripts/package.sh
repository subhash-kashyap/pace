#!/usr/bin/env bash
# Build the Chrome Web Store upload: dist/pace-chrome-<version>.zip
# Only runtime files go in; tests, node_modules and store assets stay out.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(node -p "require('./manifest.json').version")
PKG_VERSION=$(node -p "require('./package.json').version")
if [ "$VERSION" != "$PKG_VERSION" ]; then
  echo "error: manifest.json version ($VERSION) != package.json version ($PKG_VERSION)" >&2
  exit 1
fi

FILES=(manifest.json src icons)

if [ -f config.json ]; then
  node -e "
    const c = require('./config.json');
    const k = (c.posthogApiKey || '').trim();
    if (!k.startsWith('phc_') || k === 'phc_your_project_api_key') {
      console.error('error: config.json posthogApiKey must be a real PostHog project key (phc_...)');
      process.exit(1);
    }"
  FILES+=(config.json)
  echo "analytics: ON (config.json included)"
else
  echo "analytics: OFF (no config.json; copy config.example.json to enable)"
fi

if [ "${SKIP_TESTS:-0}" != "1" ]; then
  npm test
fi

mkdir -p dist
OUT="dist/pace-chrome-$VERSION.zip"
rm -f "$OUT"
zip -r -X -q "$OUT" "${FILES[@]}" -x '*.DS_Store'
echo "built $OUT ($(du -h "$OUT" | cut -f1))"
unzip -l "$OUT"
