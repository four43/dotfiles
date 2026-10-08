// Self-test for the skill's scripts: templates build and pass, the broken file fails with every expected code,
// and look.mjs renders. Run: npm test (from the skill folder).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SKILL = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'glb-author-'));
const run = (script, ...args) => spawnSync('node', [path.join(SKILL, 'scripts', script), ...args], { encoding: 'utf8' });

function build(template, out) {
  const src = fs.readFileSync(path.join(SKILL, 'templates', template), 'utf8').replace("'../scripts/kit.mjs'", JSON.stringify(path.join(SKILL, 'scripts', 'kit.mjs')));
  const f = path.join(tmp, template); fs.writeFileSync(f, src);
  execFileSync('node', [f], { encoding: 'utf8' });
  return path.join(tmp, out);
}

for (const [t, glb] of [['prop.model.mjs', 'wagon.glb'], ['critter.model.mjs', 'pig.glb'], ['skinned.model.mjs', 'scarecrow.glb']]) {
  test(`${t} builds and validates`, () => {
    const r = run('validate.mjs', build(t, glb));
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.doesNotMatch(r.stdout, /^FAIL/m);
  });
}

test('broken.glb fails with every planted defect', () => {
  execFileSync('node', [path.join(SKILL, 'evals/files/make-broken.mjs')]);
  const r = run('validate.mjs', path.join(SKILL, 'evals/files/broken.glb'));
  assert.equal(r.status, 1);
  for (const code of ['BAD_NAME', 'WEIGHT_SUM', 'NO_NORMALS', 'INSIDE_OUT', 'SKIN_NOT_ROOT', 'MISSING_SOCKET', 'gltf:ACCESSOR_JOINTS_USED_ZERO_WEIGHT', 'STATIC_TRACK'])
    assert.match(r.stdout, new RegExp(`\\[${code}\\]`), `expected ${code}`);
});

test('look.mjs renders geo, diag and anim sheets', () => {
  const glb = path.join(tmp, 'pig.glb');
  for (const args of [[], ['--sheet', 'diag'], ['--sheet', 'anim', '--clip', 'Walk']]) {
    const r = run('look.mjs', glb, ...args);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    const png = r.stdout.match(/wrote (\S+\.png)/)[1];
    assert.ok(fs.statSync(png).size > 10000, `${png} too small`);
  }
});

test('kit keeps held keys, honours wave cycles, rejects bad names', async () => {
  const { model } = await import(path.join(SKILL, 'scripts', 'kit.mjs'));
  const m = model('t');
  m.group('arm', { at: [0, 1, 0] });
  const a = m.clip('Hold', { duration: 1 }, { arm: { rot: [[0, [0, 0, 0]], [0.4, [0, 0, 18]], [0.9, [0, 0, 18]], [1, [0, 0, 0]]] } });
  assert.equal(a.listChannels()[0].getSampler().getInput().getCount(), 4, 'held key dropped');
  const w = m.clip('Wag', { duration: 2, loop: true }, { arm: { rot: m.wave([0, 30, 0], { cycles: 3 }) } });
  assert.equal(w.listChannels()[0].getSampler().getInput().getCount(), 25);
  assert.throws(() => m.group('Arm.L'), /must match/);
});

test('look --zoom on a node under a mesh renders the part, not a blank sheet', async () => {
  const { PNG } = await import('pngjs');
  const r = run('look.mjs', path.join(tmp, 'pig.glb'), '--zoom', 'head', '--view', 'front', '--out', path.join(tmp, 'zoom.png'));
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const img = PNG.sync.read(fs.readFileSync(path.join(tmp, 'zoom.png')));
  let pink = 0; for (let i = 0; i < img.data.length; i += 4) if (img.data[i] > 150 && img.data[i + 1] < 140 && img.data[i + 2] > 100) pink++;
  assert.ok(pink > 5000, `only ${pink} pig-colored pixels`);
});

test('showcase.mjs bundles models into the viewer', () => {
  const out = path.join(tmp, 'show');
  const r = spawnSync('node', [path.join(SKILL, 'scripts', 'showcase.mjs'), '--out', out, '--title', 'Test Farm', '--group', 'Animals', path.join(tmp, 'pig.glb'), '--group', 'Props', path.join(tmp, 'wagon.glb')], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const html = fs.readFileSync(path.join(out, 'test-farm.html'), 'utf8');
  assert.match(html, /<title>Test Farm<\/title>/);
  const js = fs.readFileSync(path.join(out, 'models.js'), 'utf8');
  const data = JSON.parse(js.replace(/^window\.GLB_MODELS = /, '').replace(/;\s*$/, ''));
  assert.deepEqual(data.groups.map(g => g.group), ['Animals', 'Props']);
  assert.ok(data.data['pig.glb'].length > 1000 && data.groups[0].items[0].verdict.startsWith('PASS'));
});
