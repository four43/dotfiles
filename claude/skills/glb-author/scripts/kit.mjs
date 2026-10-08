// glb-author kit: build a GLB from code. Shapes come from three.js geometry; nodes, materials, skins and clips are
// written with glTF-Transform. Conventions: meters, +Y up, the model's front faces +Z, origin at bottom-center.
// Usage (from a <name>.model.mjs anywhere on disk):
//   import { model } from '/abs/path/to/glb-author/scripts/kit.mjs';
//   const m = model('cart');
//   m.part('bed', m.box(1.2, 0.2, 0.8), { at: [0, 0.5, 0], color: '#a0522d' });
//   await m.write('cart.glb');
import fs from 'node:fs';
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { Document, NodeIO, Logger } from '@gltf-transform/core';
import { ALL_EXTENSIONS, KHRMaterialsUnlit } from '@gltf-transform/extensions';
import { dedup, prune } from '@gltf-transform/functions';
import { PNG } from 'pngjs';

export { THREE };
export const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const NAME = /^[A-Za-z0-9_-]+$/;
const D2R = Math.PI / 180;

const fail = msg => { throw new Error(`[kit] ${msg}`); };
const vec3 = (v, what) => {
  if (!Array.isArray(v) || v.length !== 3 || !v.every(Number.isFinite)) fail(`${what} must be [x, y, z] numbers, got ${JSON.stringify(v)}`);
  return v;
};
const eulerQuat = deg => new THREE.Quaternion().setFromEuler(new THREE.Euler(deg[0] * D2R, deg[1] * D2R, deg[2] * D2R, 'XYZ'));

/** Make a PNG (Uint8Array) from a pixel function (u, v in 0..1, v=0 at top) => [r, g, b] or [r, g, b, a] (0-255). */
export function png(width, height, pixel) {
  const img = new PNG({ width, height });
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const c = pixel((x + 0.5) / width, (y + 0.5) / height, x, y), i = (y * width + x) * 4;
    img.data[i] = c[0]; img.data[i + 1] = c[1]; img.data[i + 2] = c[2]; img.data[i + 3] = c[3] ?? 255;
  }
  return new Uint8Array(PNG.sync.write(img));
}

export function model(name, { flat = true } = {}) {
  if (!NAME.test(name)) fail(`model name "${name}" must match ${NAME}`);
  const doc = new Document().setLogger(new Logger(Logger.Verbosity.WARN));
  const buffer = doc.createBuffer();
  const root = doc.createNode(name);
  const scene = doc.createScene('Scene').addChild(root); // not `name`: three.js would rename the root to name_1
  const nodes = new Map([[name, root]]);
  const bones = new Set();
  const materials = new Map();
  const acc = (type, array) => doc.createAccessor().setType(type).setArray(array).setBuffer(buffer);

  const nodeOf = ref => {
    if (ref == null) return root;
    if (typeof ref !== 'string') return ref;
    return nodes.get(ref) || fail(`no node named "${ref}". Known: ${[...nodes.keys()].join(', ')}`);
  };
  const worldMatrix = node => new THREE.Matrix4().fromArray(node.getWorldMatrix());

  function newNode(nm, { parent, at, world, rot, scale, extras } = {}) {
    if (!NAME.test(nm)) fail(`name "${nm}" must match ${NAME} (three.js renames anything else, so getObjectByName and clips break)`);
    if (nodes.has(nm)) fail(`duplicate name "${nm}"`);
    const p = nodeOf(parent), n = doc.createNode(nm);
    p.addChild(n);
    if (at && world) fail(`${nm}: give either at (parent-local) or world, not both`);
    if (at) n.setTranslation(vec3(at, `${nm}.at`));
    if (world) n.setTranslation(new THREE.Vector3(...vec3(world, `${nm}.world`)).applyMatrix4(worldMatrix(p).invert()).toArray());
    if (rot) n.setRotation(eulerQuat(vec3(rot, `${nm}.rot`)).toArray());
    if (scale) n.setScale(typeof scale === 'number' ? [scale, scale, scale] : vec3(scale, `${nm}.scale`));
    if (extras) n.setExtras(extras);
    nodes.set(nm, n);
    return n;
  }

  function material(nm, { color = '#ffffff', roughness = 0.85, metalness = 0, map, opacity = 1, unlit = false, doubleSided = false } = {}) {
    const key = nm ?? JSON.stringify({ color, roughness, metalness, opacity, unlit, doubleSided, map: map?.getName?.() });
    if (materials.has(key)) return materials.get(key);
    const c = new THREE.Color(color); // hex/CSS is sRGB; THREE.Color stores linear, which is what glTF factors want
    const mat = doc.createMaterial(nm ?? `mat_${c.getHexString()}${map ? '_' + (map.getName() || 'tex') : ''}`)
      .setBaseColorFactor([c.r, c.g, c.b, opacity]).setRoughnessFactor(roughness).setMetallicFactor(metalness)
      .setDoubleSided(doubleSided);
    if (opacity < 1) mat.setAlphaMode('BLEND');
    if (map) mat.setBaseColorTexture(map);
    if (unlit) mat.setExtension('KHR_materials_unlit', doc.createExtension(KHRMaterialsUnlit).createUnlit());
    materials.set(key, mat);
    return mat;
  }

  function texture(nm, { image, file, width = 64, height = 64, pixel } = {}) {
    const bytes = image ?? (file ? new Uint8Array(fs.readFileSync(file)) : png(width, height, pixel));
    return doc.createTexture(nm).setImage(bytes).setMimeType('image/png');
  }

  // three geometry (already placed) -> glTF primitive
  function dropDegenerate(g) { // zero-area triangles (e.g. a lathe point at radius 0) break flat normals
    const P = g.attributes.position, a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3();
    const area = (i, j, k) => { a.fromBufferAttribute(P, i); b.fromBufferAttribute(P, j); c.fromBufferAttribute(P, k); return b.sub(a).cross(c.sub(a)).lengthSq(); };
    if (g.index) { const I = g.index.array, keep = []; for (let t = 0; t < I.length; t += 3) if (area(I[t], I[t + 1], I[t + 2]) > 1e-14) keep.push(I[t], I[t + 1], I[t + 2]); if (keep.length < I.length) g.setIndex(keep); return g; }
    const keepTri = []; for (let t = 0; t < P.count; t += 3) if (area(t, t + 1, t + 2) > 1e-14) keepTri.push(t);
    if (keepTri.length * 3 === P.count) return g;
    const out = new THREE.BufferGeometry();
    for (const [k, attr] of Object.entries(g.attributes)) { const n = attr.itemSize, arr = new attr.array.constructor(keepTri.length * 3 * n); keepTri.forEach((t, j) => arr.set(attr.array.subarray(t * n, (t + 3) * n), j * 3 * n)); out.setAttribute(k, new THREE.BufferAttribute(arr, n, attr.normalized)); }
    return out;
  }

  function primitive(geo, mat, skinData) {
    let g = dropDegenerate(geo.index && flat ? geo.toNonIndexed() : geo.clone());
    if (flat || !g.attributes.normal) { g.deleteAttribute('normal'); g.computeVertexNormals(); }
    const prim = doc.createPrimitive().setMaterial(mat)
      .setAttribute('POSITION', acc('VEC3', new Float32Array(g.attributes.position.array)))
      .setAttribute('NORMAL', acc('VEC3', new Float32Array(g.attributes.normal.array)));
    if (g.attributes.uv) prim.setAttribute('TEXCOORD_0', acc('VEC2', new Float32Array(g.attributes.uv.array)));
    if (g.index) prim.setIndices(acc('SCALAR', g.attributes.position.count > 65535 ? new Uint32Array(g.index.array) : new Uint16Array(g.index.array)));
    if (skinData) {
      const { joints, weights } = skinData(g.attributes.position);
      prim.setAttribute('JOINTS_0', acc('VEC4', joints)).setAttribute('WEIGHTS_0', acc('VEC4', weights));
    }
    return prim;
  }

  // anchor: which point of the shape's bounding box sits at the node origin (the pivot); 'none' = leave the shape where it is
  function placeGeometry(geo, { anchor = 'center', offset, geoRot } = {}) {
    const g = geo.clone();
    if (geoRot) g.applyQuaternion(eulerQuat(vec3(geoRot, 'geoRot')));
    if (anchor === 'none') { if (offset) g.translate(...vec3(offset, 'offset')); return g; }
    g.computeBoundingBox();
    const b = g.boundingBox, c = b.getCenter(new THREE.Vector3());
    const ax = { center: [c.x, c.y, c.z], bottom: [c.x, b.min.y, c.z], top: [c.x, b.max.y, c.z],
      back: [c.x, c.y, b.min.z], front: [c.x, c.y, b.max.z], left: [b.min.x, c.y, c.z], right: [b.max.x, c.y, c.z] }[anchor];
    if (!ax) fail(`anchor "${anchor}" must be center|bottom|top|front|back|left|right|none`);
    g.translate(-ax[0], -ax[1], -ax[2]);
    if (offset) g.translate(...vec3(offset, 'offset'));
    return g;
  }

  const matFor = o => o.material ?? material(null, { color: o.color, map: o.map, roughness: o.roughness, metalness: o.metalness, opacity: o.opacity, unlit: o.unlit, doubleSided: o.doubleSided });

  const api = {
    doc, root, scene, THREE,
    // ---- shapes (three.js geometry, centered on the origin; part() moves them by anchor) ----
    box: (w, h, d, seg = [1, 1, 1]) => new THREE.BoxGeometry(w, h, d, ...seg),
    cyl: (rTop, rBottom, h, sides = 8, hSeg = 1) => new THREE.CylinderGeometry(rTop, rBottom, h, sides, hSeg),
    cone: (r, h, sides = 8) => new THREE.ConeGeometry(r, h, sides),
    sphere: (r, w = 8, h = 6) => new THREE.SphereGeometry(r, w, h),
    torus: (r, tube, radial = 6, tubular = 12, arcDeg = 360) => new THREE.TorusGeometry(r, tube, radial, tubular, arcDeg * D2R),
    // profile: [[radius, y], ...] bottom to top, spun around +Y
    lathe: (profile, sides = 8) => new THREE.LatheGeometry(profile.map(([r, y]) => new THREE.Vector2(r, y)), sides),
    // outline: [[x, y], ...] in the XY plane, extruded `depth` along +Z
    extrude: (outline, depth, bevel = 0) => new THREE.ExtrudeGeometry(new THREE.Shape(outline.map(([x, y]) => new THREE.Vector2(x, y))), { depth, bevelEnabled: bevel > 0, bevelSize: bevel, bevelThickness: bevel, bevelSegments: 1 }),
    wedge: (w, h, d) => { // ramp: full height at +Z, zero height at -Z
      const g = new THREE.ExtrudeGeometry(new THREE.Shape([new THREE.Vector2(-d / 2, 0), new THREE.Vector2(d / 2, 0), new THREE.Vector2(-d / 2, h)]), { depth: w, bevelEnabled: false });
      return g.rotateY(Math.PI / 2).translate(-w / 2, -h / 2, 0);
    },

    node: nodeOf,
    material, texture, png,

    /** Empty pivot node. Children and animation rotate around its origin. */
    group: (nm, o = {}) => newNode(nm, o),

    /** Empty attachment point. Found in three.js with getObjectByName(name); extras land in userData. */
    socket: (nm, o = {}) => newNode(nm, { ...o, extras: { socket: true, ...(o.extras || {}) } }),

    /**
     * Mesh part. The node origin is the pivot: place it with `at` (parent-local) or `world`, then `anchor` says which
     * side of the shape touches that pivot (e.g. a leg hanging from the hip: anchor 'top').
     * opts: parent, at | world, rot [deg], scale, anchor, offset, geoRot [deg, rotates the shape not the node],
     *       color '#hex' | material, map (texture), roughness, metalness, opacity, unlit, doubleSided, extras
     */
    part(nm, geo, o = {}) {
      if (!geo?.isBufferGeometry) fail(`${nm}: second argument must be a shape (m.box(...), m.cyl(...), ...)`);
      const n = newNode(nm, o);
      return n.setMesh(doc.createMesh(nm).addPrimitive(primitive(placeGeometry(geo, o), matFor(o))));
    },

    /**
     * Bar from world point a to world point b (rails, struts, braces, axles). Node origin at a, so it pivots there.
     * opts: size (square side, default 0.04) or [w, d], round: true for a cylinder, sides, parent, color/material...
     */
    beam(nm, a, b, o = {}) {
      const A = new THREE.Vector3(...vec3(a, `${nm} a`)), B = new THREE.Vector3(...vec3(b, `${nm} b`)), dir = B.clone().sub(A), len = dir.length();
      if (len < 1e-6) fail(`beam ${nm}: a and b are the same point`);
      const [w, d] = Array.isArray(o.size) ? o.size : [o.size ?? 0.04, o.size ?? 0.04];
      const geo = o.round ? new THREE.CylinderGeometry(w / 2, w / 2, len, o.sides ?? 8) : new THREE.BoxGeometry(w, len, d);
      const n = api.part(nm, geo, { ...o, world: a, anchor: 'bottom', rot: undefined, at: undefined });
      const qWorld = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
      const parentQ = new THREE.Quaternion(); worldMatrix(n.getParentNode()).decompose(new THREE.Vector3(), parentQ, new THREE.Vector3());
      n.setRotation(parentQ.invert().multiply(qWorld).toArray());
      return n;
    },

    /** Bone (joint) node. Same placement options as group(). */
    bone(nm, o = {}) { const n = newNode(nm, o); bones.add(nm); return n; },

    /**
     * One continuous skinned mesh bent by bones. `pieces` are [{ geo, world: [x,y,z], anchor, geoRot }] in the bind
     * (rest) pose, in WORLD space. Give shapes height segments where they should bend.
     * opts: bones: [names] (first = skeleton root), weights: 'smooth' | 'rigid' | (worldPos [x,y,z]) => { boneName: w },
     *       blend: meters of falloff for 'smooth' (default 0.15), color | material | map
     * The mesh node goes at the scene root with no transform, as glTF requires.
     */
    skinned(nm, pieces, o = {}) {
      if (!NAME.test(nm) || nodes.has(nm)) fail(`skinned name "${nm}" invalid or duplicate`);
      const bnames = o.bones || fail(`${nm}: opts.bones is required`);
      const joints = bnames.map(b => (bones.has(b) ? nodes.get(b) : fail(`${nm}: "${b}" is not a bone (make it with m.bone)`)));
      const geos = pieces.map((p, i) => placeGeometry(p.geo, p).translate(...vec3(p.world ?? [0, 0, 0], `${nm} piece ${i}.world`)));
      const toFlat = g => (flat && g.index ? g.toNonIndexed() : g);
      const geo = mergeGeometries(geos.map(toFlat).map(g => { const c = g.clone(); for (const k of Object.keys(c.attributes)) if (!['position', 'normal', 'uv'].includes(k)) c.deleteAttribute(k); return c; }));
      if (!geo) fail(`${nm}: pieces could not be merged (mixed attributes?)`);
      const heads = joints.map(j => new THREE.Vector3().setFromMatrixPosition(worldMatrix(j)));
      // each bone is a segment from its head to the mean of its bone children's heads (leaf: extend 40% of parent link)
      const tails = joints.map((j, i) => {
        const kids = j.listChildren().filter(c => joints.includes(c));
        if (kids.length) return kids.reduce((s, c) => s.add(heads[joints.indexOf(c)]), new THREE.Vector3()).divideScalar(kids.length);
        const par = joints.find(p => p.listChildren().includes(j));
        const dir = par ? heads[i].clone().sub(heads[joints.indexOf(par)]).multiplyScalar(0.4) : new THREE.Vector3(0, 0.1, 0);
        return heads[i].clone().add(dir);
      });
      const segDist = (p, i) => new THREE.Line3(heads[i], tails[i]).closestPointToPoint(p, true, new THREE.Vector3()).distanceTo(p);
      const blend = o.blend ?? 0.15, mode = o.weights ?? 'smooth';
      const skinData = pos => {
        const J = new (joints.length > 255 ? Uint16Array : Uint8Array)(pos.count * 4), W = new Float32Array(pos.count * 4), p = new THREE.Vector3();
        for (let v = 0; v < pos.count; v++) {
          p.fromBufferAttribute(pos, v);
          let ws;
          if (typeof mode === 'function') ws = Object.entries(mode(p.toArray())).map(([b, w]) => [bnames.indexOf(b), w]);
          else {
            const d = joints.map((_, i) => [i, segDist(p, i)]).sort((a, b) => a[1] - b[1]);
            ws = mode === 'rigid' ? [[d[0][0], 1]] : d.slice(0, 4).map(([i, di]) => [i, Math.max(0, 1 - (di - d[0][1]) / blend)]);
          }
          ws = ws.filter(([i, w]) => i >= 0 && w > 1e-4).sort((a, b) => b[1] - a[1]).slice(0, 4);
          const sum = ws.reduce((s, [, w]) => s + w, 0);
          if (!(sum > 0)) fail(`${nm}: vertex ${v} at ${p.toArray().map(x => x.toFixed(2))} got no weight`);
          ws.forEach(([i, w], k) => { J[v * 4 + k] = i; W[v * 4 + k] = w / sum; }); // unused slots stay joint 0 / weight 0
        }
        return { joints: J, weights: W };
      };
      const ibm = new Float32Array(joints.length * 16);
      joints.forEach((j, i) => worldMatrix(j).invert().toArray(ibm, i * 16));
      const skin = doc.createSkin(`${nm}_skin`).setSkeleton(joints[0]).setInverseBindMatrices(acc('MAT4', ibm));
      joints.forEach(j => skin.addJoint(j));
      const n = doc.createNode(nm).setMesh(doc.createMesh(nm).addPrimitive(primitive(geo, matFor(o), skinData))).setSkin(skin);
      scene.addChild(n);
      nodes.set(nm, n);
      return n;
    },

    /**
     * Looping sine keys for clip(): amp [x,y,z] (deg for rot, meters for pos), phase 0..1 of a cycle, cycles = whole
     * waves per clip (2 = body bob twice per stride), abs = |sin| (a dip on every half-stride). Down a chain from
     * head to tail, phase -i*k makes the wave travel head -> tail.
     */
    wave: (amp, { phase = 0, keys, cycles = 1, abs = false, offset = [0, 0, 0] } = {}) => ({ wave: { amp: vec3(amp, 'wave amp'), phase, keys: keys ?? 8 * cycles, cycles, abs, offset } }),

    /**
     * Animation clip. tracks: { nodeName: { rot, pos, scale, interp } } where each channel is
     * [[time, [x, y, z]], ...] or m.wave(...). Values are OFFSETS from the node's rest pose:
     * rot = extra degrees (XYZ euler, in the node's own frame), pos = meters added, scale = multiplier.
     * opts: duration (s), loop (true => first and last key must match; the kit checks).
     */
    clip(nm, { duration, loop = false } = {}, tracks) {
      if (!NAME.test(nm)) fail(`clip name "${nm}" must match ${NAME}`);
      if (!(duration > 0)) fail(`clip ${nm}: duration (seconds) is required`);
      const anim = doc.createAnimation(nm).setExtras({ loop });
      for (const [target, chans] of Object.entries(tracks)) {
        const node = nodeOf(target);
        for (const [path, keysIn] of Object.entries(chans)) {
          if (path === 'interp') continue;
          if (!['rot', 'pos', 'scale'].includes(path)) fail(`clip ${nm} ${target}: channel "${path}" must be rot|pos|scale`);
          let keys = keysIn;
          if (keys?.wave) {
            const { amp, phase, keys: k, offset, cycles, abs } = keys.wave;
            if (!Number.isInteger(cycles) || cycles < 1) fail(`clip ${nm} ${target}: wave cycles must be a whole number so the loop closes`);
            keys = Array.from({ length: k + 1 }, (_, i) => {
              const raw = Math.sin(2 * Math.PI * (cycles * i / k + phase)), s = abs ? Math.abs(raw) : raw;
              return [duration * i / k, amp.map((a, j) => offset[j] + a * s)];
            });
          }
          if (!Array.isArray(keys) || keys.length < 2) fail(`clip ${nm} ${target}.${path}: need at least 2 keys [[t, [x,y,z]], ...]`);
          keys.forEach(([t, v], i) => { vec3(v, `clip ${nm} ${target}.${path}[${i}]`); if (!(t >= 0 && t <= duration + 1e-6)) fail(`clip ${nm} ${target}.${path}: key time ${t} outside 0..${duration}`); if (i && !(t > keys[i - 1][0])) fail(`clip ${nm} ${target}.${path}: key times must increase`); });
          if (loop) {
            const a = keys[0][1], b = keys[keys.length - 1][1];
            if (keys[0][0] !== 0 || Math.abs(keys[keys.length - 1][0] - duration) > 1e-6) fail(`clip ${nm} ${target}.${path}: a loop clip needs keys at t=0 and t=${duration}`);
            const same = path === 'rot' ? Math.abs(eulerQuat(a).dot(eulerQuat(b))) > 1 - 1e-9 : a.every((x, i) => Math.abs(x - b[i]) <= 1e-6); // 0 and 360 deg are the same pose
            if (!same) fail(`clip ${nm} ${target}.${path}: loop clip but first key ${JSON.stringify(a)} != last ${JSON.stringify(b)}`);
          }
          if (path === 'rot') { // split big turns: slerp takes the short way, so a 360 between two keys does nothing
            const out = [keys[0]];
            for (let i = 1; i < keys.length; i++) {
              const [t0, v0] = keys[i - 1], [t1, v1] = keys[i];
              const steps = Math.max(1, Math.ceil(Math.max(...v0.map((x, j) => Math.abs(v1[j] - x))) / 90)); // >=1 keeps held poses
              for (let s = 1; s <= steps; s++) out.push([t0 + (t1 - t0) * s / steps, v0.map((x, j) => x + (v1[j] - x) * s / steps)]);
            }
            keys = out;
          }
          const times = new Float32Array(keys.map(k => k[0]));
          let values;
          if (path === 'rot') {
            const rest = new THREE.Quaternion(...node.getRotation());
            const qs = keys.map(([, v]) => rest.clone().multiply(eulerQuat(v)));
            for (let i = 1; i < qs.length; i++) if (qs[i].dot(qs[i - 1]) < 0) qs[i].set(-qs[i].x, -qs[i].y, -qs[i].z, -qs[i].w);
            values = new Float32Array(qs.flatMap(q => q.toArray()));
          } else if (path === 'pos') {
            const r = node.getTranslation(); values = new Float32Array(keys.flatMap(([, v]) => v.map((x, j) => r[j] + x)));
          } else {
            const r = node.getScale(); values = new Float32Array(keys.flatMap(([, v]) => v.map((x, j) => r[j] * x)));
          }
          const sampler = doc.createAnimationSampler().setInput(acc('SCALAR', times))
            .setOutput(acc(path === 'rot' ? 'VEC4' : 'VEC3', values)).setInterpolation(chans.interp || 'LINEAR');
          anim.addSampler(sampler).addChannel(doc.createAnimationChannel().setTargetNode(node)
            .setTargetPath({ rot: 'rotation', pos: 'translation', scale: 'scale' }[path]).setSampler(sampler));
        }
      }
      return anim;
    },

    /** World position [x,y,z] of a node's origin in the rest pose. */
    worldOf: ref => new THREE.Vector3().setFromMatrixPosition(worldMatrix(nodeOf(ref))).toArray().map(v => +v.toFixed(4)),

    /** Clean up and write the GLB. prune keeps empty leaves so sockets survive. */
    async write(path) {
      if (!/\.glb$/.test(path)) fail(`write path must end in .glb: ${path}`);
      await doc.transform(dedup(), prune({ keepLeaves: true, keepAttributes: true }));
      await io.write(path, doc);
      let tris = 0;
      for (const n of doc.getRoot().listNodes()) for (const p of n.getMesh()?.listPrimitives() ?? []) tris += (p.getIndices()?.getCount() ?? p.getAttribute('POSITION').getCount()) / 3;
      console.log(`wrote ${path}: ${doc.getRoot().listNodes().length} nodes, ${doc.getRoot().listMeshes().length} meshes, ${tris} tris, ${doc.getRoot().listMaterials().length} materials, clips [${doc.getRoot().listAnimations().map(a => a.getName()).join(', ')}], ${fs.statSync(path).size} bytes`);
      return path;
    },
  };
  return api;
}
