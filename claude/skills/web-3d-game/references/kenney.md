# Kenney 3D assets reference (checked 2026-10)

## License and downloads

- **CC0 public domain.** You can use the assets in personal, educational, and commercial work. Attribution is optional; credit "Kenney" or "www.kenney.nl" if you like, but don't use Kenney's logo. Policy: https://kenney.nl/support
- Each pack has a page at `https://kenney.nl/assets/<slug>` with a single zip.
- **The zip URL is not stable.** It contains a hash and a timestamp, e.g. `https://kenney.nl/media/pages/assets/platformer-kit/<hash>-<ts>/kenney_platformer-kit.zip`. To script a download, fetch the page with curl and extract `media/pages/assets/[^"]*\.zip`.
- All 3D packs: https://kenney.nl/assets/category:3D
- The paid All-in-1 bundle is at https://kenney.itch.io/kenney-game-assets.
- Tools:
  - Asset Forge, a block-based model builder that exports glTF: https://kenney.nl/tools/asset-forge
  - Kenney Shape: https://kenney.nl/tools/kenney-shape
- **Official starter kits are Godot only** (github.com/KenneyNL Starter-Kit-*). There are no official three.js samples.

## Useful packs (`https://kenney.nl/assets/<slug>`)

| Need | Slugs |
|---|---|
| Platformer levels and characters | `platformer-kit` |
| Cities and roads | `city-kit-roads`, `city-kit-commercial`, `city-kit-suburban`, `city-kit-industrial` |
| Vehicles and tracks | `car-kit` (wheels are separate nodes), `racing-kit`, `toy-car-kit` |
| Outdoor scenery | `nature-kit`, `survival-kit`, `hexagon-kit` |
| Dungeons and castles | `mini-dungeon`, `modular-dungeon-kit`, `castle-kit` |
| Space | `space-kit`, `modular-space-kit`, `space-station-kit` |
| Other themes | `tower-defense-kit`, `pirate-kit`, `furniture-kit` |
| Characters (animated) | `mini-characters`, `blocky-characters`, `animated-characters-retro` (FBX only), `animated-characters-survivors` |
| Greybox / prototyping | `prototype-kit` (models), `prototype-textures` (grid PNGs only) |

## File layout

- **Newer packs** (Platformer, Car, City Roads, Castle, Mini Dungeon, Tower Defense, Pirate, Prototype Kit, Mini/Blocky Characters):
  - Contain `Models/GLB format/*.glb` plus `Models/GLB format/Textures/colormap.png`.
  - **The GLB references the texture externally** via `uri: "Textures/colormap.png"`, so it is not embedded.
  - The colormap is a 512² palette atlas. Alternate palettes are in `Models/Textures/variation-*.png`.
  - Blocky Characters is the exception: each GLB uses its own `Textures/texture-<x>.png`.
- **Older packs** (Nature, Space, Racing, Furniture):
  - The `Models/GLTF format/` folder actually holds `.glb` files.
  - They have no textures, only flat `baseColorFactor` materials.
  - **Nature and Space set `metallicFactor: 1`**, so they render black without an environment map.

## Scale, pivots, animation

- **1 tile = 1 unit**, and glTF is Y-up. Floor, road, and wall tiles span ±0.5 in X and Z.
- Platformer `block-grass` is about 1.08 wide because of an overhang lip, and its large blocks are 2×2.
- **Pivot:** newer packs use bottom-centre (y=0 at the base). **Racing and Furniture use a corner pivot**, e.g. `roadStraight` spans x 0..1, z −1..0, so they need offsets to snap to a grid.
- Platformer characters (`character-oobi`, etc.) are about 0.9 units tall.
- **Skinned clips** in Platformer and Mini Characters, all lowercase:
  - Movement: `idle`, `walk`, `sprint`, `jump`, `fall`, `crouch`, `sit`, `drive`, `die`
  - Actions: `pick-up`, `emote-yes`, `emote-no`, `interact-*`
  - Combat: `attack-melee-*`, `attack-kick-*`, `holding-*`
- Blocky Characters uses node-hierarchy animation with no skin. It has the same clip set except `jump`, `fall`, and `crouch`.
- Prototype Kit animals have `walk`, `run`, `down`, and `up`.

## three.js gotchas

- **Grey or white models with "Couldn't load texture":** the `Textures/` folder wasn't served next to the GLB, or a bundler hashed the GLB URL (`?url` import). Serve from `public/` with the folder layout intact, or call `loader.setResourcePath()`.
- **File name collisions:** every pack ships a different `colormap.png`. Keep one directory per pack.
- **Black or dark models (older packs):** traverse the meshes and set `material.metalness = 0`, or set `scene.environment` from `PMREMGenerator` + `RoomEnvironment`.
- **Palette bleeding at a distance:** set `texture.minFilter = texture.magFilter = THREE.NearestFilter`.
- **The flat-shaded look is intentional.** Don't recompute or merge normals.
- **Colliders:** size them from the tile grid, not the raw `Box3`, because of lips and corner pivots.
- **Reuse loaded models:** load each GLB once. Clone plain props with `.clone()` and characters with `SkeletonUtils.clone()`.
