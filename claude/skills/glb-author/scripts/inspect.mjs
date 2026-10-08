// Print a GLB as compact facts: bbox, counts, node tree with world positions, materials, skins, clips.
// Usage: node inspect.mjs model.glb [--attrs [N]]   (--attrs: also print the first N (default 6) vertices of every attribute)
import fs from 'node:fs';
import { readDoc, sceneBox, nodeBox, wm, tris, drawnTris, hex, f2, v3, THREE } from './lib.mjs';

const file = process.argv[2], ai = process.argv.indexOf('--attrs'), attrN = ai < 0 ? 0 : +(process.argv[ai + 1] || 6) || 6;
if (!file) { console.error('usage: node inspect.mjs model.glb'); process.exit(2); }
const doc = await readDoc(file);
const root = doc.getRoot();
const scene = root.getDefaultScene() ?? root.listScenes()[0];
const box = sceneBox(doc), size = box.getSize(new THREE.Vector3()), ctr = box.getCenter(new THREE.Vector3());
const allTris = root.listMeshes().reduce((s, m) => s + m.listPrimitives().reduce((t, p) => t + tris(p), 0), 0);
const jointSet = new Set(root.listSkins().flatMap(s => s.listJoints()));
const out = [];
out.push(`file: ${file} (${(fs.statSync(file).size / 1024).toFixed(1)} KB)`);
out.push(`size: ${f2(size.x)} x ${f2(size.y)} x ${f2(size.z)} m (x by y by z)   bbox min ${v3(box.min.toArray())} max ${v3(box.max.toArray())}`);
out.push(`origin check: bottom y=${f2(box.min.y)} (want 0), center x=${f2(ctr.x)} z=${f2(ctr.z)} (want ~0)`);
out.push(`counts: ${root.listNodes().length} nodes, ${root.listMeshes().length} meshes, ${drawnTris(doc)} tris drawn (${allTris} unique), ${root.listMaterials().length} materials, ${root.listTextures().length} textures, ${root.listSkins().length} skins, ${root.listAnimations().length} clips`);
out.push('tree: (name [kind] local at / rot deg / world origin / world size)');
const deg = q => new THREE.Euler().setFromQuaternion(new THREE.Quaternion(...q)).toArray().slice(0, 3).map(r => f2(r * 180 / Math.PI));
function walk(n, depth) {
  const kind = n.getSkin() ? 'skinned mesh' : n.getMesh() ? 'mesh' : jointSet.has(n) ? 'bone' : n.getExtras()?.socket ? 'socket' : 'empty';
  const t = n.getTranslation(), r = n.getRotation(), s = n.getScale();
  const parts = [`${'  '.repeat(depth)}- ${n.getName() || '(unnamed)'} [${kind}]`];
  if (t.some(Boolean)) parts.push(`at ${v3(t)}`);
  if (r[3] < 0.99999) parts.push(`rot ${v3(deg(r))}`);
  if (s.some(x => Math.abs(x - 1) > 1e-6)) parts.push(`scale ${v3(s)}`);
  parts.push(`world ${v3(new THREE.Vector3().setFromMatrixPosition(wm(n)).toArray())}`);
  if (n.getMesh()) {
    const b = nodeBox(n), sz = b.getSize(new THREE.Vector3());
    const mats = [...new Set(n.getMesh().listPrimitives().map(p => p.getMaterial()?.getName() || '-'))];
    parts.push(`size ${f2(sz.x)}x${f2(sz.y)}x${f2(sz.z)}`, `${n.getMesh().listPrimitives().reduce((a, p) => a + tris(p), 0)} tris`, `mat ${mats.join('+')}`);
  }
  if (Object.keys(n.getExtras() || {}).length) parts.push(`extras ${JSON.stringify(n.getExtras())}`);
  out.push(parts.join('  '));
  n.listChildren().forEach(c => walk(c, depth + 1));
}
scene.listChildren().forEach(n => walk(n, 1));
if (root.listMaterials().length) {
  out.push('materials:');
  for (const m of root.listMaterials()) {
    const tex = m.getBaseColorTexture(), img = tex?.getSize();
    out.push(`  - ${m.getName() || '(unnamed)'}: ${hex(m.getBaseColorFactor())} rough ${f2(m.getRoughnessFactor())} metal ${f2(m.getMetallicFactor())}${tex ? ` map ${tex.getName() || 'texture'} ${img ? img.join('x') : '?'}` : ''}${m.getAlphaMode() !== 'OPAQUE' ? ' ' + m.getAlphaMode() : ''}`);
  }
}
for (const s of root.listSkins()) out.push(`skin ${s.getName() || '(unnamed)'}: skeleton ${s.getSkeleton()?.getName() ?? '-'}, joints [${s.listJoints().map(j => j.getName()).join(', ')}]`);
if (root.listAnimations().length) {
  out.push('clips:');
  for (const a of root.listAnimations()) {
    const dur = Math.max(0, ...a.listSamplers().map(s => s.getInput().getMax([])[0]));
    const loop = a.getExtras()?.loop ? ' loop' : '';
    const tr = a.listChannels().map(c => `${c.getTargetNode()?.getName()}.${c.getTargetPath()}(${c.getSampler().getInput().getCount()}${c.getSampler().getInterpolation() === 'LINEAR' ? '' : ' ' + c.getSampler().getInterpolation()})`);
    out.push(`  - ${a.getName() || '(unnamed)'} ${f2(dur)}s${loop}: ${tr.join(', ')}`);
  }
}
if (attrN) {
  out.push(`attributes (first ${attrN} vertices; getElement handles stride/normalization):`);
  for (const mesh of root.listMeshes()) for (const [pi, p] of mesh.listPrimitives().entries()) {
    out.push(`  ${mesh.getName() || 'mesh'}#${pi}: ${p.getAttribute('POSITION')?.getCount()} verts, ${p.getIndices() ? p.getIndices().getCount() + ' indices' : 'not indexed'}, material ${p.getMaterial()?.getName() || '-'}`);
    for (const sem of p.listSemantics()) {
      const a = p.getAttribute(sem), rows = [];
      for (let i = 0; i < Math.min(attrN, a.getCount()); i++) rows.push('[' + a.getElement(i, []).map(f2).join(',') + ']');
      out.push(`    ${sem} (${a.getType()} ${a.getComponentType()}${a.getNormalized() ? ' normalized' : ''}): ${rows.join(' ')}`);
    }
    if (p.getIndices()) out.push(`    indices: ${Array.from(p.getIndices().getArray().slice(0, attrN * 3)).join(',')}`);
  }
}
console.log(out.join('\n'));
