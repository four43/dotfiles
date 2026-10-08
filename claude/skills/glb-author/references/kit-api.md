# kit.mjs API

`import { model, png, THREE, io } from '<abs path>/glb-author/scripts/kit.mjs'`

`model(name, { flat = true })`. `flat: true` un-welds vertices for faceted low-poly shading. `flat: false` keeps smooth normals from three.js geometry; use it for round, smooth things.

## Shapes

All shapes are centered on the origin before `anchor` moves them. They are three.js `BufferGeometry`, so any three.js geometry works (`new m.THREE.TorusKnotGeometry(...)`), and so does `geo.scale/rotateX/translate` before passing it in.

| Call | Notes |
|---|---|
| `box(w, h, d, seg=[1,1,1])` | `seg` = segments along x,y,z. Add some where a skinned box bends |
| `cyl(rTop, rBottom, h, sides=8, hSeg=1)` | axis = Y. Lay along X with `geoRot:[0,0,90]`, along Z with `geoRot:[90,0,0]` |
| `cone(r, h, sides=8)` | tip at +Y |
| `sphere(r, w=8, h=6)` | |
| `torus(r, tube, radial=6, tubular=12, arcDeg=360)` | ring in the XY plane |
| `lathe([[radius, y], ...], sides=8)` | profile bottom→top, spun around Y. Vases, barrels, bottles, tree trunks |
| `extrude([[x, y], ...], depth, bevel=0)` | outline in XY, extruded along +Z. Signs, gables, silhouettes |
| `wedge(w, h, d)` | ramp: full height at +Z, zero at −Z |

Shapes are three.js geometries, so `.scale(x, y, z)`, `.rotateY(rad)` and `.translate()` chain before `part()`.

- **Open tub, tray or bin:** `m.lathe([[0.30, 0], [0.42, 0.25]], 4).rotateY(Math.PI / 4).scale(1.2, 1, 0.8)` makes a square-section tapered tub. Add a floor box, or a profile point at radius 0 (the kit drops the degenerate triangles that point makes).
- **Cylinder lying on its side:** use `sides` as a multiple of 4 so a corner, not a flat, touches the ground.

## beam

`m.beam(name, a, b, { size = 0.04 | [w, d], round, sides, parent, color, ... })` draws a bar from world point `a` to world point `b`. Its node origin is at `a` and its local +Y points at `b`, so it can pivot at `a`. Any `part` material option works.

## Part options (`part`, `group`, `socket`, `bone`)

| Option | Meaning |
|---|---|
| `parent` | node or name (default: the model root) |
| `at: [x,y,z]` | translation in the parent's frame |
| `world: [x,y,z]` | world position at rest; converted to parent-local (translation only) |
| `rot: [x,y,z]` | node rotation in degrees (XYZ euler). Rotates children too |
| `scale: n \| [x,y,z]` | node scale. Prefer sizing the shape instead; skins dislike scaled nodes |
| `extras: {}` | copied to `userData` in three.js |

`part` only:

| Option | Meaning |
|---|---|
| `anchor` | which bbox point of the shape sits at the node origin (pivot): `center` `bottom` `top` `front` (+Z) `back` (−Z) `left` (−X) `right` (+X), or `none` (no re-centering). These are bbox sides on the axis, not the model's left/right. Rule: anchor = the side that touches the joint |
| `offset: [x,y,z]` | extra shift of the shape relative to the pivot |
| `geoRot: [x,y,z]` | rotate the shape (not the node) in degrees, before anchoring |
| `color: '#hex'` | sRGB hex. The kit converts it to the linear factor glTF wants. Same color = shared material |
| `map: texture` | from `m.texture`. Keep `color: '#ffffff'` so the texture isn't tinted |
| `roughness`, `metalness`, `opacity` (<1 → BLEND), `unlit`, `doubleSided` | material settings. `doubleSided` for single planes (leaves, flags, paper) |
| `material` | a material from `m.material(name, opts)` to share by name |

## Textures

- `m.texture(name, { width, height, pixel: (u, v, x, y) => [r, g, b, a?] })` builds a PNG. Values are 0–255 and `v = 0` is the top row.
- `{ file: 'path.png' }` loads a PNG from disk; `{ image: Uint8Array }` uses raw bytes.
- Use powers of two (16–256 is plenty for low poly).
- Shapes come with three.js UVs:
  - Box faces each map 0..1.
  - Cylinders, cones and lathes: u runs around the axis, starting at +Z (u=0, the seam) and turning toward +X. v runs along the axis, v=0 at the bottom.
  - After `geoRot` the seam turns with the shape: `[90,0,0]` puts it underneath. That's handy for a belly stripe: color `u` near 0 or 1.
- For a repeating pattern, use more cells inside the pixel function rather than texture repeat.

## Skinning

`m.bone(name, opts)` makes joints. `m.skinned(name, pieces, opts)`:

- `pieces: [{ geo, world: [x,y,z], anchor, geoRot }]` are in the **world rest pose**. They are merged into one mesh.
- `bones: ['Root', ...]`: all joints that may influence it. The first one is the skeleton root.
- `weights`:
  - `'smooth'` (default) blends between the nearest bone segments within `blend` meters (default 0.15).
  - `'rigid'` gives each vertex to its nearest bone.
  - A function `([x,y,z]) => ({ Spine: 0.7, Chest: 0.3 })` gives explicit weights.
- Bone segments run from a bone's head to its children's heads. A leaf bone extends 40% of its parent link.
- Rigid parts that should follow a bone (head, hat, hand) are ordinary `m.part`s with `parent: '<bone>'`.

## Clips

`m.clip(name, { duration, loop }, { nodeName: { rot, pos, scale, interp } })`:

- Each channel is `[[time, [x, y, z]], ...]` or `m.wave(amp, { phase = 0, cycles = 1, abs = false, keys = 8*cycles, offset = [0,0,0] })`.
- Repeated keys hold a pose (e.g. `[[0.4,[0,0,18]],[0.9,[0,0,18]]]`).
- Travelling wave down a chain of bones `b0` (head) … `bn`: `{ [b_i]: { rot: m.wave([0, A_i, 0], { phase: -i * 0.12 }) } }`. Grow `A_i` toward the tail.
- Offsets are from the node's rest pose:
  - `rot`: degrees applied in the node's own frame after its rest rotation.
  - `pos`: meters added.
  - `scale`: multiplier.
- `interp: 'STEP'` for snappy motion; the default is `LINEAR`.
- `loop: true` requires keys at 0 and `duration` with the same pose. For rot, 0° and 360° count as the same, so `[[0,[0,0,0]],[1,[360,0,0]]]` is a loopable spin. It's stored as clip `extras.loop`, and validate checks the seam.
- Clips should animate only nodes that move in them. three.js keeps the last pose of a node no clip touches, so when switching clips, make sure every clip that matters resets the nodes the others move (see game-code.md).

## Escape hatches

- `m.doc` is the glTF-Transform `Document` and `m.node(name)` is its `Node`. Use them for anything the kit lacks: morph targets (`doc.createPrimitiveTarget()` + `prim.addTarget`, animate path `weights`), cameras, lights (KHR_lights_punctual), extra UV sets.
- `m.material(name, opts)` makes a named shared material.
- `m.root` and `m.scene` are the root node and the scene. The scene is named `Scene` on purpose: if it shared the model's name, three.js would rename the root to `name_1`.
- Any glTF-Transform function can run before `write`: `await m.doc.transform(fn())`. Avoid `prune()` without `{ keepLeaves: true }`, and avoid `weld()` on flat-shaded models.
