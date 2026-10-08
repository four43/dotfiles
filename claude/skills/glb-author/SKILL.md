---
name: glb-author
description: Use when making, rigging, animating, editing, fixing or inspecting a 3D model, .glb or .gltf asset for three.js or a web game (props, vehicles, animals, characters, buildings), including multi-mesh hierarchies, pivots, attachment sockets/empties, textures, bones/skins and animation clips, or when a GLB loads wrong (renders black or inside-out, nodes renamed, clips not playing, sockets missing, model floating or facing backwards).
---

# glb-author

Treat the GLB as **compiled output**. The source is a `<name>.model.mjs` script that builds the model with the kit (three.js shapes + glTF-Transform). Every build is checked twice:

- **Scripts check the facts:** names, weights, normals, size, track bindings, loop seams, ground contact.
- **You check the look in rendered PNGs:** silhouette, proportions, whether the motion reads.

Writing code that runs is easy. What goes wrong is spatial: floating or misaligned parts, wrong axes, pivots in the wrong place. Plus glTF defects that load with no error. So validate before you look, and look before you call it done.

**Related:** to load the model into a game, see `references/game-code.md`. For Rapier physics and Kenney kits, use the `web-3d-game` skill.

## Setup (once per machine)

`SKILL` below means the directory containing this file.

```bash
cd "$SKILL" && [ -d node_modules ] || npm install
```

Chromium comes from Playwright's cache. If look.mjs says no Chromium was found, run `npx playwright install chromium-headless-shell` in `$SKILL`.

## Conventions (every model)

- **Units:** meters.
- **Axes:** +Y up. The model's **front faces +Z**, so **+X is the model's LEFT**.
- **Origin:** bottom-center. The lowest point sits at y=0, centered in x and z.
- **Names:** `A-Z a-z 0-9 _ -` only, and unique. three.js strips `. : / [ ]` and spaces, so `Arm.L` becomes `ArmL` and lookups and clips break. Use `Arm_L`, `wheel_FL`, `Socket_Hitch`.
- **Pivots:** every part that moves is (or hangs from) a node whose **origin is the joint**: hinge, axle, hip, neck. Animation rotates that node. `anchor` = **the side of the shape that touches the joint**: a leg hanging from a hip is `'top'`, a tail sticking out the back is `'front'`, a lid hinged at its back edge is `'back'`.
- **Sockets:** empty nodes named `Socket_<Thing>`, made with `m.socket()`. Game code finds them with `getObjectByName`.
- **Rigging:** rigid parts → node rig, no skin (wheels, doors, arms, most low-poly animals). Skin only when one continuous surface must bend.
- **Colors:** flat material colors per part. Texture only when asked for, or when a pattern is needed (planks, straw, a face).
- **Shading:** `model(name)` is faceted low-poly. Use `model(name, { flat: false })` for smooth round things (snakes, fruit, skinned tubes).

## Workflow

Copy this checklist and track it:

```
- [ ] 1 SPEC   write <name>.spec.json (numbers + visual checks) BEFORE any code
- [ ] 2 BUILD  write <name>.model.mjs from a template; node <name>.model.mjs
- [ ] 3 CHECK  node $SKILL/scripts/validate.mjs <name>.glb   -> fix until PASS
- [ ] 4 LOOK   node $SKILL/scripts/look.mjs <name>.glb (+ --sheet diag, + --sheet anim per clip); Read every PNG
- [ ] 5 JUDGE  answer each spec check Yes/No/Unclear citing a tile; fix Nos at node level; repeat 2-5
- [ ] 6 HAND OFF  publish the showcase viewer, list kept WARNs with reasons, give the game-code snippet
```

**Pass order:**
1. **Blockout:** parts, names, pivots, sockets and size.
2. **Form and color.**
3. **Clips.**

For a small asset (under ~20 parts), build all three at once, then judge them in that order. For bigger ones, get the blockout's geo sheet right before adding detail.

**Loop caps:**
- `validate` failures: loop freely, up to 5 builds per pass. The messages say exactly what to fix.
- Visual fixes (a "No" in step 5): at most **3 per pass and 6 in total**. At the cap, stop and show the user the current sheets with the open Nos. Don't keep polishing.

**Edits stay local.** Change the named part and rebuild; never regenerate the whole script. `look.mjs` keeps the previous render as `*-prev.png`, one version back. To keep a baseline across several rebuilds, render it once with `--out before.png`. Read both before you claim a fix worked.

## 1. Spec (`<name>.spec.json`, next to the GLB)

```json
{
  "title": "Hay wagon",
  "description": "Four-wheel farm wagon: wheels spin on axle pivots, hitch socket at the tongue tip, load socket on the bed.",
  "size": [1.3, 1.0, 2.4],
  "tolerance": 0.1,
  "grounded": true,
  "nodes": ["bed", "wheel_FL", "wheel_FR", "wheel_BL", "wheel_BR"],
  "sockets": ["Socket_Hitch"],
  "contacts": ["tire_FL", "tire_FR", "tire_BL", "tire_BR"],
  "clips": { "Roll": { "duration": 1, "loop": true, "moves": ["wheel_FL"] } },
  "budget": { "tris": 3000, "materials": 8, "textureSize": 256, "kb": 300 },
  "checks": [
    "FRONT tile: the hitch tongue points toward the camera",
    "LEFT tile: four wheels touch the grid line, none float",
    "3/4 tile: the bed has side boards on both sides and a tailboard at the back",
    "anim Roll: the red rim mark is at a different angle in every frame"
  ]
}
```

- Work out `size` from the numbers you plan to build with (wheel radius, body height, …), not by guessing.
- `size` is the x, y, z extent in meters.
- `contacts` lists parts that must touch y=0: wheels, feet, legs. The model-wide ground check passes if *anything* touches, so a wheel can float 5 mm unnoticed without this.
- `tolerance` is a **fraction** of each axis (0.1 = ±10%). It can be one number or `[x, y, z]`, and is never tighter than 1 cm.
- `checks` are yes/no questions written **before** you render. Name the tile each one is judged from, and make each one observable.
- Side tiles are mirror images of each other. The tile label says where the front is (`front is <-`), so phrase checks with "front end" and "back end", not screen left or right.
- Undersides need `--view bottom`.
- `validate.mjs` reads `<name>.spec.json` automatically, or `--spec <file>` when the names differ (e.g. repairing `broken.glb` into `fixed.glb`). It fails on size, missing nodes, sockets or clips, clip duration, `moves`, and budgets. `WARN [NO_SPEC]` means nothing was checked against intent.

## 2. Build with the kit

Start from a template in `$SKILL/templates/`:
- `prop.model.mjs`: rigid parts, wheels on pivots, sockets, generated texture, clip.
- `critter.model.mjs`: node-rigged animal with Walk and Idle.
- `skinned.model.mjs`: one bending skinned mesh, rigid parts on bones, clip.

Copy it next to the game's models. Change the import to the absolute path of `$SKILL/scripts/kit.mjs`. Put dimensions in named constants at the top, and derive every position from them.

| Call | Does |
|---|---|
| `const m = model('name')` | new model; root node `name` |
| `m.box(w,h,d)` `m.cyl(rTop,rBot,h,sides)` `m.cone(r,h,sides)` `m.sphere(r)` `m.torus(r,tube)` `m.lathe([[r,y],...])` `m.extrude([[x,y],...], depth)` `m.wedge(w,h,d)` | shapes (three.js geometry) |
| `m.part(name, shape, {parent, at\|world, rot, anchor, geoRot, color, map, ...})` | mesh node. `at` = parent-local, `world` = world position, `rot` = node degrees, `anchor` = side of the shape on the node origin (`center` `bottom` `top` `front`=+Z `back`=−Z `left`=−X `right`=+X `none`=leave the shape where it is), `geoRot` = rotate the shape only (e.g. `[0,0,90]` lays a cylinder along X) |
| `m.beam(name, worldA, worldB, {size, round, parent, color})` | bar from point A to point B (rails, struts, braces, axles); pivots at A |
| `m.group(name, {parent, at\|world, rot})` | empty pivot node |
| `m.socket(name, {parent, at\|world})` | empty attachment node (`userData.socket = true`) |
| `m.bone(name, {parent, at\|world})` | joint for `m.skinned` |
| `m.skinned(name, [{geo, world, anchor}], {bones, weights:'smooth'\|'rigid'\|fn, blend, color})` | one skinned mesh. Pieces are in **world** rest pose and are re-centered by `anchor` like parts (`anchor:'none'` keeps coordinates you already built). Add segments where it bends; a tapered tube is `m.lathe(...)` turned along Z with `geoRot:[90,0,0]` |
| `m.texture(name, {width, height, pixel:(u,v)=>[r,g,b]})` / `{file}` | PNG texture → use as `map` |
| `m.clip(name, {duration, loop}, {node: {rot\|pos\|scale: keys}})` | keys `[[t,[x,y,z]],...]` are **offsets from rest**: rot = degrees, pos = meters added, scale = multiplier |
| `m.wave([x,y,z], {phase, cycles, abs, keys})` | looping sine keys. `cycles: 6` = six wags in one clip; `abs: true` = a dip every half cycle (body bob in a walk). Down a chain (head→tail), `phase: -0.1*i` makes the wave travel toward the tail |
| `m.worldOf(name)` | world position, for debugging placement |
| `await m.write(path)` | dedup, prune (keeps sockets), write .glb, print a summary |

The kit throws on bad names, duplicates, unknown parents, loop clips whose first and last keys differ, and keys out of range. It splits rotations over 90° into extra keys so slerp can't take a shortcut. Full options and raw glTF-Transform escape hatches: `references/kit-api.md`.

## 3–4. Check and look

```bash
node $SKILL/scripts/validate.mjs wagon.glb          # PASS / FAIL [CODE] lines, exit 1 on FAIL
node $SKILL/scripts/inspect.mjs wagon.glb [--attrs] # tree with world positions/sizes, materials, skins, clips; --attrs dumps vertex data
node $SKILL/scripts/look.mjs wagon.glb              # geo sheet: FRONT, LEFT, 3/4, BACK, RIGHT, TOP
node $SKILL/scripts/look.mjs wagon.glb --sheet diag # faces (red = inside showing), clay or skin weights, wireframe, labeled pivots/sockets/bones
node $SKILL/scripts/look.mjs wagon.glb --sheet anim --clip Roll [--view front] [--frames 8]
node $SKILL/scripts/look.mjs wagon.glb --zoom wheel_FL        # a part isolated and framed; an empty/socket: framed in context, marked magenta
node $SKILL/scripts/look.mjs wagon.glb --view bottom,front     # geo sheet with just these views (front back left right top bottom 34 34back)
node $SKILL/scripts/look.mjs wagon.glb --clip Walk --t 0.4    # any sheet, posed mid-clip
```

PNGs go to `<glb dir>/look/`. **Read each one.** Each sheet is about 1.2k image tokens.

How to read the sheets:
- The grid is at y=0, so anything above it floats and anything below it sinks. The cell size is in the footer.
- Orange is the bounding box.
- In the side tiles the label says which way the front is.

Treat every WARN as a question. Keep it only if you can say why (e.g. "OFF_CENTER: the tongue sticks out the front on purpose").

## Repairing a GLB you didn't build

1. `validate.mjs broken.glb --spec <spec>`: the full list of problems, in one pass.
2. `node $SKILL/scripts/fix.mjs broken.glb fixed.glb [--ground]` fixes the mechanical ones and prints each change:
   - names
   - weights and unused joint slots
   - normals
   - inside-out winding
   - metallic=1
   - a skinned mesh that isn't at the root
3. Fix what's left (missing sockets or clips, motion, holes) with glTF-Transform. See `references/gltf-rules.md`.
4. Validate with `--spec` and look, as for a new model. Report every defect and the fix you made.

## 5. Judge (checklist, not vibes)

1. Answer every spec check: **Yes / No / Unclear**, plus the tile it was judged from.
2. **Unclear is not Yes.** Re-render with `--zoom <node>` or `--view <v>` and answer again.
3. For each No, name the node and the numeric fix ("wheel_FL at y=0.30 floats 0.02: set WHEEL_R 0.32"). Then rebuild, re-run validate, re-render, and compare against `*-prev.png`.
4. Vision models miss counts, small gaps and detached parts. Count with `inspect.mjs`, not with your eyes. Use `m.worldOf()` and inspect's world sizes to confirm contact between parts.
5. Never accept in the same turn you first wrote the code. Accept only after a render you have actually Read.

## 6. Hand off: show the user

When a model passes and its checks are all Yes, give the user something they can turn around and play with, not just PNGs:

```bash
node $SKILL/scripts/showcase.mjs --out <dir>/showcase --title "Farm animals" [--group "Animals"] dog.glb pig.glb [--group "Props"] wagon.glb
```

This builds an interactive viewer (`viewer/template.html`):
- orbit the model and play each clip;
- toggle socket/pivot markers, bones and a turntable;
- the validate verdict appears next to each model;
- the spec's `title` and `description` become each model's name and note.

Publish the printed `.html` with the Artifact tool and pass `models.js` in `files`, exactly as the script prints. The page is already designed and themed, so publish it as is. For a later version of the same models, republish the same file path so the link stays the same.

In your reply, give the link plus three short items:
- what was built: parts, sockets, clips;
- any WARNs you kept, with the reason;
- the game-code snippet from `references/game-code.md`, with this model's names filled in.

If the session has no Artifact tool, tell the user to open the `.html` locally in a browser. It loads three.js from a CDN.

## Common mistakes

| Symptom | Fix |
|---|---|
| Part rotates around its center instead of its hinge | Put the pivot node at the joint and hang the mesh with `anchor` (leg: `anchor:'top'`; lid: `anchor:'back'`) |
| Model faces backwards in game | Front must face +Z: in the FRONT tile you see the face/hitch |
| Left/right swapped | +X is the model's LEFT. `_L` parts have x > 0 |
| Wheel spin invisible in filmstrip | Add ONE off-center mark. A plain wheel, a spoke bar or a cross looks the same every 180°/90°, and 8 frames over 360° alias with it |
| Wheel floats a few mm (CONTACT) | A cylinder laid on its side rests on a flat face unless `sides` is a multiple of 4 |
| Walk feet slide or float (AIRBORNE / BELOW_GROUND) | The body drops `legLength*(1-cos(swing))` at each peak swing, twice per cycle: `pos: m.wave([0,-drop,0], {abs:true})`. Or reduce the swing |
| `getObjectByName('Arm.L')` is undefined | Bad name: rename to `Arm_L` |
| Socket gone after optimizing | `prune({ keepLeaves: true })` (kit does this) |
| Skinned mesh offset or doubled transform | Skinned mesh at scene root with no transform (kit does this) |
| Renders black or very dark | No normals (NO_NORMALS), or metallic 1 with no env map (METALLIC; glTF's default when unset) |
| Red in diag faces tile | Inside-out winding or a hole (OPEN_SHELL); solid patch = real defect, hairline specks along edges = seams |
| Clip plays but nothing moves (STATIC_TRACK) | 360° between two keys is a no-op (kit splits), or keys equal the rest pose |
| Loop pops (LOOP_SEAM) | First and last keys must match as poses (0° and 360° match); `m.wave` loops by construction |
| MATERIAL_BUDGET exceeded | Each distinct color + roughness + metalness is its own material: reuse exact values, or share one with `m.material(name, …)` |

## References

| File | Read when |
|---|---|
| `references/kit-api.md` | You need an option not in the table above, morph targets, or raw glTF-Transform |
| `references/gltf-rules.md` | Fixing a GLB not made with the kit, or a validate code you don't understand |
| `references/game-code.md` | Handing off: loading, sockets, AnimationMixer, cloning skinned models |
