// Template: ONE continuous skinned mesh bent by bones, plus rigid parts parented to bones, a socket on a bone,
// and a looping clip. Use skinning only when a surface must bend smoothly (torso, tail, tentacle, flag).
// Run: node scarecrow.model.mjs. Origin bottom-center, +Y up, faces +Z (+X is its LEFT), meters.
import { model } from '../scripts/kit.mjs'; // in a copy: absolute path to glb-author/scripts/kit.mjs

const m = model('scarecrow');
const POST_H = 1.25, HIP_Y = 0.95, CHEST_Y = 1.2, SHOULDER_Y = 1.36, ARM_L = 0.65;

m.part('post', m.cyl(0.05, 0.06, POST_H, 6), { anchor: 'bottom', color: '#6b4a2b' });

// bones: plain nodes at the joints. Bone order in `bones:` below must start with the root bone.
m.bone('Spine', { at: [0, HIP_Y, 0] });
m.bone('Chest', { parent: 'Spine', world: [0, CHEST_Y, 0] });
m.bone('Arm_L', { parent: 'Chest', world: [0.2, SHOULDER_Y, 0] });  // +X = its left
m.bone('Arm_R', { parent: 'Chest', world: [-0.2, SHOULDER_Y, 0] });

// the skinned body: pieces are in WORLD space at the rest pose. Extra segments where it bends.
m.skinned('body', [
  { geo: m.box(0.4, 0.5, 0.22, [1, 6, 1]), world: [0, HIP_Y, 0], anchor: 'bottom' },             // torso
  { geo: m.box(ARM_L, 0.12, 0.12, [8, 1, 1]), world: [0.2, SHOULDER_Y, 0], anchor: 'left' },     // left arm, out along +X
  { geo: m.box(ARM_L, 0.12, 0.12, [8, 1, 1]), world: [-0.2, SHOULDER_Y, 0], anchor: 'right' },   // right arm, out along -X
], { bones: ['Spine', 'Chest', 'Arm_L', 'Arm_R'], weights: 'smooth', blend: 0.12, color: '#4a6fa5' });

// rigid parts ride on bones: parent them to the bone node
m.part('head', m.sphere(0.14, 8, 6), { parent: 'Chest', world: [0, SHOULDER_Y + 0.2, 0], color: '#e8d6a0' });
const straw = m.texture('straw', { width: 32, height: 32, pixel: (u, v) => { const s = 0.8 + 0.2 * Math.sin(u * 60) * Math.sin(v * 9); return [222 * s, 190 * s, 90 * s]; } });
m.part('hat', m.cone(0.26, 0.2, 10), { parent: 'head', at: [0, 0.12, 0], anchor: 'bottom', map: straw });
m.socket('Socket_Perch', { parent: 'Arm_L', world: [0.2 + ARM_L - 0.05, SHOULDER_Y + 0.06, 0] });

// Wave: right arm swings up and down twice (about Z, in its own frame), torso sways. Offsets from rest, in degrees.
m.clip('Wave', { duration: 2, loop: true }, {
  Arm_R: { rot: [[0, [0, 0, 0]], [0.5, [0, 0, -60]], [1, [0, 0, -20]], [1.5, [0, 0, -60]], [2, [0, 0, 0]]] },
  Chest: { rot: m.wave([0, 0, 6], { phase: 0.25 }) },
  Spine: { rot: m.wave([0, 4, 0]) },
});

await m.write(new URL('./scarecrow.glb', import.meta.url).pathname);
