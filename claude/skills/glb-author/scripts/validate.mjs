// Check a GLB: Khronos validator, data checks, a three.js reload with every clip sampled, and the spec if one exists.
// Usage: node validate.mjs model.glb [--spec model.spec.json] [--quiet]
// Prints PASS or FAIL lines with codes; exits 1 on any FAIL. WARN lines don't fail but each needs a reason to keep.
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { readDoc, findSpec, sceneBox, nodeBox, wm, tris, drawnTris, loadThree, posedBox, nearest, NAME, f2, v3, THREE } from './lib.mjs';

const args = process.argv.slice(2);
const file = args.find(a => !a.startsWith('--') && args[args.indexOf(a) - 1] !== '--spec');
if (!file) { console.error('usage: node validate.mjs model.glb [--spec model.spec.json]'); process.exit(2); }
const specArg = args.includes('--spec') ? args[args.indexOf('--spec') + 1] : undefined;
const found = findSpec(file, specArg);
if (specArg && !found) { console.error(`spec not found: ${specArg}`); process.exit(2); }
const spec = found?.spec;

const fails = [], warns = [], notes = [];
const FAIL = (code, msg) => fails.push(`FAIL [${code}] ${msg}`);
const WARN = (code, msg) => warns.push(`WARN [${code}] ${msg}`);

// ---------- 1. Khronos glTF validator ----------
const validator = createRequire(import.meta.url)('gltf-validator');
const bytes = new Uint8Array(fs.readFileSync(file));
const report = await validator.validateBytes(bytes, { maxIssues: 0, writeTimestamp: false, ignoredIssues: ['NODE_EMPTY', 'UNUSED_OBJECT'],
  severityOverrides: { NODE_SKINNED_MESH_NON_ROOT: 1, NODE_SKINNED_MESH_LOCAL_TRANSFORMS: 1 } });
let gltfJson = {}; try { const len = new DataView(bytes.buffer, bytes.byteOffset).getUint32(12, true); gltfJson = JSON.parse(new TextDecoder().decode(bytes.subarray(20, 20 + len))); } catch {}
const who = ptr => { const m = /^\/(meshes|nodes|materials|animations)\/(\d+)/.exec(ptr || ''); const nm = m && gltfJson[m[1]]?.[+m[2]]?.name; return nm ? ` ("${nm}")` : ''; };
for (const m of report.issues.messages) if (m.severity <= 1) FAIL(`gltf:${m.code}`, `${m.pointer ?? ''}${who(m.pointer)} ${m.message}`);
notes.push(`khronos: ${report.issues.numErrors} errors, ${report.issues.numWarnings} warnings; ${report.info?.totalTriangleCount ?? '?'} tris, ${report.info?.drawCallCount ?? '?'} draw calls, max ${report.info?.maxInfluences ?? 0} influences`);
// ---------- 2. data checks ---------- (run even after Khronos errors, so one pass reports everything)
let doc;
try { doc = await readDoc(file); } catch (e) { FAIL('UNREADABLE', e.message); print(); process.exit(1); }
const root = doc.getRoot();
const sceneDef = root.getDefaultScene() ?? root.listScenes()[0];
const names = new Map();
for (const n of root.listNodes()) {
  const nm = n.getName();
  if (!nm) { WARN('UNNAMED_NODE', `a node has no name (parent ${n.getParentNode()?.getName() ?? 'scene'}); game code can't find it`); continue; }
  if (/[\s\[\]\.:\/]/.test(nm)) FAIL('BAD_NAME', `"${nm}": three.js GLTFLoader renames it to "${nm.replace(/\s/g, '_').replace(/[\[\]\.:\/]/g, '')}"; use only A-Z a-z 0-9 _ -`);
  if (names.has(nm)) FAIL('DUP_NAME', `"${nm}" used twice; three.js renames the second to "${nm}_1" and clips bind to the wrong node`);
  names.set(nm, n);
}
for (const a of root.listAnimations()) if (!a.getName()) WARN('UNNAMED_CLIP', 'a clip has no name');
for (const sc of root.listScenes()) if (names.has(sc.getName())) FAIL('DUP_NAME', `scene and node are both named "${sc.getName()}"; three.js renames the node to "${sc.getName()}_1"`);

for (const mesh of root.listMeshes()) for (const [pi, p] of mesh.listPrimitives().entries()) {
  const where = `${mesh.getName() || 'mesh'}#${pi}`;
  const pos = p.getAttribute('POSITION');
  if (!pos) { FAIL('NO_POSITION', where); continue; }
  if (!pos.getArray().every(Number.isFinite)) FAIL('NAN_POSITION', `${where} has NaN/Infinity positions`);
  if (!p.getAttribute('NORMAL') && !p.getMaterial()?.getExtension('KHR_materials_unlit')) FAIL('NO_NORMALS', `${where} has no NORMAL: it renders black under lights (the Khronos validator does not catch this)`);
  const J = p.getAttribute('JOINTS_0'), W = p.getAttribute('WEIGHTS_0');
  if (J && ![5121, 5123].includes(J.getComponentType())) FAIL('JOINT_TYPE', `${where} JOINTS_0 must be Uint8/Uint16`);
  if (W) {
    let worst = 0, at = -1, sum = 1;
    for (let i = 0; i < W.getCount(); i++) { const s = W.getElement(i, []).reduce((x, y) => x + y, 0); if (Math.abs(s - 1) > worst) { worst = Math.abs(s - 1); at = i; sum = s; } }
    if (worst > 2e-3) FAIL('WEIGHT_SUM', `${where} vertex ${at} weights sum to ${f2(sum)} (must be 1; divide each vertex's weights by their sum)`);
  }
  // closed, outward-facing? signed volume over triangles; only judged when every edge is shared (closed shell)
  if (p.getMode() === 4) {
    const P = pos.getArray(), I = p.getIndices()?.getArray(), n = I ? I.length : pos.getCount();
    const idx = k => (I ? I[k] : k);
    const key = v => `${Math.round(P[v * 3] * 1e4)},${Math.round(P[v * 3 + 1] * 1e4)},${Math.round(P[v * 3 + 2] * 1e4)}`;
    const edges = new Map(); let vol = 0;
    for (let k = 0; k < n; k += 3) {
      const a = idx(k), b = idx(k + 1), c = idx(k + 2);
      const A = new THREE.Vector3().fromArray(P, a * 3), B = new THREE.Vector3().fromArray(P, b * 3), C = new THREE.Vector3().fromArray(P, c * 3);
      vol += A.dot(B.clone().cross(C)) / 6;
      for (const [u, v] of [[a, b], [b, c], [c, a]]) { const e = [key(u), key(v)].sort().join('|'); edges.set(e, (edges.get(e) || 0) + 1); }
    }
    const open = [...edges.values()].filter(c => c === 1).length;
    if (!open && vol < -1e-9) FAIL('INSIDE_OUT', `${where} is a closed shell with negative volume: faces point inward (reverse the triangle winding)`);
    if (open && !p.getMaterial()?.getDoubleSided()) WARN('OPEN_SHELL', `${where} has ${open} open edges and a single-sided material: you can see through it from behind/inside. Fine for a deliberate plane; else cap the hole or set doubleSided`);
  }
}

for (const n of root.listNodes()) {
  if (!n.getSkin()) continue;
  if (n.getParentNode()) FAIL('SKIN_NOT_ROOT', `skinned mesh "${n.getName()}" must be a direct child of the scene (it is under "${n.getParentNode().getName()}")`);
  const t = n.getTranslation(), r = n.getRotation(), s = n.getScale();
  if (t.some(Boolean) || r[3] < 0.99999 || s.some(x => Math.abs(x - 1) > 1e-6)) FAIL('SKIN_TRANSFORM', `skinned mesh "${n.getName()}" must have no translation/rotation/scale (glTF ignores it; bake it into the vertices)`);
}

for (const a of root.listAnimations()) {
  const still = [], chans = a.listChannels();
  for (const ch of chans) {
    const s = ch.getSampler(), t = s.getInput().getArray(), out = s.getOutput(), tgt = `${a.getName()}: ${ch.getTargetNode()?.getName()}.${ch.getTargetPath()}`;
    for (let i = 1; i < t.length; i++) if (!(t[i] > t[i - 1])) { FAIL('KEY_ORDER', `${tgt} key times not increasing at ${i}`); break; }
    if (ch.getTargetPath() === 'rotation') for (let i = 0; i < out.getCount(); i++) { const q = out.getElement(i, []); if (Math.abs(Math.hypot(...q) - 1) > 1e-3) { FAIL('QUAT_NORM', `${tgt} key ${i} quaternion not unit length`); break; } }
    const vals = out.getArray(), w = out.getElementSize();
    let moves = false; for (let i = w; i < vals.length && !moves; i++) if (Math.abs(vals[i] - vals[i % w]) > 1e-5) moves = true;
    if (!moves && ch.getTargetPath() !== 'weights') still.push(`${ch.getTargetNode()?.getName()}.${ch.getTargetPath()}`);
  }
  if (still.length) WARN('STATIC_TRACK', `${a.getName()}: ${still.length} of ${chans.length} tracks never change (${still.slice(0, 4).join(', ')}${still.length > 4 ? ', ...' : ''}). Fine if they hold a pose on purpose; a bug if meant to move (a 360 deg turn with 2 keys is a no-op: key every <=90 deg)`);
}

const box = sceneBox(doc), size = box.getSize(new THREE.Vector3()), ctr = box.getCenter(new THREE.Vector3());
notes.push(`rest bbox: ${f2(size.x)} x ${f2(size.y)} x ${f2(size.z)} m, bottom y=${f2(box.min.y)}, center x=${f2(ctr.x)} z=${f2(ctr.z)}`);
const grounded = spec?.grounded ?? true;
if (grounded && Math.abs(box.min.y) > 0.01) (spec ? FAIL : WARN)('NOT_GROUNDED', `lowest point is y=${f2(box.min.y)}; the origin should be at the bottom (set "grounded": false in the spec for floating things)`);
if (Math.abs(ctr.x) > 0.2 * Math.max(size.x, 0.1) || Math.abs(ctr.z) > 0.2 * Math.max(size.z, 0.1)) WARN('OFF_CENTER', `bbox center is x=${f2(ctr.x)} z=${f2(ctr.z)}; origin should be bottom-center (fine if a tongue/tail/head sticks out on purpose)`);

for (const m of root.listMaterials()) {
  if (m.getMetallicFactor() >= 0.5 && !m.getMetallicRoughnessTexture() && !m.getExtension('KHR_materials_unlit'))
    WARN('METALLIC', `material "${m.getName() || '(unnamed)'}" has metallic ${f2(m.getMetallicFactor())}: renders dark/black in three.js without an environment map. glTF defaults metallic to 1 when unset; use 0 for non-metal`);
}
for (const t of root.listTextures()) {
  const sz = t.getSize();
  if (sz && sz.some(d => (d & (d - 1)) !== 0)) WARN('NPOT_TEXTURE', `${t.getName() || 'texture'} is ${sz.join('x')}; use powers of two`);
  if (sz && spec?.budget?.textureSize && Math.max(...sz) > spec.budget.textureSize) FAIL('TEXTURE_BUDGET', `${t.getName()} ${sz.join('x')} > ${spec.budget.textureSize}`);
}

// ---------- 3. three.js reload + clip sampling ----------
let gltf;
try { gltf = await loadThree(file); } catch (e) { FAIL('THREE_LOAD', e.message); }
if (gltf) {
  const s3 = gltf.scene;
  for (const nm of names.keys()) if (!/[\s\[\]\.:\/]/.test(nm) && !s3.getObjectByName(nm)) FAIL('LOST_NODE', `"${nm}" is in the file but not in the three.js scene`);
  const restBox = posedBox(s3), restSize = restBox.getSize(new THREE.Vector3());
  for (const clip of gltf.animations) {
    for (const t of clip.tracks) {
      const { nodeName } = THREE.PropertyBinding.parseTrackName(t.name);
      if (!THREE.PropertyBinding.findNode(s3, nodeName)) FAIL('UNBOUND_TRACK', `${clip.name}: track ${t.name} targets nothing`);
    }
    const mixer = new THREE.AnimationMixer(s3), act = mixer.clipAction(clip).play();
    const steps = 24; let low = Infinity, lowT = 0, minFrac = Infinity, minT = 0, high = -Infinity, highT = 0;
    for (let i = 0; i <= steps; i++) {
      const t = clip.duration * i / steps; mixer.setTime(t);
      const b = posedBox(s3), sz = b.getSize(new THREE.Vector3());
      if (b.min.y < low) { low = b.min.y; lowT = t; }
      if (b.min.y > high) { high = b.min.y; highT = t; }
      const frac = Math.min(sz.x / (restSize.x || 1), sz.y / (restSize.y || 1), sz.z / (restSize.z || 1));
      if (frac < minFrac) { minFrac = frac; minT = t; }
    }
    if (high > box.min.y + Math.max(0.01, 0.02 * restSize.y)) WARN('AIRBORNE', `${clip.name}: nothing touches the ground at t=${f2(highT)}s (lowest point y=${f2(high)}). Fine for a jump; for a walk, lower the body as legs swing (drop = leg length * (1 - cos swing))`);
    if (low < box.min.y - 0.03) WARN('BELOW_GROUND', `${clip.name}: mesh dips to y=${f2(low)} at t=${f2(lowT)}s`);
    if (minFrac < 0.6) WARN('COLLAPSE', `${clip.name}: model shrinks to ${Math.round(minFrac * 100)}% of rest size on one axis at t=${f2(minT)}s (check weights / bone rotations)`);
    // loop seam: pose at t=0 vs t=duration
    const loopFlag = spec?.clips?.[clip.name]?.loop ?? root.listAnimations().find(a => a.getName() === clip.name)?.getExtras()?.loop;
    if (loopFlag) {
      const pose = () => { const o = []; s3.traverse(n => o.push([n.name, n.position.clone(), n.quaternion.clone(), n.scale.clone()])); return o; };
      mixer.setTime(0); const p0 = pose(); mixer.setTime(clip.duration - 1e-6); const p1 = pose();
      for (let i = 0; i < p0.length; i++) {
        const d = p0[i][1].distanceTo(p1[i][1]) + p0[i][3].distanceTo(p1[i][3]), ang = p0[i][2].angleTo(p1[i][2]) * 180 / Math.PI;
        if (d > 1e-3 || ang > 0.5) { FAIL('LOOP_SEAM', `${clip.name}: "${p0[i][0]}" pose at end differs from start (${f2(d)} m, ${f2(ang)} deg); it will pop when looping`); break; }
      }
    }
    act.stop(); mixer.uncacheRoot(s3);
  }
}

// ---------- 4. spec ----------
if (spec) {
  notes.push(`spec: ${found.path}`);
  const tol = spec.tolerance ?? 0.1;
  if (spec.size) ['x', 'y', 'z'].forEach((ax, i) => {
    const want = spec.size[i], got = size[ax];
    const allow = Math.max((Array.isArray(tol) ? tol[i] : tol) * want, 0.01); // fraction of the axis, never tighter than 1 cm
    if (want != null && Math.abs(got - want) > allow) FAIL('SIZE', `${ax} size ${f2(got)} m, spec ${want} m (±${f2(allow)} m)`);
  });
  const all = [...names.keys()];
  for (const nm of spec.nodes ?? []) if (!names.has(nm)) FAIL('MISSING_NODE', `"${nm}" not found${nearest(nm, all).length ? `; did you mean ${nearest(nm, all).join(' or ')}?` : ''}`);
  for (const nm of spec.sockets ?? []) {
    const n = names.get(nm);
    if (!n) FAIL('MISSING_SOCKET', `"${nm}" not found${nearest(nm, all).length ? `; did you mean ${nearest(nm, all).join(' or ')}?` : ''}. Add an empty node (kit: m.socket; raw: doc.createNode + parent.addChild); if it existed before an optimize step, a plain prune() deleted it (use keepLeaves: true)`);
    else if (n.getMesh()) FAIL('SOCKET_HAS_MESH', `"${nm}" should be an empty node`);
  }
  for (const nm of spec.contacts ?? []) { // named parts that must touch the ground (wheels, feet, legs)
    const n = names.get(nm);
    if (!n) { FAIL('MISSING_NODE', `contact "${nm}" not found`); continue; }
    const b = new THREE.Box3(); n.traverse(c => { if (c.getMesh()) b.union(nodeBox(c)); });
    if (b.isEmpty()) FAIL('CONTACT', `"${nm}" has no mesh under it`);
    else if (Math.abs(b.min.y) > 0.003) FAIL('CONTACT', `"${nm}" lowest point y=${f2(b.min.y)} m; it should touch the ground (y=0). A cylinder laid on its side touches with a corner only if sides is a multiple of 4`);
  }
  const clips = new Map(root.listAnimations().map(a => [a.getName(), a]));
  for (const [nm, c] of Object.entries(spec.clips ?? {})) {
    const a = clips.get(nm);
    if (!a) { FAIL('MISSING_CLIP', `"${nm}" not found; clips: [${[...clips.keys()].join(', ')}]`); continue; }
    const dur = Math.max(0, ...a.listSamplers().map(s => s.getInput().getMax([])[0]));
    if (c.duration && Math.abs(dur - c.duration) > 0.02) FAIL('CLIP_DURATION', `${nm} lasts ${f2(dur)}s, spec ${c.duration}s`);
    for (const nn of c.moves ?? []) if (!a.listChannels().some(ch => ch.getTargetNode()?.getName() === nn)) FAIL('CLIP_TARGET', `${nm} does not animate "${nn}"`);
  }
  const b = spec.budget ?? {};
  const T = drawnTris(doc);
  if (b.tris && T > b.tris) FAIL('TRI_BUDGET', `${T} tris > ${b.tris}`);
  if (b.materials && root.listMaterials().length > b.materials) FAIL('MATERIAL_BUDGET', `${root.listMaterials().length} materials > ${b.materials}`);
  if (b.kb && bytes.length / 1024 > b.kb) FAIL('SIZE_BUDGET', `${f2(bytes.length / 1024)} KB > ${b.kb} KB`);
} else WARN('NO_SPEC', `no spec checked: write ${file.replace(/\.glb$/, '.spec.json')} or pass --spec <file> to check size, names, sockets, clips, budgets`);

print();
process.exit(fails.length ? 1 : 0);

function print() {
  const quiet = args.includes('--quiet');
  if (!quiet) notes.forEach(n => console.log(`  ${n}`));
  // group repeats by code: first 2 lines + a count, so the output stays short
  const groups = new Map();
  for (const l of [...fails, ...warns]) { const k = l.slice(0, l.indexOf(']') + 1); if (!groups.has(k)) groups.set(k, []); groups.get(k).push(l); }
  for (const ls of groups.values()) { ls.slice(0, 2).forEach(l => console.log(l)); if (ls.length > 2) console.log(`  ... and ${ls.length - 2} more like this`); }
  console.log(fails.length ? `FAIL: ${fails.length} failing, ${warns.length} warnings — ${file}` : `PASS${warns.length ? ` with ${warns.length} warnings` : ''} — ${file}`);
}
