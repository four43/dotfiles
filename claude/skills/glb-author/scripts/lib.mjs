// Shared helpers for inspect.mjs / validate.mjs / look.mjs.
import fs from 'node:fs';
import path from 'node:path';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';

export { THREE };
export const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
export const NAME = /^[A-Za-z0-9_-]+$/;
export const f2 = v => (Math.abs(v) < 5e-4 ? 0 : +v.toFixed(3));
export const v3 = a => `(${a.map(f2).join(', ')})`;

export async function readDoc(file) { return io.read(file); }

/** Spec next to the GLB: foo.glb -> foo.spec.json (or an explicit path). */
export function findSpec(file, explicit) {
  const p = explicit ?? path.join(path.dirname(file), path.basename(file, path.extname(file)) + '.spec.json');
  return fs.existsSync(p) ? { path: p, spec: JSON.parse(fs.readFileSync(p, 'utf8')) } : null;
}

export const wm = node => new THREE.Matrix4().fromArray(node.getWorldMatrix());

/** World-space bbox of one mesh node (rest pose), from accessor min/max. */
export function nodeBox(node) {
  const box = new THREE.Box3();
  const mesh = node.getMesh(); if (!mesh) return box;
  const m = node.getSkin() ? new THREE.Matrix4() : wm(node); // skinned verts are already in bind/world space
  for (const p of mesh.listPrimitives()) {
    const a = p.getAttribute('POSITION'); if (!a) continue;
    const v = new THREE.Vector3(), el = []; // every vertex: a rotated part's corner-transformed box would be too big
    for (let i = 0; i < a.getCount(); i++) box.expandByPoint(v.fromArray(a.getElement(i, el)).applyMatrix4(m));
  }
  return box;
}

export function sceneBox(doc) {
  const box = new THREE.Box3();
  for (const n of doc.getRoot().listNodes()) if (n.getMesh()) box.union(nodeBox(n));
  return box;
}

export function tris(prim) {
  if (prim.getMode() !== 4) return 0;
  return (prim.getIndices()?.getCount() ?? prim.getAttribute('POSITION').getCount()) / 3;
}

/** Triangles drawn: every mesh node counts, so 4 wheels sharing one mesh count 4 times. */
export function drawnTris(doc) {
  let t = 0; for (const n of doc.getRoot().listNodes()) for (const p of n.getMesh()?.listPrimitives() ?? []) t += tris(p); return t;
}

export const hex = f => '#' + new THREE.Color().setRGB(f[0], f[1], f[2]).getHexString();

/** Load into three.js in Node. Textures are stripped first (Node has no image decoder). */
export async function loadThree(file) {
  const doc = await io.read(file);
  for (const t of doc.getRoot().listTextures()) t.dispose();
  const glb = await io.writeBinary(doc);
  const gltf = await new GLTFLoader().parseAsync(glb.buffer.slice(glb.byteOffset, glb.byteOffset + glb.byteLength), '');
  gltf.scene.updateMatrixWorld(true);
  return gltf;
}

/** World bbox of everything renderable in a posed three.js scene (skinned meshes use their bones). */
export function posedBox(scene) {
  const box = new THREE.Box3();
  scene.updateMatrixWorld(true);
  scene.traverse(o => {
    if (!o.isMesh) return;
    if (o.isSkinnedMesh) { o.skeleton.update(); o.computeBoundingBox(); box.union(o.boundingBox.clone().applyMatrix4(o.matrixWorld)); }
    else box.expandByObject(o, true); // precise: a rotated wheel's AABB-of-AABB would poke below ground
  });
  return box;
}

/** Closest names for "did you mean". */
export function nearest(name, names) {
  const d = (a, b) => { a = a.toLowerCase(); b = b.toLowerCase(); const m = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]); for (let j = 1; j <= b.length; j++) m[0][j] = j; for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) m[i][j] = Math.min(m[i - 1][j] + 1, m[i][j - 1] + 1, m[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)); return m[a.length][b.length]; };
  return names.map(n => [n, d(name, n)]).sort((a, b) => a[1] - b[1]).slice(0, 2).filter(([, s]) => s <= Math.max(3, name.length / 2)).map(([n]) => n);
}

/**
 * UV stretch of a triangle primitive: for each triangle, the singular values of its 3D -> UV map; stretch = max/min
 * (1 = squares stay squares, Infinity = the triangle collapses to a line in UV). Returns the area fraction above
 * `limit` and the worst value. Scale doesn't count: a part textured at half density is not stretched.
 */
export function uvStretch(prim, limit = 3) {
  const P = prim.getAttribute('POSITION'), U = prim.getAttribute('TEXCOORD_0'), I = prim.getIndices();
  const n = I ? I.getCount() : P.getCount(), idx = k => (I ? I.getScalar(k) : k);
  let total = 0, over = 0, worst = 1;
  for (let k = 0; k + 2 < n; k += 3) {
    const [a, b, c] = [idx(k), idx(k + 1), idx(k + 2)], p0 = P.getElement(a, []);
    const e1 = P.getElement(b, []).map((x, i) => x - p0[i]), e2 = P.getElement(c, []).map((x, i) => x - p0[i]);
    const l1 = Math.hypot(...e1), area2 = Math.hypot(e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]);
    if (area2 < 1e-12 || l1 < 1e-9) continue;
    const bx = (e1[0] * e2[0] + e1[1] * e2[1] + e1[2] * e2[2]) / l1, by = area2 / l1; // triangle flattened: (0,0) (l1,0) (bx,by)
    const q0 = U.getElement(a, []), q1 = U.getElement(b, []), q2 = U.getElement(c, []);
    const d1 = [q1[0] - q0[0], q1[1] - q0[1]], d2 = [q2[0] - q0[0], q2[1] - q0[1]];
    const J = [d1[0] / l1, (d2[0] - d1[0] * bx / l1) / by, d1[1] / l1, (d2[1] - d1[1] * bx / l1) / by];
    const E = J[0] ** 2 + J[2] ** 2, F = J[0] * J[1] + J[2] * J[3], G = J[1] ** 2 + J[3] ** 2, r = Math.hypot(E - G, 2 * F);
    const smax = Math.sqrt((E + G + r) / 2), smin = Math.sqrt(Math.max(0, (E + G - r) / 2));
    const s = smin > 1e-9 * smax ? smax / smin : Infinity;
    total += area2; if (s > limit) over += area2; worst = Math.max(worst, s);
  }
  return { over: total ? over / total : 0, worst };
}
