// Template: low-poly animal rigged with NODES (no skin). Each moving part hangs from a pivot node placed at its joint,
// and clips rotate those pivots. Cheaper and more robust than skinning; use it unless one surface must bend.
// Run: node pig.model.mjs. Origin bottom-center, +Y up, faces +Z (so +X is the animal's LEFT), meters.
import { model } from '../scripts/kit.mjs'; // in a copy: absolute path to glb-author/scripts/kit.mjs

const m = model('pig');

// proportions first
const BODY = [0.5, 0.42, 0.8], LEG_H = 0.24, LEG_W = 0.11, BODY_Y = LEG_H + BODY[1] / 2;
const HIP_X = BODY[0] / 2 - LEG_W / 2 - 0.02, HIP_Z = BODY[2] / 2 - LEG_W / 2 - 0.04;
const PINK = '#f2a7b5', DARK = '#c9798a';

m.part('body', m.box(...BODY), { at: [0, BODY_Y, 0], color: PINK });

// head pivots at the neck (front-top of the body) so a bob rotates around the neck, not the head center
const neck = m.group('neck', { parent: 'body', at: [0, 0.06, BODY[2] / 2] });
m.part('head', m.box(0.36, 0.32, 0.3), { parent: neck, anchor: 'back', color: PINK });
m.part('snout', m.box(0.18, 0.12, 0.08), { parent: 'head', at: [0, -0.04, 0.3], anchor: 'back', color: DARK });
for (const s of [1, -1]) {
  const side = s > 0 ? 'L' : 'R';
  m.part(`ear_${side}`, m.cone(0.06, 0.12, 4), { parent: 'head', at: [s * 0.12, 0.2, 0.08], rot: [0, 0, -s * 20], color: DARK });
  m.part(`eye_${side}`, m.box(0.04, 0.05, 0.02), { parent: 'head', at: [s * 0.1, 0.06, 0.3], anchor: 'back', color: '#1a1a1a' });
}
m.socket('Socket_Hat', { parent: 'head', at: [0, 0.16, 0.15] });

// legs: pivot ('hip_*') at the top of the leg, mesh hangs below it (anchor 'top')
for (const [id, x, z] of [['FL', 1, 1], ['FR', -1, 1], ['BL', 1, -1], ['BR', -1, -1]]) {
  const hip = m.group(`hip_${id}`, { parent: 'body', at: [x * HIP_X, -BODY[1] / 2, z * HIP_Z] });
  m.part(`leg_${id}`, m.box(LEG_W, LEG_H, LEG_W), { parent: hip, anchor: 'top', color: PINK });
  m.part(`hoof_${id}`, m.box(LEG_W + 0.01, 0.04, LEG_W + 0.01), { parent: hip, at: [0, -LEG_H + 0.02, 0], color: '#6b4a3a' });
}
const tail = m.group('tail', { parent: 'body', at: [0, 0.12, -BODY[2] / 2] });
m.part('tail_tip', m.box(0.04, 0.04, 0.1), { parent: tail, anchor: 'front', color: DARK });

// Walk: diagonal pairs swing together (FL with BR, FR with BL), half a cycle apart. Body bobs twice per step cycle.
const SWING = 28, D = 0.8;
m.clip('Walk', { duration: D, loop: true }, {
  hip_FL: { rot: m.wave([SWING, 0, 0], { phase: 0 }) },
  hip_BR: { rot: m.wave([SWING, 0, 0], { phase: 0 }) },
  hip_FR: { rot: m.wave([SWING, 0, 0], { phase: 0.5 }) },
  hip_BL: { rot: m.wave([SWING, 0, 0], { phase: 0.5 }) },
  neck: { rot: m.wave([4, 0, 0], { phase: 0.25 }) },
  tail: { rot: m.wave([0, 30, 0], { phase: 0 }) },
});
// Idle: legs still (not listed), head looks down and back up, tail flicks. Keys are offsets from the rest pose.
m.clip('Idle', { duration: 2.4, loop: true }, {
  neck: { rot: [[0, [0, 0, 0]], [0.8, [18, 0, 0]], [1.4, [18, 0, 0]], [2.4, [0, 0, 0]]] },
  tail: { rot: m.wave([0, 40, 0], { keys: 12 }) },
});

await m.write(new URL('./pig.glb', import.meta.url).pathname);
