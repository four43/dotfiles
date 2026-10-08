# Programmatically authoring rigged, animated, textured glTF 2.0 / GLB for three.js (Node, three 0.186, glTF-Transform 4.5)

Method note: besides the sources below, every behavior marked **[verified]** was checked on 2026-10-07 by a Node script (three 0.186.1, @gltf-transform/core + functions 4.5.1, gltf-validator 2.0.0-dev.3.10) that built GLBs both with glTF-Transform and with three.js GLTFExporter, ran them through the Khronos validator, and parsed them back with GLTFLoader + AnimationMixer. Source-code claims were read directly from three r186 (`node_modules/three/examples/jsm/{exporters/GLTFExporter.js,loaders/GLTFLoader.js}`, `src/animation/PropertyBinding.js`) and the glTF-Transform 4.5.1 `.d.ts` files. The script is in the session scratchpad (`scratchpad/glt/test.mjs`), not in the repo.

## 1. Node hierarchy, TRS vs matrix, empties/sockets, meshes vs primitives, scene/units/axes

### Takeaway
Use TRS (never `matrix`) on every node, put sockets/attach points in as empty named nodes carrying `extras`, and keep names in `[A-Za-z0-9_-]` so three.js keeps them unchanged. glTF is right-handed, +Y up, meters, and the asset's front faces +Z. three.js maps this 1:1 (its cameras look down -Z, so a glTF model faces the default camera). One glTF mesh with N primitives loads as a three `Group` of N `Mesh`es. A mesh with one primitive loads as a single `Mesh` that takes the node's place.

### Cited Findings
- Spec: right-handed coordinates, "+Y as up, +Z as forward, and -X as right; the front of a glTF asset faces +Z". Linear units are meters and angles are radians — [glTF 2.0 spec §3.4](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html). (The WebFetch summary paraphrased this section and claimed the spec has no unit rule. The spec does say "The units for all linear distances are meters". Check the spec page directly if it matters.)
- A node has either `matrix` or TRS (`translation`, `rotation` as an XYZW unit quaternion, `scale`), never both. A node targeted by an animation MUST use TRS only. Nodes form strict trees (no node has two parents), and `scene.nodes` lists the root nodes — [glTF 2.0 spec §3.5](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- `mesh.primitives` is an array, and each primitive can have its own material. Any object may have `extras` for app data — [glTF 2.0 spec](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- GLTFLoader node creation: a joint node becomes `Bone`; a node with more than one resulting object becomes a `Group`; a node holding a single mesh object is that `Mesh` (the node and the mesh merge); a node with nothing becomes a plain `Object3D` — [GLTFLoader.js r186 `_loadNodeShallow`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js). A multi-primitive mesh becomes `new Group()` with one child Mesh per primitive — [same file, `loadMesh`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js)
- Names: GLTFLoader passes every node, mesh, camera and scene name through `createUniqueName()` → `PropertyBinding.sanitizeNodeName()`, which turns whitespace into `_` and removes `[ ] . : /`. Duplicates get the suffix `_1`, `_2`, …. The original name is kept in `object.userData.name` — [GLTFLoader.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js), [PropertyBinding.js r186](https://github.com/mrdoob/three.js/blob/r186/src/animation/PropertyBinding.js). **[verified]** `"Bone.Base"` loads as `BoneBase` (`getObjectByName("Bone.Base")` → undefined) and `"Bone Upper"` loads as `Bone_Upper`, with `userData.name` holding the original.
- `extras` (object form) is `Object.assign`ed into `userData`. Non-object extras log a warning and are ignored. Unknown extensions go to `userData.gltfExtensions` — [GLTFLoader.js r186 `assignExtrasToUserData`/`addUnknownExtensionsToUserData`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js). **[verified]** An empty node `Socket_Hat` with `extras:{socket:'hat'}` loads as `Object3D "Socket_Hat"` with `userData = {name:'Socket_Hat', socket:'hat'}`, so it can be found with `scene.getObjectByName('Socket_Hat')`.
- GLTFExporter writes `userData` → `extras` through a JSON round-trip, so non-JSON values are dropped and it warns on failure. Empty names are not written. `trs:false` (the default) writes a `matrix` unless the matrix is identity, and passing `animations` forces `trs = true` — [GLTFExporter.js r186 `writeAsync`, `processNodeAsync`, `serializeUserData`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js)
- r186 exporter/loader detail: an `Object3D` with a non-null `.pivot` is exported as a container node (position+pivot, rotation, scale; `extras.pivot`) plus a child node holding the mesh at -pivot, and animations target the container. GLTFLoader rebuilds `.pivot` from `userData.pivot` — [GLTFExporter.js r186 `_processNodeWithPivotAsync`; GLTFLoader.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js)
- **[verified] gotcha:** glTF-Transform `prune()` removes empty leaf nodes by default, and that includes socket nodes that have `extras` ("prune: Removed types... Node (1)"). Use `prune({ keepLeaves: true })` (`keepExtras` also exists) — [@gltf-transform/functions 4.5.1 PruneOptions](https://gltf-transform.dev/modules/functions/functions/prune)
- **[verified]** A Document whose first `Scene` is empty while another scene holds the content loads as an empty scene in GLTFLoader (validator: `EMPTY_ENTITY /scenes/0/nodes`). Create exactly one scene, or call `root.setDefaultScene()`.

### Inferences
- Convention for code-authored assets: model in meters, +Y up, front facing +Z, origin at the ground contact point (or at a wheel axle for wheels). Rigid moving parts (wheels, doors, hitch arms) get their own nodes with their pivot at the node origin. That is the only way to rotate them about the right axis without a skin, since glTF nodes have no separate pivot.
- Name sockets/bones with `[A-Za-z0-9_]` only (for example `Socket_Hat`, `wheel_FL`) so the authored name, `getObjectByName`, and animation track names all agree.
- Several materials on one rigid object: use one mesh with several primitives, accepting the Group-of-Meshes result when loaded. If code needs one `Mesh` per node, use separate nodes instead.

### Gaps
- I could not fetch a clean verbatim copy of spec §3.4 (the fetch tool paraphrased). The units/axes wording above is the well-known spec text but was not re-confirmed character by character this session.

## 2. Skins: joints, IBMs, skeleton, JOINTS_0/WEIGHTS_0, validator errors, building in three.js and glTF-Transform, simple auto-weighting

### Takeaway
A valid, loader-friendly skin needs these things:
- Joints are ordinary nodes in the scene.
- `inverseBindMatrices[i]` = inverse(world matrix of joint i at bind time).
- JOINTS_0 is `Uint8`/`Uint16` VEC4.
- WEIGHTS_0 is float VEC4 summing to 1, with index 0 in every unused slot.
- The skinned-mesh node sits at the scene root (sibling of the armature) with an identity transform.

GLTFLoader always binds with an identity bindMatrix. So skinned-mesh node transforms are ignored, which is also what the spec says.

### Cited Findings
- Spec: `skin.joints` (node indices), optional `inverseBindMatrices` (MAT4 float accessor, defaults to identity), optional `skeleton` (common root). Only joint transforms affect a skinned mesh, and the skinned mesh node's own transform is ignored. JOINTS_n are unsigned byte/short, WEIGHTS_n are float or normalized ubyte/ushort, weights must sum to 1, and unused influences should be index 0 with weight 0 — [glTF 2.0 spec §3.7.3](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- GLTFLoader marks every node in any `skin.joints` as `isBone` (→ `THREE.Bone`), marks meshes on nodes that have `skin` as SkinnedMesh, builds `new Skeleton(bones, boneInverses)` from the IBMs, calls `mesh.normalizeSkinWeights()`, and then calls `mesh.bind(skeleton, identityMatrix)`. If the skinIndex/skinWeight attributes are missing it warns "Skinning disabled" and creates a plain Mesh — [GLTFLoader.js r186 `_markDefs`, `loadSkin`, `loadMesh`, `_loadNodeShallow`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js). **[verified]** The loaded `SkinnedMesh` has `bindMode 'attached'` and bones in joint order.
- GLTFExporter skin export: joints = `skeleton.bones`, `IBM_i = boneInverses[i] × mesh.bindMatrix`, `skeleton = bones[0]` (so bones[0] must be the root bone). JOINTS_0 is converted to UNSIGNED_SHORT (with a warning) unless it is already Uint8/Uint16 — [GLTFExporter.js r186 `processSkin`, `processMeshAsync`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js). **[verified]** Exported JOINTS_0 componentType is 5123 and the skin skeleton is `base`.
- Validator codes seen **[verified]**:
  - `NODE_SKINNED_MESH_NON_ROOT` (warning): skinned mesh node has a parent, even an identity `Armature`/`Rig` group. three's usual `rig.add(bone); rig.add(skinnedMesh)` layout triggers it when exported.
  - `NODE_SKINNED_MESH_LOCAL_TRANSFORMS` (warning): skinned mesh node has its own TRS.
  - `ACCESSOR_WEIGHTS_NON_NORMALIZED` (error): weights summed to 0.5.
  - `ACCESSOR_JOINTS_USED_ZERO_WEIGHT` (warning): a non-zero joint index paired with weight 0. It is triggered by the common lazy pattern `skinIndex = [0,1,0,0]` for every vertex.
- Other skin codes in this validator build: `ACCESSOR_JOINTS_INDEX_OOB`, `ACCESSOR_JOINTS_INDEX_DUPLICATE`, `ACCESSOR_INVALID_IBM`, `MESH_PRIMITIVE_JOINTS_WEIGHTS_MISMATCH`, `NODE_SKIN_NO_SCENE`, `SKIN_NO_COMMON_ROOT`, `ANIMATION_CHANNEL_TARGET_NODE_SKIN` — [gltf-validator npm 2.0.0-dev.3.10 bundle](https://github.com/KhronosGroup/glTF-Validator)
- **[verified] gotcha:** with a Float32 JOINTS_0 accessor, gltf-validator 2.0.0-dev.3.10 threw an uncaught Dart type error ("not a subtype of type a4<int>") instead of reporting an issue. Always store joints as Uint8Array/Uint16Array.
- three: `SkinnedMesh.bind(skeleton, bindMatrix?)` uses `mesh.matrixWorld` when bindMatrix is omitted. `new Skeleton(bones)` without inverses calls `calculateInverses()` from the bones' current `matrixWorld`, so call `root.updateMatrixWorld(true)` BEFORE `new Skeleton`/`bind` — [three r186 src/objects/SkinnedMesh.js, Skeleton.js](https://github.com/mrdoob/three.js/blob/r186/src/objects/Skeleton.js)
- glTF-Transform 4.5 skin API **[verified]**: `doc.createSkin().addJoint(node)…setSkeleton(rootJoint).setInverseBindMatrices(accessor MAT4)` and `meshNode.setSkin(skin)`. `sortPrimitiveWeights(prim, limit)` sorts and limits influences ("limit must be a multiple of four") — [@gltf-transform/core/functions 4.5.1 typings](https://gltf-transform.dev/modules/core/classes/Skin)

Verified glTF-Transform pattern (0 errors and 0 warnings in the validator; loads as a SkinnedMesh and animates correctly in AnimationMixer):
```js
const acc = (type, arr) => doc.createAccessor().setType(type).setArray(arr).setBuffer(buf);
const prim = doc.createPrimitive()
  .setAttribute('POSITION', acc('VEC3', pos))
  .setAttribute('JOINTS_0', acc('VEC4', new Uint8Array(joints)))   // unused slots = 0
  .setAttribute('WEIGHTS_0', acc('VEC4', new Float32Array(weights))) // each vec4 sums to 1
  .setIndices(acc('SCALAR', new Uint16Array(idx))).setMaterial(mat);
const arm = doc.createNode('Armature');
const j0 = doc.createNode('hip'), j1 = doc.createNode('spine').setTranslation([0, 1, 0]);
j0.addChild(j1); arm.addChild(j0);
const ibm = new Float32Array(32);                  // inverse of each joint's WORLD bind matrix, column-major
new THREE.Matrix4().makeTranslation(0, 0, 0).invert().toArray(ibm, 0);
new THREE.Matrix4().makeTranslation(0, 1, 0).invert().toArray(ibm, 16);
const skin = doc.createSkin().addJoint(j0).addJoint(j1).setSkeleton(j0).setInverseBindMatrices(acc('MAT4', ibm));
const body = doc.createNode('Body').setMesh(doc.createMesh('Body').addPrimitive(prim)).setSkin(skin); // no TRS
doc.createScene('Scene').addChild(arm).addChild(body);  // skinned node at ROOT, not under Armature
```
Verified three.js pattern before GLTFExporter:
```js
const b0 = new THREE.Bone(); b0.name = 'base'; const b1 = new THREE.Bone(); b1.name = 'upper'; b1.position.y = 1; b0.add(b1);
geo.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4));
geo.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
const sm = new THREE.SkinnedMesh(geo, mat);
scene.add(b0, sm);              // keep both at scene root to avoid NODE_SKINNED_MESH_NON_ROOT
scene.updateMatrixWorld(true);  // before bind!
sm.bind(new THREE.Skeleton([b0, b1]));  // bones[0] must be the root bone (exported as skin.skeleton)
```

### Inferences
- Rigid per-part binding (the "robot" rig) is the most robust auto-weighting for low-poly game characters: each body part's vertices get `joints=[k,0,0,0]`, `weights=[1,0,0,0]`. It never produces candy-wrapper artifacts. A simpler alternative that often works is no skin at all: parent each part's mesh to its joint node and animate the nodes (see §3). That gives identical motion with fewer failure modes, and a skin is only needed when one continuous surface has to bend.
- Segment blend (as verified above): for a limb along an axis, `w = clamp((t - t0)/(t1 - t0), 0, 1)` between the parent and child joint, used only in a band around the joint. Distance-based weights: for each vertex compute `1/d^p` (p≈2–4) to the nearest point on each bone segment, keep the top 4, normalize so they sum to 1, and zero the joint index of any slot with weight 0.
- Always validate generated GLBs with `gltf-validator` (`validator.validateBytes(new Uint8Array(glb))`) as a build/test step. It catches the weight/joint mistakes LLM-written code most often makes.

### Gaps
- I did not test inverse bind matrices with rotated/scaled bind poses. The rule (IBM = inverse of the joint's world matrix at bind) is from the spec, but only translation-only binds were exercised.
- I did not check the Khronos sample assets (RiggedSimple, SimpleSkin) directly this session.

## 3. Animations: channels/samplers, paths, interpolation, quaternions, three.js name binding, node vs skeletal, morph targets

### Takeaway
A glTF animation is a set of (sampler: times → values) plus (channel: node + path). GLTFLoader turns each channel into a three KeyframeTrack named `<sanitizedNodeName>.<position|quaternion|scale|morphTargetInfluences>`, and AnimationMixer resolves that name by searching under the mixer root. Unique, sanitized node names are therefore what makes playback work. Node (rigid) animation and bone animation use exactly the same mechanism. A bone is just a node listed in a skin.

### Cited Findings
- Spec: `channel.target.path` ∈ `translation | rotation | scale | weights`. Rotation is an XYZW unit quaternion. Sampler input is float seconds, strictly increasing. Interpolation is `LINEAR` (slerp for rotations), `STEP`, or `CUBICSPLINE` (each keyframe stores in-tangent, value, out-tangent; tangents are scaled by the keyframe delta time). Animated nodes must not use `matrix`, and two channels in one animation must not target the same node+path — [glTF 2.0 spec §3.11](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html). Related validator codes: `ACCESSOR_ANIMATION_INPUT_NON_INCREASING`, `ACCESSOR_ANIMATION_INPUT_NEGATIVE`, `ANIMATION_DUPLICATE_TARGETS`, `ANIMATION_SAMPLER_INPUT_ACCESSOR_WITHOUT_BOUNDS` — [gltf-validator](https://github.com/KhronosGroup/glTF-Validator)
- GLTFLoader `_createAnimationTracks`: the track name is `(node.name || node.uuid) + '.' + {position|quaternion|scale|morphTargetInfluences}`. For `weights` on a multi-primitive mesh (a Group), it creates one track per child mesh. Rotation → `QuaternionKeyframeTrack`, translation/scale → `VectorKeyframeTrack`, CUBICSPLINE → a custom `GLTFCubicSplineInterpolant` — [GLTFLoader.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js). **[verified]** Channels on `"Bone Upper"` and `Wheel_FL` load as tracks `Bone_Upper.quaternion` (LINEAR=2301) and `Wheel_FL.quaternion` (STEP/Discrete=2300). After `mixer.update(0.5)` the bone quaternion is the authored keyframe `0,0,0.383,0.924`.
- PropertyBinding track grammar: `nodeName[.objectName[objectIndex]].propertyName[propertyIndex]`. Reserved chars are `[ ] . : /`, and supported object names are `material, materials, bones, map` — [PropertyBinding.js r186](https://github.com/mrdoob/three.js/blob/r186/src/animation/PropertyBinding.js)
- GLTFExporter exports only `position→translation`, `quaternion→rotation`, `scale→scale`, `morphTargetInfluences→weights` (so no Euler `.rotation[x]`, no material/color tracks). Discrete → STEP, glTF cubic interpolant → CUBICSPLINE, everything else → LINEAR (three's `InterpolateSmooth` is NOT exported as CUBICSPLINE; there's a TODO). Untargetable tracks get the warning "Could not export animation track" and are skipped. Morph tracks are merged with `mergeMorphTargetTracks` — [GLTFExporter.js r186 `processAnimation`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js)
- **[verified] exporter crash:** the track name `'Body.skeleton.bones[upper].position'` made `GLTFExporter.parseAsync` throw `TypeError: Cannot read properties of null (reading 'isSkinnedMesh')`, because the node lookup returned null before the null check. Use `'upper.position'` (bone name directly) or `'Body.bones[upper].position'`. The latter exported and re-imported as `upper.position`.
- Morph targets: the exporter supports only POSITION and NORMAL morphs ("Only POSITION and NORMAL morph are supported") and writes target names to `mesh.extras.targetNames`. The loader reads `extras.targetNames` into `morphTargetDictionary` — [GLTFExporter.js r186; GLTFLoader.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js)
- glTF-Transform animation API **[verified]**: `doc.createAnimation(name)`, `createAnimationSampler().setInput(acc SCALAR times).setOutput(acc VEC4|VEC3).setInterpolation('LINEAR'|'STEP'|'CUBICSPLINE')`, `createAnimationChannel().setTargetNode(node).setTargetPath('rotation').setSampler(s)`. Both the sampler and the channel must be added to the animation. `resample()` removes redundant keyframes, based on three's `KeyframeTrack.optimize` — [@gltf-transform/functions 4.5.1 typings](https://gltf-transform.dev/modules/functions/functions/resample)

### Inferences
- Rigid-hierarchy animation (wheels spinning, doors, a tractor loader arm): put each moving part on its own node with its pivot at the origin and animate `rotation`. Store quaternions as `[x,y,z,w]` (three's `Quaternion.toArray()` order matches). For continuous spin, prefer driving `node.rotation` in game code rather than baked clips. A baked 0→360° loop needs at least 3 keys, because LINEAR slerp between identical quaternions (0° and 360°) produces no motion.
- Use one clip per action (`Idle`, `Walk`, `Open`). Clip names come from `animation.name`, and three uses `AnimationClip.findByName(gltf.animations, 'Walk')`.
- Mixer root: create the `AnimationMixer` on the loaded `gltf.scene` (or a clone made with `SkeletonUtils.clone` for skinned instances), because name lookup is a search under that root. Duplicate names resolve to the first match, and the loader's `_1` suffixing keeps them distinct.

### Gaps
- CUBICSPLINE round-tripping through GLTFExporter was not tested. For game assets LINEAR/STEP are enough.

## 4. Textures/materials: PBR, vertex colors, UVs, procedural textures in Node, palette atlases, extensions, compression, color space

### Takeaway
For code-generated low-poly assets there are two simple options:
- `COLOR_0` vertex colors with a white baseColor. This needs no texture and no UVs. It is what this repo already does.
- A tiny palette PNG (Kenney-style) with every face's UVs pointing at a color cell.

baseColor/emissive textures are sRGB, while COLOR_0, factors, and metallicRoughness/normal/occlusion maps are linear. GLTFLoader sets `texture.colorSpace` and `flipY=false` itself. Compressed variants (Draco, meshopt, KTX2) only load if the matching decoder is registered on GLTFLoader.

### Cited Findings
- Spec: baseColorTexture (and emissive) are sRGB-encoded. metallicRoughnessTexture is linear, with roughness in G and metalness in B. COLOR_0 is linear (float, or normalized ubyte/ushort; VEC3/VEC4) and multiplies baseColor. UV (0,0) is the top-left of the image — [glTF 2.0 spec §3.9](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- GLTFLoader assigns `map`/`emissiveMap` with `SRGBColorSpace`, leaves other maps without a color space, sets `texture.flipY = false`, sets `material.vertexColors = true` when COLOR_0 is present, and converts color factors with `setRGB(..., LinearSRGBColorSpace)`. It warns if `ColorManagement.workingColorSpace` isn't linear-sRGB while COLOR_0 exists — [GLTFLoader.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js)
- Practical consequence: when you build a `CanvasTexture`/`DataTexture` for a three.js scene you intend to export, set `tex.colorSpace = THREE.SRGBColorSpace` for color maps and `tex.flipY = false` if you author UVs glTF-style. Vertex colors written into a glTF must be linear, so convert sRGB palette bytes with `THREE.Color().setRGB(r,g,b, SRGBColorSpace)`, read `.r/.g/.b` (which come out linear), or use glTF-Transform `vertexColorSpace({inputColorSpace:'srgb'})` — [@gltf-transform/functions 4.5.1 `vertexColorSpace`](https://gltf-transform.dev/modules/functions/functions/vertexColorSpace)
- GLTFExporter: use MeshStandardMaterial or MeshBasicMaterial ("Use MeshStandardMaterial or MeshBasicMaterial for best results"; ShaderMaterial is not supported). MeshBasicMaterial is exported via KHR_materials_unlit. Separate metalnessMap+roughnessMap are merged into one texture (with a warning). Texture offset/repeat/rotation → KHR_texture_transform. `maxTextureSize` downsizes images. A multi-material mesh exports one primitive per `geometry.groups` entry, and returns null if a material array has no groups. Unknown attributes are prefixed `_`. Int32/Uint32 non-custom attributes are converted to FLOAT. Supported extensions: KHR_lights_punctual, materials_{clearcoat,dispersion,emissive_strength,ior,iridescence,specular,sheen,transmission,unlit,volume}, mesh_quantization, texture_transform — [GLTFExporter.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js)
- **[verified]** GLTFExporter writes TEXCOORD_0 even with no texture, and the validator reports `UNUSED_OBJECT` (info). glTF-Transform `prune()` drops unused attributes unless `keepAttributes: true`.
- Compression on the loader side: KHR_draco_mesh_compression needs `loader.setDRACOLoader(new DRACOLoader().setDecoderPath(...))`. KHR_texture_basisu (KTX2) needs `setKTX2Loader(...)`, otherwise it throws "setKTX2Loader must be called before loading KTX2 textures". EXT_meshopt_compression needs `setMeshoptDecoder(MeshoptDecoder)`, otherwise it throws "setMeshoptDecoder must be called before loading compressed files" — [GLTFLoader.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/loaders/GLTFLoader.js)
- glTF-Transform 4.5.1 functions available **[verified via export list]**: `prune dedup weld unweld normals tangents flatten join palette quantize meshopt draco resample sequence simplify textureCompress unlit unwrap vertexColorSpace sortPrimitiveWeights metalRough instance center transformMesh` among others. `palette()` merges solid-color materials into a palette texture. `unwrap()` generates UVs (needs a watlas instance). `textureCompress` uses sharp (installed as a functions dependency) — [@gltf-transform/functions](https://gltf-transform.dev/functions)
- Embedding a PNG with glTF-Transform: `doc.createTexture('pal').setImage(pngBytes).setMimeType('image/png')`, then `material.setBaseColorTexture(tex)`. The local repo already has `pngjs` 7 for encoding (`PNG.sync.write(png)`) — [@gltf-transform/core typings](https://gltf-transform.dev/modules/core/classes/Texture); repo `package.json`.

### Inferences
- Best fit for this project: keep vertex colors (COLOR_0 + white `baseColorFactor`, `metallicFactor 0`, `roughnessFactor ~0.8–1`) and use flat shading by un-welding, giving each face its own vertices and normals. This avoids UVs, samplers, and color-space mistakes in textures. Use a palette texture only when you need image detail (eyes, decals) or want to share one material/draw call across many models.
- Palette UV trick: for an N×1 palette PNG, set every vertex UV of a face to the center of its color cell, `((i+0.5)/N, 0.5)`, and use `NearestFilter` with no mipmaps, or pad cells to ≥4 px to avoid bleed.
- Skip Draco/KTX2 for small low-poly GLBs. meshopt + quantize is the cheaper win if size matters, but adds a runtime decoder dependency.

### Gaps
- I did not test procedural textures through GLTFExporter in Node. Image export uses `canvas.toBlob`/`OffscreenCanvas.convertToBlob`, which do not exist in plain Node. Building textures in glTF-Transform from pngjs bytes avoids the problem. KTX2 generation in Node (toktx/basis encoders) was not researched.

## 5. GLTFExporter limitations (esp. Node) vs glTF-Transform capabilities

### Takeaway
In Node, GLTFExporter works for geometry, skins, and animations once a `FileReader` polyfill exists (Node 18+ has a global `Blob`), but it cannot export textures without a canvas implementation. glTF-Transform is the safer primary authoring tool in Node: it has a direct Document API, no DOM dependency, `io.writeBinary`, and the validator-clean output shown above. A good workflow builds geometry with three.js helpers, then writes through glTF-Transform. That is the pattern this repo's `models.mjs` + `tools/glb.mjs` already use.

### Cited Findings
- Options and defaults: `binary:false, trs:false, onlyVisible:true, maxTextureSize:Infinity, animations:[], includeCustomExtensions:false, copyright:null`. Supplying animations forces `trs:true`. `onlyVisible` skips invisible children, so hidden sockets/variants vanish unless you set `onlyVisible:false`. `includeCustomExtensions` exports `userData.gltfExtensions` — [GLTFExporter.js r186 `writeAsync`](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js)
- Node usage: the exporter uses `new Blob(...)` and `new FileReader()` (readAsArrayBuffer for GLB, readAsDataURL for .gltf) — [GLTFExporter.js r186](https://github.com/mrdoob/three.js/blob/r186/examples/jsm/exporters/GLTFExporter.js). Forum workarounds polyfill Blob/FileReader (e.g. `vblob`), and texture export needs canvas fallbacks — [three.js forum: Nodejs GLTFExporter Blob issue](https://discourse.threejs.org/t/nodejs-threejs-gltfexporter-server-side-blob-issue/4040), [GLTF Exporter in Node Backend](https://discourse.threejs.org/t/gltf-exporter-in-node-backend/44748). **[verified]** On Node 26 this minimal shim was enough for a binary skinned+animated export:
  ```js
  globalThis.FileReader ??= class { readAsArrayBuffer(b){ b.arrayBuffer().then(r=>{this.result=r;this.onloadend?.();}); }
    readAsDataURL(b){ b.arrayBuffer().then(r=>{this.result=`data:${b.type||'application/octet-stream'};base64,`+Buffer.from(r).toString('base64');this.onloadend?.();}); } };
  const glb = Buffer.from(await new GLTFExporter().parseAsync(scene, { binary: true, animations: [clip] }));
  ```
- **[verified]** A `THREE.Scene` with an empty name exports as the glTF scene and re-imports as an unnamed `Group`. Export the scene, not a sub-object, if you want a scene root. Exported node order/hierarchy round-tripped (`Rig, base, upper, Socket_Hand, Body[skin][mesh]`), and `userData` round-tripped via extras.
- glTF-Transform: `NodeIO().writeBinary(doc)`/`readBinary`/`write(path)`. Transforms run via `await doc.transform(dedup(), prune({keepLeaves:true}), weld(), normals())`. `prune` options are `keepLeaves`, `keepAttributes`, `keepSolidTextures`, `keepExtras`. `flatten()` and `join()` will break socket/animated-node hierarchies, so don't run them on rigged assets unless the targets are named or excluded (`join({keepNamed:true})`) — [@gltf-transform/functions 4.5.1 typings](https://gltf-transform.dev/functions)
- Extensions in glTF-Transform need `@gltf-transform/extensions` (installed in this repo) and `io.registerExtensions(ALL_EXTENSIONS)` (plus `registerDependencies` for draco/meshopt encoders) — [glTF-Transform docs](https://gltf-transform.dev/extensions)

### Inferences
- Recommended pipeline for an LLM agent in this repo:
  1. Build parts with three.js geometry (BoxGeometry etc.), transformed into model space.
  2. Bake vertex colors.
  3. Assemble nodes, skins, and animations in glTF-Transform with sanitized names and root-level skinned meshes.
  4. Run `dedup()` + `prune({keepLeaves:true})`.
  5. `writeBinary`.
  6. Assert `gltf-validator` reports zero errors and no skin warnings.
  7. Parse back with GLTFLoader in a node test, checking `getObjectByName` for every socket and joint and that each clip's tracks all bind (`mixer.clipAction(clip)` then `update`).
- Blender `bpy` is not needed for any of this. It is only worth adding if real smooth-skinned organic characters (heat-map weights) become a requirement.

### Gaps
- I did not test `weld()`/`normals()` on skinned primitives. weld merges vertices that share all attributes, so it should respect JOINTS/WEIGHTS differences, but this was not confirmed.
- I did not check glTF-Transform GitHub issues for skin-specific bugs in 4.5.
