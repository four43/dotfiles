# three.js reference (r186, Sept 2026)

Releases ship every 2–3 months, and APIs get deprecated quickly. Check the
[Migration Guide](https://github.com/mrdoob/three.js/wiki/Migration-Guide) before
trusting older tutorials.

## Install and imports

- Run `npm i three` (types are in `@types/three`) and use Vite with no config. `npx vite` starts the dev server and `npx vite build` builds.
- `import * as THREE from 'three'` and `import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js'`
- Package exports:
  - `three`
  - `three/addons/*` → `examples/jsm/*`
  - `three/webgpu`
  - `three/tsl`
- CDN import map with no build step. Pin one version and use one CDN:
  ```json
  {"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.186.1/build/three.module.js",
              "three/addons/":"https://cdn.jsdelivr.net/npm/three@0.186.1/examples/jsm/"}}
  ```

## Renderer choice

- **`WebGLRenderer`** is stable and recommended for WebGL 2. Use it for most Kenney-style games.
- **`WebGPURenderer`** (`import * as THREE from 'three/webgpu'`) is still labelled experimental, but it is mature.
  - It falls back to WebGL 2 automatically. Pass `forceWebGL: true` to force that.
  - Call `await renderer.init()` before any render, clear, or `KTX2Loader.detectSupport()` outside `setAnimationLoop`.
  - It has no `ShaderMaterial`, `RawShaderMaterial`, or `onBeforeCompile`. Write shaders with TSL node materials instead.
  - Post-processing uses `RenderPipeline` (renamed from `PostProcessing` in r183), not `EffectComposer`.

## Game-loop essentials

- `renderer.setAnimationLoop(fn)` replaces raw `requestAnimationFrame` and works with XR and WebGPU.
- **`THREE.Timer`** replaces the deprecated `Clock` (since r183). Call `timer.connect(document)` so that hidden tabs don't produce huge deltas. Each frame, call `timer.update(t)` and then `getDelta()`.
- Call `renderer.setPixelRatio(Math.min(devicePixelRatio, 2))`.
- On resize, set `camera.aspect`, call `updateProjectionMatrix()`, then `renderer.setSize(w, h)`.
- Colour: output is sRGB by default. Set `tex.colorSpace = THREE.SRGBColorSpace` on colour textures you load manually. GLTFLoader handles this for you.

## Loading and animation

- `GLTFLoader.loadAsync(url)`. For compressed assets, add:
  - `setDRACOLoader(new DRACOLoader().setDecoderPath(...))`
  - `setKTX2Loader(new KTX2Loader().setTranscoderPath(...).detectSupport(renderer))`
  - `setMeshoptDecoder(MeshoptDecoder)` from `three/addons/libs/meshopt_decoder.module.js`
- Clone skinned models with `import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js'` and `SkeletonUtils.clone(gltf.scene)`.
- Animation: create one `new AnimationMixer(root)` per character and call `mixer.clipAction(clip)`. Blend with `.fadeIn`, `.fadeOut`, and `.crossFadeTo`. Call `mixer.update(dt)` every frame.

## Performance

- `InstancedMesh` handles one geometry and material with many transforms. Call `setMatrixAt`, then set `instanceMatrix.needsUpdate = true`.
- `BatchedMesh` handles many geometries that share one material. Check the constructor signature in the docs.
- Shadows:
  - Use one directional light with a tight shadow camera frustum and a 1024–2048 map.
  - Set `castShadow` and `receiveShadow` selectively.
  - Use `PCFShadowMap`, because `PCFSoftShadowMap` was removed in r186.
- Disposal: call `geometry.dispose()`, `material.dispose()`, and `texture.dispose()` explicitly. `Object3D.dispose()` (new in r186) only fires an event.
- Built-in Rapier helper: `three/addons/physics/RapierPhysics.js` is handy for demos. It loads Rapier 0.17 from a CDN, so install `@dimforge/rapier3d-compat` yourself for real projects.

## URLs

- Docs: https://threejs.org/docs/. Class pages look like https://threejs.org/docs/pages/GLTFLoader.html, e.g. `Timer.html`, `WebGPURenderer.html`, `InstancedMesh.html`, `BatchedMesh.html`, `AnimationMixer.html`, `module-SkeletonUtils.html`.
- Manual: https://threejs.org/manual/. Useful topics:
  - `#en/load-gltf`
  - `#en/game` (game architecture)
  - `#en/physics`
  - `#en/cleanup`
  - `#en/color-management`
  - `#en/responsive`
  - `#en/optimize-lots-of-objects`
- Installation: https://threejs.org/manual/pages/installation.html
- WebGPU renderer: https://threejs.org/manual/pages/webgpurenderer.html
- TSL: https://github.com/mrdoob/three.js/wiki/Three.js-Shading-Language
- Examples: https://threejs.org/examples/. Relevant ones:
  - `#webgl_loader_gltf`
  - `#webgl_loader_gltf_compressed`
  - `#webgl_animation_skinning_blending`
  - `#webgl_animation_multiple` (SkeletonUtils clones)
  - `#webgl_instancing_performance`
  - `#webgl_mesh_batch`
  - `#physics_rapier_instancing`
- Migration guide: https://github.com/mrdoob/three.js/wiki/Migration-Guide
- Releases: https://github.com/mrdoob/three.js/releases
- Forum: https://discourse.threejs.org/
