// Writes broken.glb: a skinned column with the classic silent defects, for the repair eval and for testing validate.
// Defects: dotted bone name, skinned mesh under a parent with a transform, weights summing to 0.8, joints used with
// zero weight, no NORMAL on the box, an inside-out (reversed winding) box, and a socket deleted by a default prune().
import { Document, NodeIO } from '@gltf-transform/core';
import { prune } from '@gltf-transform/functions';
import * as THREE from 'three';

const doc = new Document(), buf = doc.createBuffer();
const acc = (type, a) => doc.createAccessor().setType(type).setArray(a).setBuffer(buf);
const mat = doc.createMaterial('red').setBaseColorFactor([0.8, 0.1, 0.1, 1]);

// column: 4 rings x 4 verts, 2 bones
const pos = [], J = [], W = [], idx = [];
for (let r = 0; r <= 3; r++) for (const [x, z] of [[-0.2, -0.2], [0.2, -0.2], [0.2, 0.2], [-0.2, 0.2]]) {
  const y = r * 0.6, w1 = Math.min(1, Math.max(0, (y - 0.5) / 1.0));
  pos.push(x, y, z); J.push(0, 1, 0, 0); W.push((1 - w1) * 0.8, w1 * 0.8, 0, 0); // sums to 0.8; joint 1 kept even at weight 0
}
for (let r = 0; r < 3; r++) for (let s = 0; s < 4; s++) { const a = r * 4 + s, b = r * 4 + (s + 1) % 4; idx.push(a, a + 4, b, b, a + 4, b + 4); }
const col = doc.createPrimitive().setMaterial(mat)
  .setAttribute('POSITION', acc('VEC3', new Float32Array(pos)))
  .setAttribute('NORMAL', acc('VEC3', new Float32Array(pos.length).map((_, i) => (i % 3 === 1 ? 0 : pos[i] * 5))))
  .setAttribute('JOINTS_0', acc('VEC4', new Uint8Array(J))).setAttribute('WEIGHTS_0', acc('VEC4', new Float32Array(W)))
  .setIndices(acc('SCALAR', new Uint16Array(idx)));
const rig = doc.createNode('Rig').setTranslation([0, 0.1, 0]);
const b0 = doc.createNode('Bone.Base'), b1 = doc.createNode('Bone.Top').setTranslation([0, 1, 0]);
b0.addChild(b1); rig.addChild(b0);
const ibm = new Float32Array(32);
new THREE.Matrix4().makeTranslation(0, -0.1, 0).toArray(ibm, 0); new THREE.Matrix4().makeTranslation(0, -1.1, 0).toArray(ibm, 16);
const skin = doc.createSkin('skin').addJoint(b0).addJoint(b1).setSkeleton(b0).setInverseBindMatrices(acc('MAT4', ibm));
rig.addChild(doc.createNode('Column').setMesh(doc.createMesh('Column').addPrimitive(col)).setSkin(skin));

// box with no normals and reversed winding
const g = new THREE.BoxGeometry(0.5, 0.5, 0.5).translate(0.8, 0.25, 0);
const bi = Array.from(g.index.array); for (let i = 0; i < bi.length; i += 3) [bi[i + 1], bi[i + 2]] = [bi[i + 2], bi[i + 1]];
const box = doc.createPrimitive().setMaterial(mat).setAttribute('POSITION', acc('VEC3', new Float32Array(g.attributes.position.array))).setIndices(acc('SCALAR', new Uint16Array(bi)));
rig.addChild(doc.createNode('Crate').setMesh(doc.createMesh('Crate').addPrimitive(box)));

// socket that a default prune() deletes
b1.addChild(doc.createNode('Socket_Hat').setTranslation([0, 0.3, 0]).setExtras({ socket: true }));
const wave = doc.createAnimation('Wave');
const t = acc('SCALAR', new Float32Array([0, 1])), q = acc('VEC4', new Float32Array([0, 0, 0, 1, 0, 0, 0, 1]));
const smp = doc.createAnimationSampler().setInput(t).setOutput(q);
wave.addSampler(smp).addChannel(doc.createAnimationChannel().setTargetNode(b1).setTargetPath('rotation').setSampler(smp));
doc.createScene('Scene').addChild(rig);
await doc.transform(prune());
await new NodeIO().write(new URL('./broken.glb', import.meta.url).pathname, doc);
console.log('wrote broken.glb');
