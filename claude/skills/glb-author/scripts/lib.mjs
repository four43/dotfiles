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
