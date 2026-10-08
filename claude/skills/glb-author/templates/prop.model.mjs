// Template: rigid multi-part prop with pivoted moving parts, sockets, a generated texture and a node-animation clip.
// Copy next to the game's models, rename, and edit. Run: node wagon.model.mjs
// Origin bottom-center, +Y up, front (the hitch) faces +Z, meters.
import { model } from '../scripts/kit.mjs'; // in a copy: absolute path to glb-author/scripts/kit.mjs

const m = model('wagon');

// numbers first: every placement below derives from these
const L = 2.4, W = 1.3, BED_Y = 0.55, BED_T = 0.08, WHEEL_R = 0.32, WHEEL_W = 0.1, AXLE_Z = 0.75;

// a planks texture: dark lines across a warm wood color (u along the plank, v across)
const planks = m.texture('planks', { width: 64, height: 64, pixel: (u, v) => {
  const seam = (v * 6) % 1 < 0.08, grain = 0.92 + 0.08 * Math.sin(u * 40 + v * 7);
  return seam ? [70, 45, 25] : [176 * grain, 124 * grain, 74 * grain];
} });

m.part('bed', m.box(W, BED_T, L), { at: [0, BED_Y, 0], anchor: 'bottom', map: planks, color: '#ffffff' });
for (const s of [-1, 1]) m.part(`side_${s < 0 ? 'L' : 'R'}`, m.box(0.06, 0.35, L), { at: [s * (W / 2 - 0.03), BED_Y + BED_T, 0], anchor: 'bottom', color: '#8b5a2b' });
m.part('tailboard', m.box(W, 0.35, 0.06), { at: [0, BED_Y + BED_T, -L / 2 + 0.03], anchor: 'bottom', color: '#8b5a2b' });

// +X is the wagon's LEFT (it faces +Z), so FL = front-left = +X, +Z
// wheels: each wheel is its own node with its origin ON the axle, so rotating x spins it in place
// tire sides: a multiple of 4 so a corner (not a flat side) touches the ground when the cylinder lies along X
for (const [id, x, z] of [['FL', 1, 1], ['FR', -1, 1], ['BL', 1, -1], ['BR', -1, -1]]) {
  const hub = m.group(`wheel_${id}`, { at: [x * (W / 2 + WHEEL_W / 2 + 0.01), WHEEL_R, z * AXLE_Z] });
  m.part(`tire_${id}`, m.cyl(WHEEL_R, WHEEL_R, WHEEL_W, 12), { parent: hub, geoRot: [0, 0, 90], color: '#3a3a3a' });
  m.part(`hubcap_${id}`, m.cyl(0.08, 0.08, WHEEL_W + 0.02, 8), { parent: hub, geoRot: [0, 0, 90], color: '#b0a080' });
  // ONE mark makes the spin visible: a round wheel (or a symmetric cross) looks the same in many animation frames
  m.part(`mark_${id}`, m.box(WHEEL_W + 0.02, WHEEL_R * 0.5, 0.06), { parent: hub, at: [0, WHEEL_R * 0.6, 0], color: '#c03020' });
}
m.part('axle_F', m.cyl(0.03, 0.03, W + 0.2, 6), { at: [0, WHEEL_R, AXLE_Z], geoRot: [0, 0, 90], color: '#555555' });
m.part('axle_B', m.cyl(0.03, 0.03, W + 0.2, 6), { at: [0, WHEEL_R, -AXLE_Z], geoRot: [0, 0, 90], color: '#555555' });
m.beam('tongue', [0, WHEEL_R, L / 2], [0, WHEEL_R, L / 2 + 0.9], { size: [0.08, 0.06], color: '#8b5a2b' }); // bar from point A to point B

// sockets: empty nodes the game finds with getObjectByName
m.socket('Socket_Hitch', { at: [0, WHEEL_R, L / 2 + 0.9] });
m.socket('Socket_Load', { at: [0, BED_Y + BED_T, 0] });

// wheels roll forward (+Z) => rotate +X. 0 -> 360 is one loopable turn (the kit adds keys every 90 deg so slerp can't shortcut)
const roll = { rot: [[0, [0, 0, 0]], [1, [360, 0, 0]]] };
m.clip('Roll', { duration: 1, loop: true }, { wheel_FL: roll, wheel_FR: roll, wheel_BL: roll, wheel_BR: roll });

await m.write(new URL('./wagon.glb', import.meta.url).pathname);
