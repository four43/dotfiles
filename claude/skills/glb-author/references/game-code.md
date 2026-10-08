# Using the GLB in three.js game code

```js
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

const gltf = await new GLTFLoader().loadAsync('/assets/models/wagon.glb');
const template = gltf.scene;                       // keep as a template
const wagon = SkeletonUtils.clone(template);       // per instance; plain .clone() breaks skinned meshes
scene.add(wagon);

// sockets / pivots by name (names are exactly as authored when they use A-Z a-z 0-9 _ -)
const hitch = wagon.getObjectByName('Socket_Hitch');
hitch.add(ropeMesh);                               // child follows the socket, animation included
const p = hitch.getWorldPosition(new THREE.Vector3());

// animation: one mixer per instance, clips by name
const mixer = new THREE.AnimationMixer(wagon);
const clip = name => THREE.AnimationClip.findByName(gltf.animations, name);
const walk = mixer.clipAction(clip('Walk'));
const idle = mixer.clipAction(clip('Idle'));
idle.play();
// switch: fade over 0.25 s. Clips should key every node the other clip moves, or that node keeps its last pose.
function setMoving(moving) {
  const [from, to] = moving ? [idle, walk] : [walk, idle];
  to.reset().play(); from.crossFadeTo(to, 0.25, false);
}
// one-shot clip: stop on last frame
const wave = mixer.clipAction(clip('Wave')); wave.setLoop(THREE.LoopOnce, 1); wave.clampWhenFinished = true;

// in the frame loop
mixer.update(dt);
// match walk playback to ground speed to stop foot sliding: stride = distance per cycle
walk.timeScale = speed / STRIDE_METERS_PER_CYCLE;

// wheels driven by code instead of a clip (rotation about the node's own X; front faces +Z)
wagon.getObjectByName('wheel_FL').rotation.x += (speed * dt) / WHEEL_RADIUS;

// shadows
wagon.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
```

Notes:
- The model faces +Z. To face a heading angle `a` (0 = +Z), set `wagon.rotation.y = a`. `Object3D.lookAt` points +Z at its target, for non-camera objects.
- `userData` holds the node `extras` (e.g. `userData.socket === true`).
- Never mutate `gltf.scene` once instances exist; clone it.
- Dispose the template's geometries and materials when the level unloads.
