const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..', '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));

test('manifest is MV3 with minimal permissions', () => {
  assert.equal(manifest.manifest_version, 3);
  assert.deepEqual([...manifest.permissions].sort(), ['scripting', 'storage']);
  assert.equal(manifest.web_accessible_resources, undefined, 'config.json must never be web accessible');
  assert.equal(manifest.externally_connectable, undefined);
  assert.equal(manifest.commands, undefined, 'no keyboard shortcuts in v1');
});

test('content script runs top-frame only, core before content', () => {
  const [cs] = manifest.content_scripts;
  assert.deepEqual(cs.js, ['src/core.js', 'src/content.js']);
  assert.equal(cs.all_frames, false);
});

test('every file referenced by the manifest exists', () => {
  const refs = [
    manifest.background.service_worker,
    manifest.action.default_popup,
    ...Object.values(manifest.icons),
    ...Object.values(manifest.action.default_icon),
    ...manifest.content_scripts.flatMap((c) => c.js)
  ];
  for (const ref of refs) assert.ok(fs.existsSync(path.join(root, ref)), `missing ${ref}`);
});

test('extension ships no runtime dependencies', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  assert.equal(pkg.dependencies, undefined);
  const srcFiles = fs.readdirSync(path.join(root, 'src'), { recursive: true }).filter((f) => f.endsWith('.js'));
  for (const f of srcFiles) {
    const code = fs.readFileSync(path.join(root, 'src', f), 'utf8');
    assert.doesNotMatch(code, /\brequire\(|^import\s/m, `${f} must not import modules`);
  }
});
