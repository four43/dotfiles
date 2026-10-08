# Visual feedback loop for LLM-authored GLB models (headless render + VLM self-critique)

Scope: how Claude Code (reads PNGs from disk, drives Playwright) can "see" GLB models and animations it writes, on this Arch Linux box (Node 26, three 0.186, Playwright, Python 3, no Blender). Research done 2026-10-07. Includes one local experiment, marked **[local experiment]**. Its scripts are in the session scratchpad (`/tmp/claude-1000/.../scratchpad/vr/shot.mjs` + `page.html`). The scratchpad is temporary, so the essential code is described inline below.

## Headless rendering options on Linux without a dedicated GPU

### Takeaway
three.js in Playwright's bundled `chromium-headless-shell` works with no flags. It renders WebGL through SwiftShader (on Vulkan, via ANGLE) and produced a 6-view contact-sheet PNG in about 0.3 s end to end on this machine. This is the best default because it uses the game's own three 0.186 GLTFLoader and materials. Blender, pyrender/OSMesa and headless-gl are worse fits. Blender is not installed and its materials don't match three.js. headless-gl only supports WebGL1, which three.js dropped in r163.

### Cited Findings
- **[local experiment]** Playwright 1.64 + `chromium_headless_shell-1243`, rendering `assets/models/tractor.glb` into a 1152x768 6-view sheet. The time covers browser launch + load + render + PNG write.
  - No flags: renderer `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)`, **291 ms**.
  - `--use-angle=swiftshader --enable-unsafe-swiftshader`: same renderer, 364 ms.
  - `--use-angle=gl`: picked up the host NVIDIA RTX 5070 Ti through OpenGL ES 3.2, 597 ms. It was slower because of GPU init cost for a tiny scene.
  - System `/usr/bin/chromium`: 563 / 807 / 1107 ms for the same three configurations.
  - Barn in normals and clay modes: about 310 ms each.
  - Note: this machine *does* have a GPU. SwiftShader is still the deterministic, portable default (for example in CI). Use `WEBGL_debug_renderer_info` → `UNMASKED_RENDERER_WEBGL` to log which backend actually rendered.
- Playwright's Chromium uses `--enable-unsafe-swiftshader` for CPU WebGL via SwiftShader, which keeps WebGL working without GPU drivers. `--disable-gpu`, the most commonly copied headless flag, "silently forces SwiftShader on again" — [microlink: WebGL without a GPU](https://microlink.io/blog/webgl-without-a-gpu)
- microlink measured SwiftShader at about 24 s per heavy 3D page versus about 6 s with `--use-angle=gl` on Mesa llvmpipe (4x faster in isolation, about 2x under production load). This needs Xvfb plus `LIBGL_ALWAYS_SOFTWARE=1`. Without an X display, "WebGL silently degrades to a flat 2D fallback" that looks successful. `--in-process-gpu` also breaks the ANGLE GL surface — [microlink](https://microlink.io/blog/webgl-without-a-gpu)
- Another recipe: run headed Chromium under xvfb, or use `--use-cmd-decoder=passthrough` to get the GPU in headless mode — [three.js forum: running three.js on headless chromium using GPU](https://discourse.threejs.org/t/running-threejs-on-headless-chromium-using-gpu/18080); [createit: testing WebGL with Playwright](https://www.createit.com/?p=3319)
- three.js deprecated WebGL1 in r153 and removed it in r163. Because headless-gl doesn't support WebGL2, it "can no longer be used" with three r163+ except by mocking WebGL2 methods, which gives no real pixels — [three.js forum: headless-gl and WebGL 2](https://discourse.threejs.org/t/suggestions-for-unit-testing-with-headless-gl-and-webgl-2/66891); [three.js Migration Guide](https://github.com/mrdoob/three.js/wiki/Migration-Guide)
- `@shopify/screenshot-glb` is a CLI that drives Puppeteer with headless Chrome and `<model-viewer>`. Flags: `-i/-o`, `-w/-h`, `-c` background colour, `-t` timeout, `-m` URL-encoded model-viewer attributes (camera-orbit and similar), `-@` model-viewer version, `--enable_gpu`. It produces one view per call — [GitHub Shopify/screenshot-glb](https://github.com/Shopify/screenshot-glb)
- LL3M renders its critique images with Blender EEVEE, chosen "to reduce the mesh generation time" — [LL3M arXiv 2508.08228](https://arxiv.org/html/2508.08228v1)

### Inferences
- **Recommended default:** a single `node tools/look.mjs <model.glb> [--mode lit|clay|normals|wire|uv|bones] [--anim walk --frames 8] -o out.png` CLI.
  - It starts a tiny `http.server` that serves `node_modules/three` and the GLB (ES modules don't load from `file://`), then launches headless-shell Chromium.
  - The page builds `THREE.WebGLRenderer({preserveDrawingBuffer:true})` and renders all views into one canvas using `setViewport`/`setScissor`. It composites labels onto a 2D canvas and sets `window.__done = canvas.toDataURL()`.
  - Node waits with `page.waitForFunction(() => window.__done)` and writes the PNG.
  - This is the exact pattern tested; it is well under 1 s per sheet.
  - The repo's existing `tools/models.html` (OrbitControls viewer) is the interactive companion. It can be extended with a `?shot=1` mode instead of duplicating it.
- `preserveDrawingBuffer:true`, or reading the canvas in the same task as `render()`, is needed for `toDataURL`. Playwright's `page.screenshot()` of the canvas also works, but text labels drawn in DOM need layout. Compositing onto a 2D canvas keeps it self-contained.
- Reuse one browser across many renders (batch mode). At about 0.3 s with launch included, per-model launches are fine, but filmstrips of N frames should render in one page.
- `<model-viewer>`/screenshot-glb is fine for pretty thumbnails, but it can't add helpers (grid, skeleton, normals). A custom three page is strictly more useful for critique.
- Blender CLI (`blender -b --python render.py`, Workbench engine for clay/matcap) would add a second, independent glTF importer. That is useful for catching "works in three but not elsewhere" export bugs, but it is not needed for the main loop.
- pyrender/trimesh with OSMesa/EGL is fast for silhouettes and depth but doesn't match three.js PBR/skinning. It is also not installed (`import trimesh` failed).

### Gaps
- I didn't benchmark Blender, pyrender or model-viewer locally because they aren't installed. Speeds for them are not measured.
- The guidance that WebGL in new `--headless` Chrome without a display "silently degrades" comes from microlink's llvmpipe/`--use-angle=gl` setup. The default SwiftShader-on-Vulkan path rendered correctly here without Xvfb.

## Render layout that gives a VLM the most signal; image size vs token cost

### Takeaway
Send one labeled contact sheet per question, roughly 1100-1600 px on the long edge. Use 4-6 views: orthographic front/side/top/back plus a 3/4 perspective. Include a ground grid in metres, a 1 m reference cube, an axes gizmo, a bbox readout in text, and generous spacing between elements. Add a separate normals (or clay) sheet for geometry. Research supports multi-view plus normal maps (GPTEval3D) and large separation between shapes (BlindTest). Anthropic's sizing rules make about 1.2-1.6 MP the sweet spot.

### Cited Findings
- **Claude image sizing (current docs):**
  - Cost is `ceil(w/28) × ceil(h/28)` visual tokens.
  - Claude 4.7 and later models are "high-resolution": max long edge 2576 px and 4784 visual tokens. Other models: 1568 px / 1568 tokens. Larger images are downscaled.
  - Examples: 1000x1000 = 1296 tokens; 1092x1092 = 1521; 1920x1080 = 2691 tokens on the high-res tier.
  - Max 8000x8000 px. If a request has more than 20 images, a stricter limit applies (keep each side ≤ 2000 px).
  - Images under 200 px and rotated images raise hallucination risk.
  - Counting is "approximate", and coordinate/localization outputs are "approximate".
  - Text in images must be legible and survive resizing.
  - Images work best before the text that asks about them.
  - When sending several images, label each ("Image 1:").
  - Source: [Anthropic Vision docs](https://platform.claude.com/docs/en/build-with-claude/vision)
- GPTEval3D (CVPR 2024):
  - Feeds GPT-4V one large image with renders from 4 or 9 viewpoints, plus world-space surface-normal renders "arranged in the same layout as the RGB render".
  - Normals "provide geometric information about the surface and allow reasoning for correspondence between views".
  - One view was best for fine texture-geometry detail; 4-9 views were better for global text-asset alignment.
  - Adding watermark labels "slightly improves the alignment" by reducing position ambiguity.
  - Source: [GPTEval3D arXiv 2401.04092](https://arxiv.org/html/2401.04092v2)
- LL3M renders m=5 views with "adaptive camera distance based on the object's bounding box" for its critic and verifier agents — [LL3M](https://arxiv.org/html/2508.08228v1)
- CADCodeVerify renders 4 views at 0/90/180/270° for its verification questions — [CADCodeVerify arXiv 2410.05340](https://arxiv.org/html/2410.05340v2)
- BlindTest ("VLMs are blind"): VLMs fail simple geometry (overlaps, intersections, counting) "when geometric primitives overlap or are close together". They reach "near-100% accuracy when much more space is added to separate shapes". Average accuracy was 58%, with Sonnet-3.5 best at 77.8% — [arXiv 2407.06581](https://arxiv.org/html/2407.06581v4)
- **[local experiment]** The first contact sheet (6 tiles at 384 px, 1152x768 ≈ 1148 tokens) was clearly readable: labels legible, tractor parts recognizable in all views. Problems it exposed:
  1. With a fixed ortho extent that included the reference cube, the subject filled only about 25% of each tile. Frame each view tightly on the model's bbox instead.
  2. The 1 m cube overlapped the tractor in side views. Place it diagonally off the bbox corner (+X and −Z) so it never occludes.
  3. A fixed 10 m grid was smaller than the 22 m barn. Size the grid to the bbox.
  - In normals mode with `side: FrontSide` on a magenta background, see-through areas showed up immediately as magenta inside the barn silhouette. These are back-faced or missing faces (or intentional openings, which must be stated in the spec).

### Inferences
- **Proposed sheet "A: geometry" (2x3, about 1200x800):** FRONT/RIGHT/TOP/BACK/LEFT orthographic plus a 3/4 perspective.
  - Ortho views let the model check proportions against the grid. Perspective gives a gestalt check.
  - Label each tile with view name and axis direction (for example "FRONT (+Z, model faces camera)").
  - Footer text: bbox dimensions in metres, triangle count, mesh/material counts, clip names. Numbers in text are more reliable than visual estimates, per Claude's counting/spatial limits.
- **Sheet "B: diagnostics" (same layout, separate image):**
  - MeshNormalMaterial with `FrontSide` on a loud background (magenta). Flipped or missing faces show as background holes. A second variant could colour back faces red (`side: BackSide` red pass under a front pass).
  - Wireframe overlay (`wireframe` on a cloned mesh, or `EdgesGeometry` lines) for topology density.
  - UV checker texture when textures are used.
  - `SkeletonHelper` plus `AxesHelper` on each empty/bone, and on named attachment nodes (for example hitch points, hat sockets), with CSS2D or canvas name labels. Place labels sparsely, because overlapping text and lines are exactly the BlindTest failure case.
- Clay (uniform grey Standard material) separates shape problems from colour problems. Ask shape questions on clay, and palette questions on lit.
- Keep any single tile at least 256 px (Claude degrades below about 200 px). Prefer 6 tiles at 384-512 px over 12 tiles at 256 px. For fine details, render a separate zoomed single view (GPTEval3D: single views are better for detail).
- Keep 2-3 images per critique turn. Every image remains in context and costs tokens on each later turn, so a 1200x800 sheet costs about 1,230 tokens each time it's re-sent.

### Gaps
- I found no study isolating orthographic vs perspective, ground grid, or scale-cube effects on VLM accuracy. Those recommendations are inferred from BlindTest (spacing), GPTEval3D (labels, normals) and Claude's documented limits.
- I found no direct evidence on whether wireframe overlays help or hurt VLM judgment. They likely add clutter, so they belong on a separate sheet.

## Animations: filmstrips, onion skinning, detecting popping, foot sliding, joint collapse

### Takeaway
VLMs can't watch video through this channel (GIFs are reduced to their first frame), so animations must become still sheets. Render a filmstrip grid of N evenly sampled times per clip from 1-2 fixed side/front ortho cameras, with a ground grid and the time in each label. Pair it with numeric checks computed in JS for things a VLM is poor at: foot sliding, popping, loop seams, and bbox/volume collapse.

### Cited Findings
- Claude accepts JPEG/PNG/GIF/WebP, but "Animations are unsupported, and only the first frame is used" — [Anthropic Vision docs](https://platform.claude.com/docs/en/build-with-claude/vision)
- OpenAI's "develop-web-game" agent skill uses a deterministic time-step hook, `window.advanceTime(ms)`, so a Playwright script can step frames deterministically and capture screenshots each iteration ("implement → act → pause → observe → adjust") — [develop-web-game skill (tessl registry)](https://tessl.io/registry/skills/github/openai/skills/develop-web-game/review)
- VLMs degrade sharply when integrating information across views, and they produce view-invariant answers even when wrong (ReMindView-Bench, ViewDiag). Counting and relative direction/distance are the weakest areas (ReVSI) — [MultiView/ReMindView summary arXiv 2512.02340](https://arxiv.org/abs/2512.02340v1); [ReVSI arXiv 2604.24300](https://arxiv.org/pdf/2604.24300); [MultiView-Bench arXiv 2607.08970](https://arxiv.org/pdf/2607.08970)

### Inferences
- **Filmstrip design:**
  - For each clip, choose N = 8 (loops) or 12 (one-shots) times `t_i = i·duration/N`. Set `mixer.setTime(t_i)` (the prototype page has a `?t=` hook for this, but animated renders were not exercised in the experiment) and render a side ortho view.
  - Use a 4x2 or 4x3 grid. Draw a fixed vertical reference line at the root's start x, and keep the grid in every tile so motion against the ground is visible.
  - Optionally add a second row from the front view.
  - Label each frame with `t=0.25s (2/8)`.
  - Add a final tile that repeats t=0 next to t=duration−ε to show the loop seam.
- **Onion skin:** render 3-5 sampled poses into one tile with decreasing opacity (clone the scene per pose or accumulate with `autoClear=false`). It is good for arcs and smoothness, but overlapping silhouettes are BlindTest's weak spot, so use it only as a supplement to the filmstrip.
- **Numeric checks (more reliable than vision):** compute these in the same page and print them as text/JSON next to the PNG.
  - **Foot sliding:** world position of named foot bones while their y is below a contact threshold; report horizontal drift per contact phase (in-place clips should be ~0).
  - **Popping:** per-bone max angular velocity between consecutive samples at 60 Hz; flag spikes over a threshold.
  - **Loop seam:** pose distance between t=0 and t=duration.
  - **Joint collapse / candy-wrapper:** per-frame skinned-mesh bbox volume relative to bind pose, computed from skinned vertex positions (e.g. `SkinnedMesh.applyBoneTransform` per vertex; verify API in three 0.186). Large drops flag collapse.
  - **Ground penetration:** min y of skinned vertices below 0.
- The VLM should judge readability, character and pose intent ("does the walk read as a walk? are legs alternating?"). Numbers should gate the mechanical errors.

### Gaps
- I found no published evaluation of VLMs judging animation filmstrips specifically (accuracy on detecting foot sliding or popping from stills). The numeric-check recommendation is engineering judgment, not sourced.

## Research evidence on VLM render-critique loops: what works, blind spots, critique prompt structure

### Takeaway
Render-critique loops help, but modestly. The gains are largest for weaker generators and when the critique is a **spec-derived checklist of binary questions** answered against multiple labeled views. Free-form "does this look right?" works poorly. VLM verifiers are imperfect (about 65-82% accurate) and miss spatial errors, so false "looks good" verdicts are the main risk. Use the VLM for semantic/proportion checks and deterministic code for geometry, counts and positions.

### Cited Findings
- **CADCodeVerify (ICLR 2025):**
  - The VLM generates 2-5 binary Yes/No verification questions from the text spec, answers them using the 4 rendered views, and turns "No" answers into actionable feedback. If all answers are "Yes", it stops.
  - Compared with 3D-Premise (show image + description, ask for a fix), it gave 7.30% lower point-cloud distance and 5.5% higher compile rate with GPT-4. 3D-Premise "struggles to provide effective feedback for 'Hard' data" and degraded on it.
  - Question-answer accuracy was only 64.6-68.2%.
  - A geometric-solver baseline with ground truth was the upper bound, and human-in-the-loop was still marginally better.
  - Source: [arXiv 2410.05340](https://arxiv.org/html/2410.05340v2)
- **LL3M (2025):**
  - Uses separate critic and verification agents. The critic sends 5 renders plus a fixed prompt to Gemini 2.0 Flash to "check if the renders match the task" and list issues with fixes. The verifier re-renders and compares new renders, previous renders and the critique list to confirm each fix landed.
  - Limitation: "VLMs may still struggle to accurately identify spatial artifacts". Spatial-positioning tasks "require several user follow-up prompts to correct visual errors that the VLM missed".
  - No ablation isolates the critic.
  - Source: [arXiv 2508.08228](https://arxiv.org/html/2508.08228v1)
- **SceneCraft (ICML 2024):** first writes a scene graph of spatial relations, then turns it into numerical layout constraints in Blender Python, then uses GPT-V on renders to iteratively refine. A library-learning step keeps reusable functions — [PMLR](https://proceedings.mlr.press/v235/hu24g.html); [arXiv 2403.01248](https://arxiv.org/html/2403.01248v1)
- **BlenderAlchemy (ECCV 2024):** a VLM edit generator plus a VLM state evaluator search over Blender program edits. It uses text-to-image "visual imagination" to turn text intent into concrete reference images that the evaluator compares against — [arXiv 2404.17672](https://arxiv.org/html/2404.17672v1)
- **Imperfect visual verification, TikZ (Reux et al., 2026):**
  - Visual verifiers reached F1 up to 0.815.
  - Weaker models gained 11-20 perfect customizations from iterative feedback; a strong model (Gemini-3) gained +5, mainly from "accurate verification that prevents premature acceptance".
  - Feedback works "only when it precisely identifies image issues, provides actionable guidance, addresses all relevant problems, and remains grounded in the original instruction".
  - Source: [arXiv 2606.15693](https://arxiv.org/abs/2606.15693)
- **GPTEval3D:** pairwise comparison of two assets (Elo) aligns well with human preference. Known GPT-4V misses: quantity mismatches ("fails to detect the mismatch in the number of balloons"), sensitivity to low-level noise that hides the bigger issue, and position bias — [arXiv 2401.04092](https://arxiv.org/html/2401.04092v2)
- **BlindTest:** VLMs fail at overlap, intersection and counting when elements are close together; spacing fixes this — [arXiv 2407.06581](https://arxiv.org/html/2407.06581v4)
- **Render-loop SVG work (2026):** Render-in-the-Loop, IntroSVG (draft → self-critique rendered PNG → revise) and RefineSVG/RLRF all close the render loop for vector/code graphics. Render-in-the-Loop claims the approach generalizes to HTML/CSS, TikZ, 3D rendering programs and CAD — [Render-in-the-Loop arXiv 2604.20730](https://arxiv.org/pdf/2604.20730); [RLRF arXiv 2505.20793](https://arxiv.org/html/2505.20793v2); [RefineSVG arXiv 2607.27699](https://arxiv.org/pdf/2607.27699)
- **Multi-view integration is a documented weakness:** 15 VLMs showed "consistent failures in cross-view alignment and perspective-taking" — [arXiv 2512.02340](https://arxiv.org/abs/2512.02340v1)

### Inferences
- **Critique prompt template** (put the images first, then this text):
  1. Restate the spec as numbered binary checks, written before looking. Examples: "1. Model faces +Z (front view shows the grille/face). 2. Height ≈ 1.6 m (compare to 1 m cube). 3. Four wheels, rear wheels larger. 4. No magenta holes in normals sheet except listed openings. 5. Feet touch grid line at y=0."
  2. For each check, answer Yes / No / Unclear, citing which tile it's based on.
  3. List other defects, ranked by severity.
  4. For each "No", propose a concrete code-level fix (for example, which node/primitive and which direction).
  - Treat "Unclear" as "render a zoomed view", not as pass.
- **Verification step (LL3M pattern):** after editing, re-render and show BEFORE and AFTER sheets side by side, or as two labeled images, with the prior critique list. Ask, for each item, whether it is fixed.
- **Bias against premature acceptance:** require at least one round, phrase checks so "No" is the informative answer, and don't let the same turn that wrote the code declare it done without the checklist.
- **Offload what VLMs are bad at to code:** dimensions, counts (meshes, wheels, legs), symmetry (mirror vertex positions across the YZ plane and measure the mismatch), facing direction, ground contact, normals consistency (count faces whose normal points toward the bbox centre for convex-ish parts), and names of nodes and clips. The agent can generate these as a JSON "facts" file next to the PNG, for example with gltf-transform `inspect` (already a devDependency) or the render page itself.
- Pairwise comparison (GPTEval3D style), "is v2 better than v1 on criterion X?", is likely more reliable than absolute scores.

### Gaps
- No paper evaluates Claude specifically as a 3D render critic. All quantitative numbers are for GPT-4/4V, Gemini or Qwen.
- No study directly compares checklist critique vs free-form critique for GLB/three.js assets. CADCodeVerify vs 3D-Premise is the closest proxy.
- I found no practitioner write-up with measured results of Claude iterating on three.js models via screenshots, only skill/tooling descriptions (OpenAI develop-web-game skill; ["Giving Claude Code Eyes" Medium post](https://medium.com/@rotbart/giving-claude-code-eyes-round-trip-screenshot-testing-ce52f7dcc563), not fetched).

## Compare-to-reference techniques and existing tools

### Takeaway
Pick the comparison by the question:
- **VLM side-by-side** with a reference/concept image (BlenderAlchemy's "visual imagination", CADCodeVerify's views) for "does it match the intent".
- **Silhouette IoU** from flat-colour orthographic masks for proportions and shape against a reference or previous version.
- **pixelmatch** golden-image diffs for regression ("did my edit change anything else?").

Deterministic rendering (SwiftShader, fixed size, `setPixelRatio(1)`, no time-based animation) makes the last two practical.

### Cited Findings
- BlenderAlchemy generates reference images from text and uses them as visual targets for its VLM evaluator. Concrete visual targets improved program refinement over text-only intent — [arXiv 2404.17672](https://arxiv.org/html/2404.17672v1)
- CADCodeVerify's best automated signal still lagged a geometric solver that compares against ground-truth geometry. Point-cloud and Hausdorff distances capture spatial similarity but miss "structural differences" — [arXiv 2410.05340](https://arxiv.org/html/2410.05340v2)
- RLRF and RefineSVG compare rendered outputs against target images to give evaluative feedback when differentiable rendering is unavailable — [arXiv 2505.20793](https://arxiv.org/html/2505.20793v2); [arXiv 2607.27699](https://arxiv.org/pdf/2607.27699)
- Existing tools:
  - `@shopify/screenshot-glb` (Puppeteer + model-viewer CLI, single view) — [GitHub](https://github.com/Shopify/screenshot-glb)
  - The repo's own `tools/models.html`, a three.js GLTFLoader grid viewer with `?m=` and `?anim=` (local file)
  - The Playwright MCP's `browser_take_screenshot`/`browser_run_code_unsafe`, available in this environment

### Inferences
- **Silhouette IoU:**
  - Render each ortho view with `MeshBasicMaterial({color:white})` on black, at the same camera/extent as the reference.
  - Read pixels with `gl.readPixels` (or pngjs, already a devDependency) and compute IoU per view.
  - Report it as text, for example "front IoU 0.91, side 0.78 → side profile differs". Show a red/green overlay tile of the mismatch (reference-only red, model-only green) so the VLM sees *where*.
- **Regression:** store `golden/<model>-<mode>.png` and run `pixelmatch` (npm, pairs with pngjs) with a threshold of about 0.1. Fail on diff pixels above X% and emit a diff PNG.
  - Cross-machine flakiness from GPU differences is avoided by always using SwiftShader. Playwright's `expect(page).toHaveScreenshot()` is an alternative that has this built in.
- **Reference images:** if the user supplies a concept image (or the agent finds a Kenney/reference model), compose `[reference | current front | current 3/4]` into one image with labels. Ask checklist questions about named differences rather than "how similar".
- **Tool choice:** a custom three page beats screenshot-glb for this purpose (multi-view, helpers, normals, filmstrips, numeric facts in one pass). The Playwright MCP is good for interactive poking, but a scripted CLI is better for repeatable loops and goldens.

### Gaps
- I didn't verify current pixelmatch/odiff versions or APIs (not fetched). I didn't check whether the `three-gltf-viewer` and `gltf-viewer` CLIs still offer screenshot modes. Those tools were not researched.
- No source quantifies silhouette IoU thresholds that correlate with human "matches the reference" judgments for stylized low-poly game assets.
