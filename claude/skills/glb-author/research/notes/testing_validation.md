# Automated Testing and Validation of GLB/glTF Game Models (for three.js)

Scope: tools, programmatic checks and test patterns a coding agent can run as `npm test` (`node --test`) or one CLI command, with machine-readable pass/fail. Environment assumed: Node (`node --test`), three 0.186, @gltf-transform/core 4.5, Playwright.

**Verification note:** Items marked **[verified locally]** were run by the researcher on 2026-10-07 in a scratch directory with three@0.186, @gltf-transform/{core,functions,cli}@4.5.1, gltf-validator@2.0.0-dev.3.10, playwright@1.64, pixelmatch, pngjs, Node v26.10, against the project's own `assets/models/*.glb` and a generated 2-bone skinned, textured, animated test GLB. The local runs are a primary source in their own right: they show what actually happened with these exact versions. All three tests in the example `node --test` suite below passed on the good asset. An intentionally broken weight (sum 0.8) failed both the validator test and the custom weight-sum test, as it should.

---

## 1. Khronos glTF-Validator (npm `gltf-validator` / CLI): running it in Node, report format, relevant codes, how to treat severities

### Takeaway
`gltf-validator` (npm, Dart compiled to JS) gives you `validateBytes(Uint8Array, options)`, which returns a JSON report with `issues.numErrors/numWarnings/numInfos/numHints`, a `messages[]` array (`code`, `message`, `severity` 0–3, `pointer` as a JSON Pointer) and an `info` block with triangle, draw-call and influence counts. Recommended gate: fail on severity 0 (error) and 1 (warning), allow-list specific infos (for example `NODE_EMPTY` for socket empties), and use `info` for budget checks.

### Cited Findings
- The npm package is `gltf-validator`. Its Node usage is `validator.validateBytes(new Uint8Array(asset)).then(report => …)`. It also has `validateString(json, options)`, `version()` and `supportedExtensions()`. — [gltf-validator npm README](https://www.npmjs.com/package/gltf-validator) (README read from the published tarball)
- ValidationOptions: `uri`, `format` (`'glb'|'gltf'` to skip auto-detection), `externalResourceFunction` (if omitted, external resources are not validated), `writeTimestamp` (set `false` for deterministic reports), `maxIssues` (`0` = unlimited), `ignoredIssues: string[]`, `onlyIssues: string[]` (cannot be combined with ignoredIssues), and `severityOverrides: {CODE: n}`. The README example `{ 'ACCESSOR_INDEX_TRIANGLE_DEGENERATE': 0 }` "treat[s] degenerate triangles as errors". A rejected promise means invalid arguments or an undetectable format. — [gltf-validator npm README](https://www.npmjs.com/package/gltf-validator)
- The latest npm version is `2.0.0-dev.3.10`, last modified 2024-10-22. The package is still tagged "dev" but is the current official build. — `npm view gltf-validator` **[verified locally]**
- Native CLI: `gltf_validator [<options>] <input>`. Flags include `-o/--stdout` (JSON report to stdout instead of `<asset>.report.json`), `-r/--validate-resources`, `-m/--messages`, `-a/--all` and `-c/--config <yaml>`. — [KhronosGroup/glTF-Validator README](https://github.com/KhronosGroup/glTF-Validator)
- **Real report shape** from running on the project's `chicken.glb` **[verified locally]**:
  ```json
  {"uri":"…","mimeType":"model/gltf-binary","validatorVersion":"2.0.0-dev.3.10",
   "issues":{"numErrors":0,"numWarnings":0,"numInfos":1,"numHints":0,"truncated":false,
     "messages":[{"code":"UNUSED_OBJECT","message":"This object may be unused.","severity":2,
                  "pointer":"/meshes/2/primitives/0/attributes/TEXCOORD_0"}]},
   "info":{"version":"2.0","generator":"glTF-Transform v4.5.1","extensionsUsed":["KHR_texture_transform"],
     "animationCount":8,"materialCount":1,"hasMorphTargets":false,"hasSkins":false,"hasTextures":false,
     "hasDefaultScene":true,"drawCallCount":5,"totalVertexCount":425,"totalTriangleCount":510,
     "maxUVs":1,"maxInfluences":0,"maxAttributes":4}}
  ```
  Severity numbers: **0 = Error, 1 = Warning, 2 = Information, 3 = Hint** (seen in output, consistent with the `severityOverrides` example).
- Issue codes most relevant to procedurally or LLM-generated files, with default severities from ISSUES.md — [ISSUES.md](https://github.com/KhronosGroup/glTF-Validator/blob/main/ISSUES.md) (also bundled in the npm tarball):
  - Skinning: `ACCESSOR_JOINTS_INDEX_OOB` (Error; joint index > max joint index for the skin), `ACCESSOR_JOINTS_INDEX_DUPLICATE` (Error), `ACCESSOR_JOINTS_USED_ZERO_WEIGHT` (Warning), `ACCESSOR_WEIGHTS_NEGATIVE` (Error), `ACCESSOR_WEIGHTS_NON_NORMALIZED` (Error: "Weights accessor elements (at indices %1..%2) have non-normalized sum"), `MESH_PRIMITIVE_JOINTS_WEIGHTS_MISMATCH` (Error), `SKIN_NO_COMMON_ROOT` (Error), `SKIN_SKELETON_INVALID` (Error), `SKIN_IBM_INVALID_FORMAT` (Error), `NODE_SKIN_NO_SCENE` (Error: "A node with a skinned mesh is used in a scene that does not contain joint nodes.")
  - Skinned-mesh placement: `NODE_SKINNED_MESH_NON_ROOT` ("Parent transforms will not affect a skinned mesh"), `NODE_SKINNED_MESH_LOCAL_TRANSFORMS` (Warning), `NODE_SKINNED_MESH_WITHOUT_SKIN` (Warning), `ANIMATION_CHANNEL_TARGET_NODE_SKIN` (Warning: "Animated TRS properties will not affect a skinned mesh").
  - Floats and units: `ACCESSOR_INVALID_FLOAT` (Error; NaN/Inf), `ACCESSOR_VECTOR3_NON_UNIT` (Error; non-unit normals), `ROTATION_NON_UNIT` (Error; node quaternion), `ACCESSOR_ANIMATION_SAMPLER_OUTPUT_NON_NORMALIZED_QUATERNION` (Error).
  - Animation timing: `ACCESSOR_ANIMATION_INPUT_NEGATIVE`, `ACCESSOR_ANIMATION_INPUT_NON_INCREASING` (Errors), `ANIMATION_DUPLICATE_TARGETS` (Error), `ANIMATION_SAMPLER_INPUT_ACCESSOR_WITHOUT_BOUNDS` (Error).
  - Geometry: `MESH_PRIMITIVE_POSITION_ACCESSOR_WITHOUT_BOUNDS` (Error; min/max missing), `MESH_PRIMITIVE_UNEQUAL_ACCESSOR_COUNT` (Error), `MESH_PRIMITIVE_INCOMPATIBLE_MODE`, `MESH_PRIMITIVE_TOO_FEW_TEXCOORDS` (Error), `MESH_PRIMITIVE_NO_TANGENT_SPACE`/`GENERATED_TANGENT_SPACE`, `ACCESSOR_INDEX_TRIANGLE_DEGENERATE` (Information).
  - Images: `IMAGE_NPOT_DIMENSIONS` (Information), `IMAGE_MIME_TYPE_INVALID`, `IMAGE_DATA_INVALID` (Errors).
  - Hygiene: `UNUSED_OBJECT` (Information), `NODE_EMPTY` (Information).
- **Severity discrepancy:** ISSUES.md on GitHub lists `NODE_SKINNED_MESH_NON_ROOT` as Information — [ISSUES.md](https://github.com/KhronosGroup/glTF-Validator/blob/main/ISSUES.md). The npm build 2.0.0-dev.3.10 reported it as severity **1 (Warning)** when the researcher ran it on a skinned mesh parented under a translated node **[verified locally]**.
- With a deliberately broken file, the validator reported `ROTATION_NON_UNIT` (0), `MESH_PRIMITIVE_INCOMPATIBLE_MODE` (1), `NODE_SKINNED_MESH_NON_ROOT` (1), `NODE_EMPTY` (2), `UNUSED_OBJECT` (2) and `ACCESSOR_WEIGHTS_NON_NORMALIZED` (0) with JSON pointers such as `/nodes/0/rotation` **[verified locally]**.
- Intentional socket/attachment empties (nodes with only a transform) trigger `NODE_EMPTY` (Information) **[verified locally]**. Allow-list that code rather than treating infos as failures.

Recommended Node gate **[verified locally]**:
```js
import { createRequire } from 'node:module';
const validator = createRequire(import.meta.url)('gltf-validator'); // CJS package
const r = await validator.validateBytes(new Uint8Array(fs.readFileSync(f)), {
  uri: f, maxIssues: 0, writeTimestamp: false,
  ignoredIssues: ['NODE_EMPTY'],                         // sockets are intentionally empty
  severityOverrides: { ACCESSOR_INDEX_TRIANGLE_DEGENERATE: 1, UNUSED_OBJECT: 1 }, // optional tightening
});
const bad = r.issues.messages.filter(m => m.severity <= 1).map(m => `${m.code} ${m.pointer}: ${m.message}`);
assert.deepEqual(bad, []);                               // diff output lists every offending pointer
assert.ok(r.info.totalTriangleCount <= BUDGET.tris && r.info.drawCallCount <= BUDGET.draws && r.info.maxInfluences <= 4);
```

### Inferences
- For agent feedback, asserting `deepEqual(bad, [])` works better than `numErrors === 0`: the failure diff contains code, pointer and message, which the agent can act on directly.
- Upgrading `UNUSED_OBJECT` and degenerate triangles to warnings is reasonable for generated assets, because both usually mean generator bugs (orphaned UVs, collapsed faces). Leave `IMAGE_NPOT_DIMENSIONS` as info unless targeting mipmapped textures with old constraints.
- The `info` block makes a cheap first budget gate without writing any geometry code.

### Gaps
- I found no official statement explaining why the npm build reports `NODE_SKINNED_MESH_NON_ROOT` as a warning while ISSUES.md lists it as info. It may be a version difference. Check behavior empirically against the pinned version.
- `NODE_SKINNED_MESH_PARENT_TRANSFORMS` appears in the GitHub ISSUES.md fetch, but I did not see it in the strings of the npm 2.0.0-dev.3.10 bundle. The repo may be ahead of the npm release.

---

## 2. glTF-Transform `inspect`/`validate` and other tools (gltfpack, three.js GLTFLoader in Node, Babylon, Blender)

### Takeaway
`gltf-transform validate` wraps the Khronos validator and **exits 1 on errors**, so it works as a one-command gate. `gltf-transform inspect --format csv|md` prints per-scene bbox and per-mesh vertex, attribute and material tables, and `inspect(doc)` from `@gltf-transform/functions` returns the same data as JS objects. three.js `GLTFLoader.parseAsync(arrayBuffer, '')` works in plain Node for untextured GLBs. With embedded textures it throws `ReferenceError: self is not defined`, so strip textures with gltf-transform before parsing.

### Cited Findings
- `gltf-transform validate <input> [--format pretty|csv|md] [--ignore CODE,CODE] [--limit n]` — "Validate the model with official glTF validator". Example: `gltf-transform validate input.glb --ignore ACCESSOR_WEIGHTS_NON_NORMALIZED`. — `gltf-transform validate --help` (v4.5.1) **[verified locally]**; see also [gltf-transform.dev](https://gltf-transform.dev/cli)
- On a file with errors, the CLI printed a CSV table (`code,message,severity,pointer`), then `error: Validation detected errors.`, and **exited with status 1**. A clean file exits 0. — **[verified locally]** (I did not test whether warnings alone cause a non-zero exit.)
- `gltf-transform inspect <input> --format csv` prints OVERVIEW, SCENES (`bboxMin`, `bboxMax`, `renderVertexCount`, `uploadVertexCount`), MESHES (`mode`, `glPrimitives`, `vertices`, `indices`, `attributes` such as `COLOR_0:f32, NORMAL:f32, POSITION:f32`, `size`), MATERIALS (`textures`, `alphaMode`, `doubleSided`), TEXTURES and ANIMATIONS. Example scene row from `chicken.glb`: `0,animal-chick,animal-chick,"-1.098, 0, -0.625","1.098, 1.59425, 0.725",1530,425,425`. — **[verified locally]**
- Programmatic: `import { inspect } from '@gltf-transform/functions'; const r = inspect(doc);` returns `r.scenes.properties[i] = {name, rootName, bboxMin, bboxMax, renderVertexCount, …}` and `r.meshes.properties[i] = {name, mode, meshPrimitives, glPrimitives, vertices, indices, attributes[], instances, size}`. `getBounds(scene)` from `@gltf-transform/core` gives `{min, max}`. — **[verified locally]**
- three.js in Node: `new GLTFLoader().parseAsync(arrayBuffer, '')` loaded `chicken.glb` (no textures). It returned the scene graph and 8 clips, and `AnimationMixer.setTime()` sampling worked with no DOM. — **[verified locally]**
- With an embedded PNG texture, it threw `ReferenceError: self is not defined at GLTFParser.loadImageSource (GLTFLoader.js:3355)`. GLTFLoader uses `self.URL || self.webkitURL` and picks `ImageBitmapLoader` only when `createImageBitmap` exists (GLTFLoader.js line 2654 in r186). — **[verified locally]**; community reports of the same class of problem (`URL.createObjectURL is not a function`, recommended hacks) — [three.js forum: GLTFLoader for .glb with textures on node](https://discourse.threejs.org/t/gltfloader-for-glb-mesh-with-textures-on-node/8603), [Using GLTFLoader on node](https://discourse.threejs.org/t/using-gltfloader-on-node/2309)
- A working fix for geometry and animation tests **[verified locally]**:
  ```js
  const io = new NodeIO(); const doc = await io.readBinary(bytes);
  doc.getRoot().listTextures().forEach(t => t.dispose());     // Node has no self/Image/createImageBitmap
  const glb = await io.writeBinary(doc);
  const gltf = await new GLTFLoader().parseAsync(glb.buffer.slice(glb.byteOffset, glb.byteOffset + glb.byteLength), '');
  ```
- gltfpack (meshoptimizer) has `-v` (verbose) and `-r <file>` ("write a JSON report"). It optimizes for vertex cache, quantizes, merges meshes to reduce draw calls, and resamples animations. — [gltfpack man page (Debian)](https://manpages.debian.org/testing/gltfpack/gltfpack.1)
- Since r163, three.js `WebGLRenderer` no longer supports WebGL 1 (deprecated in r153). — [three.js forum: R163+ WebGL1](https://discourse.threejs.org/t/r163-workaround-to-keep-supporting-webgl-1/63547), [three.js Migration Guide](https://github.com/mrdoob/three.js/wiki/Migration-Guide)

### Inferences
- Because WebGL 1 support was removed, Node-only `headless-gl` (`gl` package, WebGL 1) is no longer a viable way to render three.js 0.186. Use a real headless Chromium via Playwright for pixels (section 5).
- Layer cheapest-first: (1) `gltf-transform validate` for spec validity, (2) gltf-transform document assertions for raw data such as weights, quaternions, bbox and budgets, (3) three.js parse plus `AnimationMixer` to check that three.js interprets the asset as intended (track binding, socket motion), (4) Playwright pixels last.
- Use gltfpack mainly as an optimizer. Its JSON report could feed budget assertions, but I did not run it.

### Gaps
- I did not verify gltfpack `-r` report fields or stats output format (not installed). Babylon.js Sandbox and Blender headless import (`blender -b --python …`) were not researched in depth. Both are possible cross-engine checks, but they are heavier than the Node tools above and I found no sources for CI recipes within budget.

---

## 3. Semantic assertions for game assets (names, hierarchy, pivots, bounds, budgets, normals, manifold, UVs, textures, skin, animation data)

### Takeaway
Most game-asset semantics are not covered by the spec validator: names and sockets, grounding, size in meters, forward axis, outward normals, watertightness, weight sums, loop seams. Each takes about 5–20 lines over `@gltf-transform/core` accessors (`getElement`) or the three.js scene. Base the conventions on the Khronos 3D Commerce guidelines: meters, +Y up, front facing +Z, bottom-center origin, power-of-two textures.

### Cited Findings
- Khronos 3D Commerce Real-time Asset Creation Guidelines:
  - "use 1 unit as 1 meter when possible", "+Y as world up", "front of the asset facing +Z", right-handed coordinates.
  - "Most assets should be placed so the center bottom is at world coordinate 0,0,0". "Articulated assets should have specific pivot placement to direct movement and animation".
  - "100,000 triangles or less" (commerce target). "no obvious holes, unintentional visible gaps, or non-manifold geometry". UVs "positioned within the 0-1 space, avoid overlapping".
  - Draw calls "should be minimized by consolidating meshes, and using fewer materials". Textures use "power of 2 resolutions", 1K or 2K. Files "Ideally less than 5MB".
  - Source: [3DC Realtime Asset Creation Guidelines](https://github.com/mlimper/3DC-Asset-Creation/blob/main/asset-creation-guidelines/RealtimeAssetCreationGuidelines.md) (mirror of the Khronos 3DC repo; [Khronos announcement](https://www.khronos.org/blog/3d-commerce-working-group-releases-real-time-asset-creation-guidelines-to-assist-artists-create-efficient-reliable-models-for-retail-and-e-commerce))
- glTF accessors in gltf-transform: `accessor.getElement(i, [])` returns denormalized values (handles normalized UNSIGNED_BYTE/SHORT weights). `getArray()` returns the raw typed array. — **[verified locally]** in the weight-sum test below.

Example assertions:

**a) Weights, quaternions, NaNs, monotonic keys, grounded bbox** (from the passing suite) **[verified locally]**
```js
const doc = await new NodeIO().readBinary(bytes); const root = doc.getRoot();
for (const mesh of root.listMeshes()) for (const prim of mesh.listPrimitives()) {
  assert.ok(prim.getAttribute('POSITION').getArray().every(Number.isFinite), `${mesh.getName()} NaN/Inf`);
  assert.ok(prim.getAttribute('NORMAL'), `${mesh.getName()} has no NORMAL`);   // see note below
  const W = prim.getAttribute('WEIGHTS_0'); if (!W) continue;
  assert.ok(!prim.getAttribute('WEIGHTS_1'), '>4 influences');
  for (let i = 0; i < W.getCount(); i++) {
    const s = W.getElement(i, []).reduce((a, b) => a + b, 0);
    assert.ok(Math.abs(s - 1) < 1e-3, `vertex ${i} weight sum ${s}`);       // also catches unweighted verts (sum 0)
  }
}
for (const a of root.listAnimations()) for (const ch of a.listChannels()) {
  const t = ch.getSampler().getInput().getArray();
  for (let i = 1; i < t.length; i++) assert.ok(t[i] > t[i-1], `${a.getName()} keys not increasing`);
  if (ch.getTargetPath() === 'rotation') { const q = ch.getSampler().getOutput();
    for (let i = 0; i < q.getCount(); i++) assert.ok(Math.abs(Math.hypot(...q.getElement(i, [])) - 1) < 1e-4); }
}
const b = getBounds(root.getDefaultScene() ?? root.listScenes()[0]);   // from @gltf-transform/core
assert.ok(Math.abs(b.min[1]) < 1e-3, `not grounded: minY=${b.min[1]}`);
assert.ok(Math.abs((b.min[0] + b.max[0]) / 2) < 0.05 && Math.abs((b.min[2] + b.max[2]) / 2) < 0.05, 'origin not bottom-center');
const h = b.max[1] - b.min[1]; assert.ok(h > 1.5 && h < 2.5, `height ${h} m out of range`);
```
Note: the generated test rig had no NORMAL attribute. It passed the Khronos validator with **0 errors and 0 warnings**, yet it rendered pure black under `MeshStandardMaterial` in the Playwright snapshot **[verified locally]**. A "normals present" assertion is therefore worth having on its own.

**b) Outward normals and watertightness** (signed volume, edge-use counts, face-vs-vertex-normal agreement). Ran on the project's `barrel`, `cone` and `bale`: all had positive volume, 0 boundary edges, 0 non-manifold edges and 0 normal disagreements **[verified locally]**:
```js
const key = (P, i) => P.getElement(i, []).map(x => Math.round(x * 1e4)).join(','); // weld by position: UV/normal seams aren't holes
let vol = 0, disagree = 0; const edges = new Map(), a = [], b = [], c = [];
for (let i = 0; i < idx.length; i += 3) {
  P.getElement(idx[i], a); P.getElement(idx[i+1], b); P.getElement(idx[i+2], c);
  vol += (a[0]*(b[1]*c[2]-b[2]*c[1]) - a[1]*(b[0]*c[2]-b[2]*c[0]) + a[2]*(b[0]*c[1]-b[1]*c[0])) / 6;
  const u = [b[0]-a[0], b[1]-a[1], b[2]-a[2]], v = [c[0]-a[0], c[1]-a[1], c[2]-a[2]];
  const fn = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]];
  const n = N.getElement(idx[i], []); if (fn[0]*n[0] + fn[1]*n[1] + fn[2]*n[2] < 0) disagree++;
  for (const [p, q] of [[idx[i], idx[i+1]], [idx[i+1], idx[i+2]], [idx[i+2], idx[i]]]) {
    const kp = key(P, p), kq = key(P, q), k = kp < kq ? kp + '|' + kq : kq + '|' + kp;
    edges.set(k, (edges.get(k) ?? 0) + 1);
  }
}
assert.ok(vol > 0, 'inside-out (CW winding) or open mesh');
assert.equal([...edges.values()].filter(n => n === 1).length, 0, 'boundary edges (holes)');
assert.equal([...edges.values()].filter(n => n > 2).length, 0, 'non-manifold edges');
assert.equal(disagree, 0, 'vertex normals point against face winding');
```
Pitfall found **[verified locally]**: keying edges by vertex *index* reported 66 "boundary edges" on a closed barrel because flat-shaded or UV-seamed vertices are duplicated. Running gltf-transform `weld()` beforehand did not fix it, because weld only merges vertices whose attributes are all identical. Key edges by quantized position instead.

**c) Other quick checks (patterns, not individually run)**
- Required names: `for (const n of ['socket_hand','wheel_FL']) assert.ok(scene.getObjectByName(n))`. This is **[verified locally]** in the three.js test.
- Hierarchy shape: compare a serialized tree such as `name(children…)` against a golden string, for example `root.listScenes()[0].listChildren()` recursively.
- Forward axis: assert that the bbox center of a named "front" part (such as the `hood` or `head` node) has a greater z than the root.
- UV range: every `TEXCOORD_0` element must be in `[0,1]` unless the material has `KHR_texture_transform` or wrap=REPEAT is intended.
- Textures: `root.listTextures()` → `tex.getSize()` gives `[w,h]`. Assert `(w & (w-1)) === 0` and `w <= 2048`, and assert total `tex.getImage().byteLength` within budget.
- Budgets: validator `info.totalTriangleCount`, `drawCallCount`, `materialCount` and `maxInfluences`; joint count via `skin.listJoints().length`.
- Bone length: compare `node.getTranslation()` length for each joint across all animation keyframes of translation channels. Assert unchanged unless intended.

### Inferences
- Signed volume > 0 assumes a closed, CCW-wound mesh around a mostly convex region. For open meshes such as planes or foliage cards, skip it and use the normal-disagreement count only.
- Per-asset budgets and required names belong in a small JSON manifest (for example `models.json`: `{ "tractor": { "maxTris": 3000, "sockets": ["hitch"], "height": [1.8, 2.6] } }`). The test then iterates the manifest, which makes failures self-describing for an agent.

### Gaps
- I did not find an authoritative games-specific budget table (tris, draws, joints for web or mobile). The only sourced numbers are 3D Commerce figures (100k tris, 1K/2K textures, under 5 MB), which are generous for a small web game.

---

## 4. Animation behavioral tests (AnimationMixer in Node; bones, sockets, skinned vertices)

### Takeaway
In Node you can deterministically sample any clip with `mixer.setTime(t)`, then `scene.updateMatrixWorld(true)` and `skinnedMesh.skeleton.update()`. You can then assert world positions of bones or sockets and CPU-skinned vertex positions via `SkinnedMesh.getVertexPosition(i, v)`, which applies `applyBoneTransform`. That catches ground penetration, collapse or candy-wrapper artifacts, unresolved tracks and non-seamless loops, all without a GPU.

### Cited Findings
- `SkinnedMesh.applyBoneTransform(index, target)` "Applies the bone transform associated with the given index to the given vector", and `computeBoundingBox()` "If the skinned mesh is animated, the bounding box should be recomputed per frame" — [three.js SkinnedMesh docs](https://threejs.org/docs/pages/SkinnedMesh.html)
- In r186, `SkinnedMesh.getVertexPosition(index, target)` calls `super.getVertexPosition` and then `this.applyBoneTransform(index, target)`. `SkinnedMesh.computeBoundingBox()` uses `getVertexPosition`, so the bbox reflects the current pose. — three.js source `src/objects/SkinnedMesh.js` lines 125, 213–217 and 319 **[verified locally]**
- Track-target resolution: `THREE.PropertyBinding.parseTrackName(track.name).nodeName` plus `THREE.PropertyBinding.findNode(scene, nodeName)`. It reported 0 unresolved tracks across 8 clips of `chicken.glb`. — **[verified locally]**

Full passing test **[verified locally]**:
```js
test('three: names, track targets, socket motion, skinned verts', async () => {
  const gltf = await loadThree();                         // texture-stripped parse (section 2)
  const scene = gltf.scene;
  const clip = THREE.AnimationClip.findByName(gltf.animations, 'wave'); assert.ok(clip, 'clip missing');
  for (const t of clip.tracks) {
    const { nodeName } = THREE.PropertyBinding.parseTrackName(t.name);
    assert.ok(THREE.PropertyBinding.findNode(scene, nodeName), `track ${t.name} unresolved`);
  }
  const mixer = new THREE.AnimationMixer(scene); mixer.clipAction(clip).play();
  const sock = scene.getObjectByName('socket_hand'), p = new THREE.Vector3(), v = new THREE.Vector3();
  let skinned; scene.traverse(o => { if (o.isSkinnedMesh) skinned = o; });
  const pose = t => { mixer.setTime(t); scene.updateMatrixWorld(true); skinned.skeleton.update(); };
  pose(0); const tip0 = skinned.getVertexPosition(8, v).clone();
  for (let i = 0; i <= 20; i++) {
    pose(clip.duration * i / 20);
    assert.ok(sock.getWorldPosition(p).y >= 0, `socket below ground at step ${i}`);
    skinned.computeBoundingBox();
    assert.ok(skinned.boundingBox.getSize(new THREE.Vector3()).y > 1.2, `mesh collapsed at step ${i}`);
  }
  pose(clip.duration);
  assert.ok(skinned.getVertexPosition(8, v).distanceTo(tip0) < 1e-4, 'loop not seamless');
});
```
Further behavioral patterns built on the same primitives:
- **Wheel rotates N times**: sample the wheel's quaternion at small dt, accumulate the signed angle about its axle (`2*atan2(dot(q.xyz, axis), q.w)` deltas, unwrapped), and assert `≈ N·2π`.
- **Feet stay above ground**: assert world y ≥ −ε for foot bones or sockets at every sample. For a walk clip, also assert that at least one foot is within ε of the ground at each sample (no floating).
- **Candy-wrapper / volume loss**: at each sample, for vertices near a joint, compare the distance to the bone axis against the bind pose. Fail if it shrinks by more than about 30%. Cheaper alternative: per-frame skinned bbox extents stay within ±X% of bind.
- **Bone length preserved**: `bone.getWorldPosition()` distance to the parent stays constant (±1e-4) across samples.
- **Mixer setTime determinism**: two runs give identical numbers, so tolerances can be tight.

### Inferences
- Set the mixer time directly instead of calling `mixer.update(dt)` repeatedly, to avoid accumulating float drift and to keep tests order-independent.
- `skeleton.update()` is needed before `getVertexPosition` because it refreshes `boneMatrices`, which `applyBoneTransform` reads. The researcher included it and the test passed. Omitting it was not tested.

### Gaps
- I found no published "candy-wrapper detector" reference implementation. The thresholds above are heuristics to tune per rig.

---

## 5. Visual regression (render to PNG, pixelmatch/odiff, Playwright toHaveScreenshot, SwiftShader determinism)

### Takeaway
Headless Chromium from Playwright, launched with `--use-angle=swiftshader --enable-unsafe-swiftshader`, renders three.js r186 through software Vulkan (SwiftShader). In the researcher's runs it was **pixel-identical across two fresh pages** when the render loop was removed and a single frame was rendered at a fixed `mixer.setTime(t)`. Compare with pixelmatch (Node) or Playwright `toHaveScreenshot`, and generate baselines only in the same environment (same OS, browser build and SwiftShader).

### Cited Findings
- Playwright `toHaveScreenshot` options: `threshold` ("acceptable perceived color difference in the YIQ color space … Defaults to 0.2"), `maxDiffPixels`, `maxDiffPixelRatio`, `animations` (default "disabled", but this only affects CSS/Web animations), `mask`, `scale`, `caret`, `stylePath`. Baselines are updated with `--update-snapshots`. — [Playwright PageAssertions docs](https://playwright.dev/docs/api/class-pageassertions)
- Playwright waits for two consecutive identical screenshots before comparing. JS-driven animation (rAF, canvas) is not frozen by CSS animation disabling. Headless and headed rendering differ, so baselines should be captured in the same CI environment. — [TestQuality: Playwright visual regression guide](https://testquality.com/playwright-visual-regression-guide/), [Argos: fix flaky visual tests](https://argos-ci.com/blog/fix-flaky-visual-tests) (secondary sources)
- The researcher's run produced renderer string `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)` and `diffPixels 0` across two separate pages rendering `arm.glb` at t=0.5 s with `antialias:false`, `setPixelRatio(1)`, 256×256, with no rAF loop and `preserveDrawingBuffer:true` — **[verified locally]**
- Practical setup notes **[verified locally]**:
  - Serving local `node_modules/three` through `page.route('**/*', …)` with an importmap avoids running a dev server.
  - The npm `playwright@1.64` expected browser build 1248, which was not installed. Passing `executablePath` to an existing `chromium_headless_shell-1243` worked. Otherwise run `npx playwright install chromium`.
- model-viewer's `render-fidelity-tools` package keeps golden images per renderer (`npm run render-goldens`) and compares model-viewer (three.js) against filament, Babylon.js, the glTF Sample Viewer and others (`npm run test`). Results are published at modelviewer.dev/fidelity. — [model-viewer render-fidelity-tools](https://git.tdem.in/google/model-viewer/blob/master/packages/render-fidelity-tools) (mirror of google/model-viewer), [modelviewer.dev/fidelity](https://modelviewer.dev/fidelity)

Minimal harness (abridged from the verified script):
```js
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 256, height: 256 } });
await page.route('**/*', r => { const u = new URL(r.request().url());
  if (u.pathname === '/') return r.fulfill({ body: HTML, contentType: 'text/html' });
  if (u.pathname === '/model.glb') return r.fulfill({ path: MODEL });
  return r.fulfill({ path: path.join('node_modules', u.pathname) }); });   // /three/build/three.module.js etc.
await page.goto('http://test.local/'); await page.waitForFunction('window.ready');
await page.evaluate(() => window.renderAt(0.5));       // page: mixer.setTime(t); renderer.render(scene, cam)
const png = PNG.sync.read(await page.locator('canvas').screenshot());
const golden = PNG.sync.read(fs.readFileSync('test/golden/arm_t0.5.png'));
const diff = new PNG({ width: 256, height: 256 });
const n = pixelmatch(png.data, golden.data, diff.data, 256, 256, { threshold: 0.1 });
if (n > 50) fs.writeFileSync('test/out/arm_t0.5.diff.png', PNG.sync.write(diff));
assert.ok(n <= 50, `${n} px differ; see test/out/arm_t0.5.diff.png`);
```
The same thing as a Playwright test: `await expect(page.locator('canvas')).toHaveScreenshot('arm-t0.5.png', { maxDiffPixelRatio: 0.001 })`.

### Inferences
- Determinism checklist: fixed viewport and `setPixelRatio(1)`; `antialias:false`; no rAF loop (render exactly once after `setTime`); fixed camera and lights; no `Math.random` in the scene; tone mapping and color space set explicitly; a SwiftShader-pinned browser build. Cross-machine GPU rendering will not be byte-identical, so keep goldens to one CI image.
- Visual tests are slow and brittle, so keep them few: one or two "turntable" angles per model and one mid-animation pose per key clip. Let data-level tests (sections 1, 3 and 4) carry most of the assertions.
- Visual checks catch problems data checks miss, such as the black rendering caused by missing normals, wrong material or colour space, and inverted alpha.

### Gaps
- I did not test stability across Playwright or Chromium version bumps. Expect to refresh goldens on browser upgrades. odiff was not evaluated (pixelmatch was used).

---

## 6. How teams lint 3D assets in CI

### Takeaway
Public practice converges on three layers: (1) the Khronos glTF-Validator as a spec gate, (2) a configurable "asset rules" validator for budgets and product conventions (the Khronos 3D Commerce Asset Validator is the most concrete public example), and (3) golden-image render comparisons (model-viewer's render-fidelity tools). For a small three.js game, a `node --test` suite combining all three layers is enough.

### Cited Findings
- The Khronos 3D Commerce Asset Validator (`@mikefesta/3dc-validator`):
  - Checks: "File Size, Triangle Count, Material Count, Node Count, Mesh Count, Primitive Count, Clean Origin for Root Node, Beveled Edges, Non-Manifold Edges, Dimensions, Dimensions (product within tolerance), PBR Safe Colors, Texture Map Resolution, Texture Map Resolution Power of 2, Texture Map Resolution Quadratic, Texel Density, 0-1 UV Texture Space, Inverted UVs, UV Overlaps, UV Gutter Width".
  - It is configured by a JSON schema with min/max per metric (`fileSizeInKb`, `model.triangles`, `materials`, `textures.width/height`, `product.dimensions` with `percentTolerance`).
  - It has a CLI and a web interface and reports each test as "Pass, Fail, or Not Tested".
  - Edge and UV-overlap checks are marked SLOW (O(n log n)).
  - Source: [3dc-validator README](https://cdn.jsdelivr.net/npm/@mikefesta/3dc-validator@1.0.0/README.md)
- The Vulkan tutorial's production-pipeline chapter recommends the CLI glTF-Validator as "the right choice for integration into a production pipeline". It lists caught issues such as misaligned accessor offsets, skin joints outside the scene, non-monotonic animation inputs, overlapping buffer views and morph-target count mismatches. — [Vulkan docs: Validation with the Khronos glTF-Validator](https://docs.vulkan.org/tutorial/latest/Advanced_glTF/Tooling_Production_Pipeline/03_validation.html)
- tinygltf added a non-blocking glTF-Validator CI step that runs over tracked glTF files — [tinygltf commit (googlesource mirror)](https://flutter.googlesource.com/third_party/tinygltf/+/refs/heads/copilot/add-gltf-validation-feature%5E%21/)
- model-viewer runs render-fidelity golden comparisons across renderers (see section 5) — [render-fidelity-tools](https://git.tdem.in/google/model-viewer/blob/master/packages/render-fidelity-tools)

Suggested single-command layout for this repo (inference, built on the verified pieces):
```
package.json   "test": "node --test test/"          (already present)
test/models.test.mjs    for each assets/models/*.glb + manifest entry:
  1. validator gate (sev ≤ 1 fails; allow NODE_EMPTY)           ~20 ms/model
  2. gltf-transform data checks (NaN, normals, weights, quats, keys, bbox, budgets, textures POT)
  3. three.js parse (textures stripped): names/sockets, track binding, mixer sampling assertions
test/models.visual.mjs  (opt-in: npm run test:visual) Playwright+SwiftShader goldens
```
Machine-readable output: `node --test --test-reporter=tap test/` or `--test-reporter=junit --test-reporter-destination=report.xml`. For per-file JSON, `gltf-transform validate x.glb --format csv`, or write `JSON.stringify(report)` from `validateBytes` to `reports/`.

### Inferences
- For LLM-authored or procedural models, failure messages should name the node, mesh or accessor and the measured versus expected value, because the agent feeds the failure text straight back into regeneration. The `pointer` field from the validator and the template-string assertion messages above do this.
- The 3DC validator's schema approach (per-asset min/max JSON) is a good model for this game's manifest even without adopting the package. Its product-retail checks (PBR-safe colours, texel density) matter less for a stylized low-poly game.

### Gaps
- I found no detailed public write-ups from game studios on glTF asset-lint CI (studio pipelines are mostly proprietary or engine-specific, for example Unreal/Unity asset validators). The Shopify/Google model-viewer guidance beyond render-fidelity tooling was not researched within the tool budget. I did not test whether the 3dc-validator package still installs and runs with current Node.
