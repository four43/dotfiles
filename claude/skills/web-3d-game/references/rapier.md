# Rapier (JS) reference (0.21, Sept 2026)

**The repo moved.** `dimforge/rapier.js` was archived on 2026-07-12. The JS bindings now live in
https://github.com/dimforge/rapier/tree/master/bindings/typescript (the CHANGELOG is in that folder).

Recent changes:
- **0.20** reworked sleeping and turned on sweep-based CCD against fixed colliders by default. It also moved the compat files into `dist/`.
- **0.21** added soft bodies (rope and cloth). Tutorials written before 0.20 may be stale.

## Packages

| Package | Use |
|---|---|
| `@dimforge/rapier3d-compat` | **Default.** The WASM is inlined as base64 (~4 MB), and it works in Vite with no plugins. |
| `@dimforge/rapier3d` | Smaller, but uses ESM WASM imports, so Vite needs `vite-plugin-wasm` and `vite-plugin-top-level-await`. |
| `-simd` / `-simd-compat` | Faster. Needs wasm simd128 support. |
| `-deterministic` / `-deterministic-compat` | Gives identical results across platforms, for lockstep or rollback netcode. |

```js
import RAPIER from '@dimforge/rapier3d-compat';
await RAPIER.init(); // before ANY other call
```

## Core API cheat sheet

- **World**
  - `new RAPIER.World({x:0,y:-9.81,z:0})`
  - `world.timestep = 1/60`
  - `world.step(eventQueue?)`
  - Tuning: `numSolverIterations`, `maxCcdSubsteps`, `lengthUnit`
- **Bodies:** `world.createRigidBody(RigidBodyDesc.dynamic() | .fixed() | .kinematicPositionBased() | .kinematicVelocityBased())`
  - Desc setters: `.setTranslation`, `.setRotation`, `.setLinearDamping`, `.setGravityScale`, `.enabledRotations(x,y,z)` (to lock axes), `.setCcdEnabled`, `.setCanSleep`
  - At runtime: `body.translation()` and `body.rotation()` return plain objects that `Vector3.copy` and `Quaternion.copy` accept.
- **Colliders:** `world.createCollider(desc, body)`. Shapes:
  - `cuboid(hx,hy,hz)` takes **half-extents**.
  - `ball(r)`
  - `capsule(halfHeight, r)`, where halfHeight covers the cylinder part only.
  - `cylinder(halfHeight, r)`
  - `trimesh(Float32Array, Uint32Array)`
  - `convexHull(Float32Array)`, which returns **`ColliderDesc | null`**.
  - `heightfield(...)`, which takes column-major heights. Check the docs for the rows/cols meaning.
- **Collider properties:** `setFriction`, `setRestitution`, `setDensity`/`setMass`, `setSensor(true)`, `setActiveEvents(ActiveEvents.COLLISION_EVENTS)`, `setCollisionGroups`, `setSolverGroups`
- **Collision groups:** a 32-bit value, `(memberships << 16) | filter`. Two colliders interact iff each one's membership bits intersect the other's filter.
- **Kinematic/fixed pairs:** these are not detected by default. Add `setActiveCollisionTypes(ActiveCollisionTypes.DEFAULT | ActiveCollisionTypes.KINEMATIC_FIXED)`.
- **Events:**
  - `const eq = new RAPIER.EventQueue(true)`, then `world.step(eq)`.
  - `eq.drainCollisionEvents((h1, h2, started) => …)` gives collider handles; look them up with `world.getCollider(h)`.
  - `drainContactForceEvents` is also available.
- **Raycast:**
  - `world.castRay(new RAPIER.Ray(o, d), maxToi, solid, filterFlags?, groups?, excludeCollider?, excludeBody?, predicate?)`
  - The hit has `.collider` and `.timeOfImpact`. The point is `ray.pointAt(hit.timeOfImpact)`.
  - Related: `castRayAndGetNormal`, `intersectionsWithRay`, `castShape`, `projectPoint`.
- **Character controller:**
  ```js
  const cc = world.createCharacterController(0.01);           // skin offset
  cc.setUp({x:0,y:1,z:0}); cc.setMaxSlopeClimbAngle(45*Math.PI/180);
  cc.setMinSlopeSlideAngle(30*Math.PI/180);
  cc.enableAutostep(0.3, 0.2, true); cc.enableSnapToGround(0.3);
  cc.setApplyImpulsesToDynamicBodies(true);
  // each fixed step (gravity is YOUR job):
  vel.y = cc.computedGrounded() ? 0 : vel.y - 9.81 * STEP;
  cc.computeColliderMovement(collider, { x: vel.x*STEP, y: vel.y*STEP, z: vel.z*STEP });
  const m = cc.computedMovement(), p = body.translation();
  body.setNextKinematicTranslation({ x: p.x+m.x, y: p.y+m.y, z: p.z+m.z }); // absolute!
  ```
  To inspect what the character hit, loop over `numComputedCollisions()` and call `computedCollision(i)`.
- **Debug:** `const {vertices, colors} = world.debugRender()`. Pass these to `BufferGeometry` and draw with `LineSegments` and `vertexColors`. Colors are RGBA, so the item size is 4.
- **Memory and state:**
  - `world.free()`, `eq.free()`, `world.removeCharacterController(cc)`
  - `world.takeSnapshot()` returns a `Uint8Array`. Restore with `RAPIER.World.restoreSnapshot(bytes)`.

## Alternatives

`@react-three/rapier` (pmndrs) is a React Three Fiber wrapper. It provides `<Physics>`,
`<RigidBody>`, and auto-colliders: https://github.com/pmndrs/react-three-rapier

## URLs

- Getting started: https://rapier.rs/docs/user_guides/javascript/getting_started_js
- Rigid bodies: https://rapier.rs/docs/user_guides/javascript/rigid_bodies
- Colliders: https://rapier.rs/docs/user_guides/javascript/colliders
- Character controller: https://rapier.rs/docs/user_guides/javascript/character_controller
- Scene queries (raycasts and shape casts): https://rapier.rs/docs/user_guides/javascript/scene_queries
- Events, sensors and collision groups: https://rapier.rs/docs/user_guides/javascript/advanced_collision_detection_js
- Debug render: https://rapier.rs/docs/user_guides/javascript/debug_render
- Serialization: https://rapier.rs/docs/user_guides/javascript/serialization
- Determinism: https://rapier.rs/docs/user_guides/javascript/determinism
- Common mistakes: https://rapier.rs/docs/user_guides/javascript/common_mistakes
- API reference: https://rapier.rs/javascript3d/ (e.g. https://rapier.rs/javascript3d/classes/World.html)
- Demos: https://rapier.rs/demos3d/index.html
- Source and testbed: https://github.com/dimforge/rapier/tree/master/bindings/typescript
- Discord: https://discord.gg/vt9DJSW
