// Repair the mechanical defects validate.mjs reports, on a GLB the kit didn't make. Prints every change it makes.
// Usage: node fix.mjs in.glb out.glb [--only names,weights,normals,winding,metal,skinroot] [--ground]
//   names     rename nodes/clips/materials to A-Z a-z 0-9 _ - and make them unique (BAD_NAME, DUP_NAME)
//   weights   divide each vertex's weights by their sum; joint index 0 wherever weight is 0 (WEIGHT_SUM, JOINTS_USED_ZERO_WEIGHT)
//   normals   add missing NORMALs, normalize non-unit ones (NO_NORMALS, ACCESSOR_VECTOR3_NON_UNIT)
//   winding   reverse triangles of closed inside-out shells (INSIDE_OUT)
//   metal     metallic -> 0 when >= 0.5 with no metal texture (METALLIC)
//   skinroot  move skinned mesh nodes to the scene root with identity TRS, baking the old world matrix into the
//             vertices. That keeps what three.js showed (it applies the parent at bind time); IBMs stay. (SKIN_NOT_ROOT)
//   --ground  (opt-in) move the scene's top-level nodes so the model sits at y=0, centered in x/z (NOT_GROUNDED)
// Not fixed here (needs judgement): missing sockets/clips, static or popping clips, open shells, sizes. Edit those
// with glTF-Transform directly (see references/gltf-rules.md), then re-run validate.mjs.
import { normals } from '@gltf-transform/functions';
import { io, readDoc, sceneBox, wm, THREE, f2 } from './lib.mjs';

const args = process.argv.slice(2);
const [inFile, outFile] = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--only');
if (!inFile || !outFile) { console.error('usage: node fix.mjs in.glb out.glb [--only names,weights,normals,winding,metal,skinroot] [--ground]'); process.exit(2); }
const only = args.includes('--only') ? new Set(args[args.indexOf('--only') + 1].split(',')) : null;
const on = k => !only || only.has(k);
const doc = await readDoc(inFile), root = doc.getRoot();
const log = (k, msg) => console.log(`fixed [${k}] ${msg}`);

if (on('names')) {
  const used = new Set();
  const clean = (thing, kind) => {
    const old = thing.getName() || kind;
    let nm = old.replace(/\s+/g, '_').replace(/[^A-Za-z0-9_-]/g, '_'), base = nm, i = 1;
    while (used.has(nm)) nm = `${base}_${i++}`;
    used.add(nm);
    if (nm !== old) { thing.setName(nm); log('names', `${kind} "${old}" -> "${nm}"`); }
  };
  root.listScenes().forEach(s => used.add(s.getName()));
  root.listNodes().forEach(n => clean(n, 'node'));
  const clipNames = new Set(); root.listAnimations().forEach(a => { const old = a.getName(); let nm = (old || 'clip').replace(/[^A-Za-z0-9_-]/g, '_'); while (clipNames.has(nm)) nm += '_2'; clipNames.add(nm); if (nm !== old) { a.setName(nm); log('names', `clip "${old}" -> "${nm}"`); } });
}

if (on('skinroot')) {
  const sc = root.getDefaultScene() ?? root.listScenes()[0];
  for (const n of root.listNodes().filter(n => n.getSkin())) {
    const m = wm(n), parent = n.getParentNode();
    const identity = m.equals(new THREE.Matrix4());
    if (!parent && identity) continue;
    if (!identity) {
      const nm = new THREE.Matrix3().getNormalMatrix(m);
      for (const p of n.getMesh().listPrimitives()) {
        const P = p.getAttribute('POSITION'), N = p.getAttribute('NORMAL'), v = new THREE.Vector3();
        for (let i = 0; i < P.getCount(); i++) P.setElement(i, v.fromArray(P.getElement(i, [])).applyMatrix4(m).toArray());
        if (N) for (let i = 0; i < N.getCount(); i++) N.setElement(i, v.fromArray(N.getElement(i, [])).applyMatrix3(nm).normalize().toArray());
      }
    }
    if (parent) parent.removeChild(n);
    n.setTranslation([0, 0, 0]).setRotation([0, 0, 0, 1]).setScale([1, 1, 1]);
    if (!sc.listChildren().includes(n)) sc.addChild(n);
    log('skinroot', `"${n.getName()}" moved to scene root${identity ? '' : ' (old world transform baked into vertices)'}`);
  }
}

for (const mesh of root.listMeshes()) for (const [pi, p] of mesh.listPrimitives().entries()) {
  const where = `${mesh.getName() || 'mesh'}#${pi}`;
  const J = p.getAttribute('JOINTS_0'), W = p.getAttribute('WEIGHTS_0');
  if (on('weights') && J && W) {
    let changed = 0;
    for (let i = 0; i < W.getCount(); i++) {
      const w = W.getElement(i, []), j = J.getElement(i, []), s = w.reduce((a, b) => a + b, 0);
      const w2 = s > 0 ? w.map(x => x / s) : [1, 0, 0, 0], j2 = j.map((x, k) => (w2[k] > 0 ? x : 0));
      if (w2.some((x, k) => Math.abs(x - w[k]) > 1e-6) || j2.some((x, k) => x !== j[k])) { W.setElement(i, w2); J.setElement(i, j2); changed++; }
    }
    if (changed) log('weights', `${where}: ${changed} vertices normalized / unused joint slots zeroed`);
  }
  if (on('normals')) {
    const N = p.getAttribute('NORMAL');
    if (N) {
      let changed = 0; const v = new THREE.Vector3();
      for (let i = 0; i < N.getCount(); i++) { v.fromArray(N.getElement(i, [])); const l = v.length(); if (Math.abs(l - 1) > 1e-3 && l > 0) { N.setElement(i, v.normalize().toArray()); changed++; } }
      if (changed) log('normals', `${where}: ${changed} normals rescaled to unit length`);
    }
  }
  if (on('winding') && p.getMode() === 4) {
    const P = p.getAttribute('POSITION'), I = p.getIndices();
    const n = I ? I.getCount() : P.getCount(), idx = k => (I ? I.getScalar(k) : k);
    const key = v => P.getElement(v, []).map(x => Math.round(x * 1e4)).join(',');
    const edges = new Map(); let vol = 0; const A = new THREE.Vector3(), B = new THREE.Vector3(), C = new THREE.Vector3();
    for (let k = 0; k < n; k += 3) {
      const a = idx(k), b = idx(k + 1), c = idx(k + 2);
      A.fromArray(P.getElement(a, [])); B.fromArray(P.getElement(b, [])); C.fromArray(P.getElement(c, []));
      vol += A.dot(B.clone().cross(C)) / 6;
      for (const [u, w] of [[a, b], [b, c], [c, a]]) { const e = [key(u), key(w)].sort().join('|'); edges.set(e, (edges.get(e) || 0) + 1); }
    }
    if (![...edges.values()].some(c => c === 1) && vol < -1e-9) {
      if (I) { const arr = I.getArray().slice(); for (let k = 0; k < arr.length; k += 3) [arr[k + 1], arr[k + 2]] = [arr[k + 2], arr[k + 1]]; I.setArray(arr); }
      else for (const sem of p.listSemantics()) { const a = p.getAttribute(sem); for (let k = 0; k < a.getCount(); k += 3) { const e1 = a.getElement(k + 1, []), e2 = a.getElement(k + 2, []); a.setElement(k + 1, e2); a.setElement(k + 2, e1); } }
      const N = p.getAttribute('NORMAL'); if (N) for (let i = 0; i < N.getCount(); i++) N.setElement(i, N.getElement(i, []).map(x => -x));
      log('winding', `${where}: inside-out shell reversed`);
    }
  }
}
if (on('normals')) {
  const missing = root.listMeshes().flatMap(m => m.listPrimitives()).filter(p => !p.getAttribute('NORMAL')).length;
  if (missing) { await doc.transform(normals({ overwrite: false })); log('normals', `${missing} primitives got computed normals (smooth across shared vertices)`); }
}

if (on('metal')) for (const m of root.listMaterials())
  if (m.getMetallicFactor() >= 0.5 && !m.getMetallicRoughnessTexture()) { log('metal', `material "${m.getName() || '(unnamed)'}" metallic ${f2(m.getMetallicFactor())} -> 0`); m.setMetallicFactor(0); }

if (args.includes('--ground')) {
  const b = sceneBox(doc), c = b.getCenter(new THREE.Vector3()), d = [-c.x, -b.min.y, -c.z];
  if (d.some(x => Math.abs(x) > 1e-4)) {
    const sc = root.getDefaultScene() ?? root.listScenes()[0];
    for (const n of sc.listChildren()) {
      if (n.getSkin()) { for (const p of n.getMesh().listPrimitives()) { const P = p.getAttribute('POSITION'); for (let i = 0; i < P.getCount(); i++) P.setElement(i, P.getElement(i, []).map((x, k) => x + d[k])); } continue; }
      n.setTranslation(n.getTranslation().map((x, k) => x + d[k]));
    }
    // joints moved with their top-level parents; skinned vertices moved above; rebuild IBMs to match the new joint positions
    for (const s of root.listSkins()) { const arr = new Float32Array(s.listJoints().length * 16); s.listJoints().forEach((j, i) => wm(j).invert().toArray(arr, i * 16)); s.getInverseBindMatrices()?.setArray(arr); }
    log('ground', `moved by (${d.map(f2).join(', ')})`);
  }
}

await io.write(outFile, doc);
console.log(`wrote ${outFile}. Now run validate.mjs on it (with --spec if the spec has another name).`);
