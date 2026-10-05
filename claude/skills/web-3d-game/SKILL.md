---
name: web-3d-game
description: >
  Use when building or debugging a browser 3D game with three.js, Rapier
  physics (@dimforge/rapier3d), and/or Kenney 3D assets (kenney.nl GLB kits) —
  scene setup, physics/render sync, character controllers, loading Kenney
  models, missing or black textures, jittery physics, colliders from GLTF.
---

# Web 3D Game: three.js + Rapier + Kenney

Three.js draws the scene. Rapier simulates the physics. Kenney supplies free CC0 low-poly models.
The integration rule is that **physics owns the transform and three.js only displays it**.
Rapier steps at a fixed rate, and each mesh copies or interpolates its body's pose every frame.

Versions as of 2026-10: three r186, `@dimforge/rapier3d-compat` 0.21. Both move quickly, so check
the releases before trusting any API detail below.

| Topic | Reference file |
|---|---|
| three.js renderer, loaders, animation, perf, doc URLs | [references/threejs.md](references/threejs.md) |
| Rapier packages, API, character controller, doc URLs | [references/rapier.md](references/rapier.md) |
| Kenney packs, file layout, scale/pivots, gotchas, URLs | [references/kenney.md](references/kenney.md) |

## Project setup (Vite)

```bash
npm i three @dimforge/rapier3d-compat && npm i -D vite @types/three
```

- Use **`@dimforge/rapier3d-compat`**. It inlines the WASM, so Vite needs no plugins. Call `await RAPIER.init()` before using any Rapier API.
- Use **`WebGLRenderer`** by default. `WebGPURenderer` (`three/webgpu`) is still marked experimental, and it does not support `ShaderMaterial` or `EffectComposer`. Choose it only when you need TSL or compute.
- Put Kenney packs under `public/models/<pack>/` and **keep the `Textures/` folder next to the `.glb` files**.

## Core loop: fixed-step physics with render interpolation

```js
import * as THREE from 'three';
import RAPIER from '@dimforge/rapier3d-compat';
await RAPIER.init();

const world = new RAPIER.World({ x: 0, y: -9.81, z: 0 });
const STEP = 1 / 60; world.timestep = STEP;
const events = new RAPIER.EventQueue(true);
const timer = new THREE.Timer(); timer.connect(document); // Clock is deprecated (r183+)
const entities = []; // { body, object3d, prev: {p, q}, curr: {p, q} }
let acc = 0;

renderer.setAnimationLoop((t) => {
  timer.update(t);
  const dt = Math.min(timer.getDelta(), 0.25);
  acc += dt;           // avoid a spiral of death after tab switches
  while (acc >= STEP) {
    for (const e of entities) e.prev = snapshot(e.body);
    world.step(events);
    events.drainCollisionEvents((h1, h2, started) => onCollision(h1, h2, started));
    acc -= STEP;
  }
  const alpha = acc / STEP;
  for (const e of entities) {
    const c = snapshot(e.body);
    e.object3d.position.lerpVectors(e.prev.p, c.p, alpha);
    e.object3d.quaternion.slerpQuaternions(e.prev.q, c.q, alpha);
  }
  mixers.forEach((m) => m.update(dt));
  renderer.render(scene, camera);
});

const snapshot = (b) => ({
  p: new THREE.Vector3().copy(b.translation()),
  q: new THREE.Quaternion().copy(b.rotation()),
});
```

For a quick prototype, you can skip interpolation and use `mesh.position.copy(body.translation())`.

## Integration rules

1. **Units are meters, and Kenney tiles are 1 unit.** Rapier is tuned for meter-scale objects. Don't scale Kenney models up by 100. Scale the camera to them instead. Platformer characters are about 0.9 m tall.
2. **Size colliders from the tile or design size, not blindly from `Box3`.** Kenney pivots are bottom-centre in the newer packs and a corner in the older Racing and Furniture packs. Some blocks have overhang lips. `cuboid()` takes **half-extents**. Offset the collider with `ColliderDesc.setTranslation(0, h/2, 0)` for bottom pivots.
3. **Choose shapes by body type.** Use `trimesh` only on **fixed** level geometry. Dynamic bodies get primitives, compounds, or `convexHull` (which can return `null`). Bake world scale into the vertices before you build a mesh collider.
4. **Use a kinematic body plus Rapier's `KinematicCharacterController` for the player.** Add gravity to the desired delta yourself. Apply the result with `body.setNextKinematicTranslation(pos + computedMovement())`, using the absolute position. The official docs snippet gets this wrong.
5. **Use kinematic bodies for moving platforms and doors.** A teleported fixed body won't push anything.
6. **Put the physics body's pose on a parent `Group`.** Load the model as a child of that group. This keeps visual offsets, scale, and skinned meshes separate from the physics transform.
7. **Clone animated characters with `SkeletonUtils.clone`** and give each clone its own `AnimationMixer`. Kenney clip names are lowercase, e.g. `idle`, `walk`, `sprint`, `jump`. Look them up with `AnimationClip.findByName`.
8. **Collision events need an opt-in on the collider:** `setActiveEvents(RAPIER.ActiveEvents.COLLISION_EVENTS)`. Events return collider *handles*. Keep a `Map<handle, entity>`.
9. **Pair kinematic and fixed bodies explicitly when sensors need it.** A kinematic sensor that must detect fixed geometry needs `setActiveCollisionTypes(DEFAULT | KINEMATIC_FIXED)`.
10. **Toggle a debug view.** `world.debugRender()` returns `{vertices, colors}` for a `THREE.LineSegments`. Colors are RGBA, so use item size 4.
11. **Share Kenney GLBs and use instances.** Many copies of one tile should become `InstancedMesh`, or `BatchedMesh` when the geometries differ. Cache each loaded `gltf` and clone from it rather than calling `load()` again.
12. **Free WASM memory.** Remove bodies and colliders from the world. Call `.free()` on queues and the world. Call `dispose()` on three.js geometries, materials, and textures, because `Object3D.dispose()` does not free them.

## Common mistakes

| Symptom | Cause / fix |
|---|---|
| Kenney model is grey or white, with a "Couldn't load texture" warning | `Textures/colormap.png` was not served next to the `.glb`, or the bundler hashed the GLB URL. Serve from `public/` or call `loader.setResourcePath`. |
| Nature, Space, or other older Kenney packs render black | Their materials have `metallicFactor: 1`. Set `metalness = 0`, or add an environment map (`RoomEnvironment` + `PMREMGenerator`). |
| Colormap colours bleed at a distance | Set `NearestFilter` on the palette texture. |
| Physics runs fast on 120/144 Hz monitors, or jitters | The code steps once per frame. Use the fixed-step accumulator above. |
| `RAPIER.World is not a constructor` or the WASM fails to load | `await RAPIER.init()` was not called. Or the non-compat package is in use without `vite-plugin-wasm`. |
| Ray hit `.toi` is undefined | The field is now `hit.timeOfImpact`, so use `ray.pointAt(hit.timeOfImpact)`. |
| Objects sink or tunnel through thin floors | The objects are too small or too fast. Use `setCcdEnabled(true)` on the fast bodies, and check the collider half-extents. |
| A cloned character's animation is frozen, or all clones move together | The code used `.clone()` instead of `SkeletonUtils.clone`, or the clones share one mixer. |
| `PCFSoftShadowMap` deprecation warning | It was removed in r186. Use `PCFShadowMap`. |
| Huge `dt` after returning to the tab | Call `timer.connect(document)` and clamp the delta. |
