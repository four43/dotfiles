# glTF rules that bite (and the validate code for each)

Read this when fixing a GLB the kit didn't make, or when a validate code isn't self-explanatory. Use raw glTF-Transform: `const doc = await io.read(f)` (io from kit.mjs) … `await io.write(f, doc)`.

## Validate codes

| Code | Meaning | Fix |
|---|---|---|
| `gltf:*` | Khronos glTF-Validator error/warning (pointer shows where) | see sections below |
| `BAD_NAME` | name has whitespace or `. : / [ ]`; three.js renames it | `node.setName(n.replace(/[\s.:/\[\]]/g, '_'))`, and update clip/game references |
| `DUP_NAME` | two nodes (or scene + node) share a name; three.js appends `_1` | make unique |
| `NO_NORMALS` | primitive has no NORMAL; renders black under lights; Khronos doesn't flag it | `normals()` from @gltf-transform/functions, or recompute in three.js |
| `INSIDE_OUT` | closed shell with negative volume: winding reversed | swap 2 indices of every triangle |
| `WEIGHT_SUM` | vertex weights don't sum to 1 | divide each vertex's 4 weights by their sum |
| `gltf:ACCESSOR_JOINTS_USED_ZERO_WEIGHT` | joint slot ≠ 0 where weight = 0 | set the joint index to 0 wherever weight is 0 |
| `JOINT_TYPE` | JOINTS_0 not Uint8/Uint16 | store as `Uint8Array` (≤256 joints) or `Uint16Array` |
| `SKIN_NOT_ROOT`, `SKIN_TRANSFORM` | skinned mesh node has a parent or its own TRS; glTF ignores it, so engines disagree | move the node to the scene root with identity TRS. If the old world matrix wasn't identity, apply it to the positions and normals; IBMs stay. three.js bound the mesh with that matrix, so this keeps what three.js showed (fix.mjs `skinroot` does it) |
| `KEY_ORDER`, `QUAT_NORM` | animation input not increasing / rotation not unit | sort keys / normalize |
| `STATIC_TRACK` | a channel never changes | if meant to move: keys equal the rest pose, or two keys 360° apart (same quaternion). Key every ≤90° |
| `LOOP_SEAM` | loop clip ends in a different pose than it starts | make last key = first |
| `UNBOUND_TRACK` | a clip targets a node three.js can't find (often a renamed one) | fix names |
| `NOT_GROUNDED`, `OFF_CENTER` | origin not bottom-center | translate the root's children / geometry; or `"grounded": false` for floating things |
| `BELOW_GROUND`, `AIRBORNE` | during a clip the lowest point dips below or never touches y=0 | adjust body height keys, swing angles |
| `COLLAPSE` | posed size shrinks below 60% on an axis | bad weights, wrong IBMs, or a bone rotated 180° |
| `SIZE`, `MISSING_*`, `CLIP_*`, `*_BUDGET` | spec mismatch | fix the model or the spec, whichever is wrong |
| `NPOT_TEXTURE` | texture side not a power of two | resize to 64/128/256… |
| `METALLIC` | metallic ≥ 0.5 without a texture; glTF defaults metallic to **1** when unset, and three.js renders that near-black without an env map | `setMetallicFactor(0)` |
| `NO_UV` | triangle primitive has no TEXCOORD_0: no texture can be mapped | kit shapes always have them; `fix.mjs` (uvs) box-projects from the normals; a hand-painted texture needs a real unwrap (Blender: Smart UV Project) |
| `UV_STRETCH` | >10% of a primitive's area is stretched over 3:1 in UV (a texture smears there) | kit: drop `uv: 'fit'`; otherwise re-unwrap the stretched part (see UV mapping below) |
| `OPEN_SHELL` | mesh has open edges and a single-sided material: see-through from behind | cap the hole, or `setDoubleSided(true)` for deliberate planes |
| `NO_SPEC` | nothing checked against intent | write `<name>.spec.json` or pass `--spec` |

`scripts/fix.mjs in.glb out.glb` fixes the purely mechanical codes (names, weights, normals, winding, metal, skin root; `--ground` to re-origin).

## UV mapping

Goal: square texels, about the same size everywhere, seams where nobody looks.

- **Measure, don't eyeball.** validate reports `UV_STRETCH`; `look.mjs --sheet uv` and the viewer's *UV checker* put a labelled checker on the UVs. Squares = no stretch, cell size = texel density, mirrored letters = flipped UVs, magenta = no UVs.
- **One density.** Keep UV units per meter the same on every part (the kit's meter UVs do this). A part with 4× the density shows a 4× finer texture next to its neighbour.
- **Cut, don't stretch.** A curved surface can't lie flat without either stretching or a seam. Cut seams (separate UV islands) along hard edges and hidden places: the underside, the back, the inside of a limb, where parts meet.
- **Poles and tips pinch.** Sphere poles and cone tips squeeze every column into a point. Keep detail out of them, or cap them with a separate flat island.
- **Mirrored UVs** are fine for color, wrong for normal maps (the tangent space flips). Don't mirror if a normal map may come later.
- **Atlases** (several parts sharing one image) need non-overlapping islands with a few texels of padding, or colors bleed at mip levels. The kit gives each part its own UVs from 0 up, so share one image across parts only for a tiling pattern.
- `fix.mjs` (uvs) box-projects per vertex from the normal's main axis, in units of the primitive's largest side. Good enough for a tiling texture; smooth curved meshes get seams where the main axis changes.

## Hierarchy

- A node has one of: nothing (an empty), a mesh, a camera. A mesh can have several primitives, one per material. Separate *moving* parts need separate nodes.
- A node's TRS is relative to its parent. Rotation is a quaternion `[x, y, z, w]`.
- Animation targets nodes, so a part's pivot is its node's origin. To move the pivot without moving the shape: shift the node by +d and the vertices by −d.
- Empties (sockets, pivots) survive load as three.js `Object3D`, and `extras` → `userData`. glTF-Transform's `prune()` deletes leaf empties unless `keepLeaves: true`.
- three.js GLTFLoader: names are sanitized (spaces → `_`, `. : / [ ]` removed) and duplicates get `_1`, `_2`. The scene object takes the scene's name.

## Materials and textures

- `baseColorFactor` is **linear**. `#ff8800` in sRGB is not `[1, 0.53, 0]`; convert with `new THREE.Color('#ff8800')`, which gives linear r, g, b.
- Vertex colors (`COLOR_0`) are linear too. Base color textures are sRGB, and three.js sets `colorSpace` itself.
- GLTFLoader sets `texture.flipY = false`, so glTF UV (0,0) is the image's top-left.
- `KHR_materials_unlit` for flat toon looks. `doubleSided: true` for single-sided planes. Alpha uses `alphaMode: 'BLEND' | 'MASK'`.
- Draco, meshopt and KTX2 compressed files each need a decoder registered on the loader in the game. Don't compress unless asked.

## Skins

- `skin.joints` lists the joint nodes. `inverseBindMatrices[i]` = inverse of joint i's **world** matrix at bind time. `skin.skeleton` = the root joint.
- Each vertex has `JOINTS_0` (4 indices into `skin.joints`) and `WEIGHTS_0` (4 floats summing to 1). Unused slots: joint 0, weight 0.
- The skinned mesh node must be at the scene root with no transform. Its vertices are in world/bind space.
- Joints are ordinary nodes: rigid parts can be their children. Don't scale joints non-uniformly.
- three.js: a skinned model must be cloned with `SkeletonUtils.clone`, not `.clone()`.

## Animation

- A channel = target node + path (`translation`, `rotation`, `scale`, `weights`) + sampler (input times, output values, `LINEAR`/`STEP`/`CUBICSPLINE`).
- Rotation LINEAR is slerp, which takes the short way: keys more than 180° apart go backwards, and 360° apart do nothing.
- three.js binds tracks by node name (`wheel_FL.quaternion`). Renamed nodes become `UNBOUND_TRACK`.
- Clip duration = the largest input time over all channels. Keep every channel's last key at the same time.
