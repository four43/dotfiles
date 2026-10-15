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
  for (const code of ['BAD_NAME', 'WEIGHT_SUM', 'NO_NORMALS', 'NO_UV', 'INSIDE_OUT', 'SKIN_NOT_ROOT', 'MISSING_SOCKET', 'gltf:ACCESSOR_JOINTS_USED_ZERO_WEIGHT', 'STATIC_TRACK'])
    assert.match(r.stdout, new RegExp(`\\[${code}\\]`), `expected ${code}`);
});

test('fix.mjs repairs the mechanical defects in broken.glb', () => {
  const out = path.join(tmp, 'fixed.glb');
  const f = run('fix.mjs', path.join(SKILL, 'evals/files/broken.glb'), out);
  assert.equal(f.status, 0, f.stdout + f.stderr);
  assert.match(f.stdout, /fixed \[uvs\]/);
  const r = run('validate.mjs', out);
  for (const code of ['BAD_NAME', 'WEIGHT_SUM', 'NO_NORMALS', 'NO_UV', 'INSIDE_OUT', 'SKIN_NOT_ROOT'])
    assert.doesNotMatch(r.stdout, new RegExp(`\\[${code}\\]`), `${code} still reported:\n${r.stdout}`);
});

test('look.mjs renders geo, diag, uv and anim sheets', () => {
  const glb = path.join(tmp, 'pig.glb');
  for (const args of [[], ['--sheet', 'diag'], ['--sheet', 'uv'], ['--sheet', 'anim', '--clip', 'Walk']]) {
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

test('kit UVs are in meters with no stretch; uv fit squeezes each face into 0..1', async () => {
  const { model } = await import(path.join(SKILL, 'scripts', 'kit.mjs'));
  const m = model('uvs');
  const shapes = { box: m.box(2, 0.1, 0.3), cyl: m.cyl(0.3, 0.3, 0.1, 12), cone: m.cone(0.2, 0.6), sphere: m.sphere(0.4), torus: m.torus(0.5, 0.05), lathe: m.lathe([[0.1, 0], [0.3, 0.05], [0.25, 0.6]]) };
  let x = 0; for (const [k, g] of Object.entries(shapes)) m.part(k, g, { at: [x += 3, 0, 0] });
  m.part('fit', m.box(2, 0.1, 0.3), { at: [0, 0, 3], uv: 'fit' });
  const uv = m.node('box').getMesh().listPrimitives()[0].getAttribute('TEXCOORD_0');
  assert.ok(Math.abs(uv.getMax([])[0] - 2) < 1e-6, `2 m box face should span 2 UV units, got ${uv.getMax([])[0]}`);
  const out = path.join(tmp, 'uvs.glb'); await m.write(out);
  const r = run('validate.mjs', out);
  assert.match(r.stdout, /\[UV_STRETCH\] fit#0/);
  assert.equal(r.stdout.match(/\[UV_STRETCH\]/g).length, 1, r.stdout);
  assert.throws(() => m.part('bad', m.wedge(1, 1, 1), { uv: 'fit' }), /always meters/);
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
