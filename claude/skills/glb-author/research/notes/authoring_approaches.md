# Code-based 3D authoring by LLM agents (for GLB / three.js game assets)

Research date: 2026-10-07. Environment target: a CLI coding agent (Claude Code) with Node, three.js 0.186, @gltf-transform/core 4.5 and Python 3. Blender is not installed. The focus is code-based authoring, not text-to-3D diffusion.

Source-reliability note: academic sources were read from arXiv HTML/abstract pages via a summarizing fetch tool. Exact numbers came from that summarization, so check them against the PDFs before quoting them publicly. Items marked "(doc knowledge, not fetched this session)" are well-established documentation facts that were not re-fetched here.

## 1. Authoring routes and how LLMs do with each

### Takeaway
Every serious academic system for LLM-authored 3D (LL3M, SceneCraft, MeshCoder, 3DCodeBench, BlenderAlchemy) targets Blender Python. That is where the evidence base is, and Blender's glTF exporter is mature. For a Node-first agent without Blender, the closest practitioner analogue is three.js scene-building code (THREE.Group factories exported with GLTFExporter), as in the img2threejs skill. CAD languages (OpenSCAD, CadQuery) have good LLM literature, but they emit single-material, un-hierarchied solids, which suits game assets poorly.

### Cited Findings
- **Blender Python (bpy) is the dominant research target.** LL3M generates assets by writing Blender Python with a team of agents ([LL3M arXiv 2508.08228, Aug 2025](https://arxiv.org/html/2508.08228v1)). SceneCraft converts text into Blender scripts for scenes of up to ~100 assets ([SceneCraft, ICML 2024](https://arxiv.org/pdf/2403.01248)). MeshCoder converts point clouds into Blender Python scripts made of semantic parts ([MeshCoder arXiv 2508.14879, NeurIPS 2025](https://arxiv.org/html/2508.14879v1)). 3DCodeBench (June 2026) benchmarks 12 VLMs on writing Blender code ([3DCodeBench arXiv 2606.01057](https://arxiv.org/pdf/2606.01057)).
- **LL3M output supports game-relevant structure.** The system supports multi-object scenes with parenting relationships and hierarchy. Its generated code is interpretable, with descriptive variable names and inline documentation, so users can edit parameters directly ([LL3M](https://arxiv.org/html/2508.08228v1)).
- **Blender as a pip module.** `pip install bpy` gives Blender as an importable Python module. Each release is tied to one Python version: 4.5.x and 5.0.x wheels target Python 3.11/3.13, and 5.0.1 was released 2025-12-16. Releases outside the LTS window move to download.blender.org/pypi ([PyPI bpy](https://pypi.org/project/bpy/); [Blender docs: Blender as a Python Module](https://docs.blender.org/api/4.5/info_advanced_blender_as_bpy.html)).
- **BlenderMCP (ahujasid)** connects Claude to a running Blender GUI over MCP. Tools: scene/object inspection, create/modify/delete shapes, materials, arbitrary Python execution, Poly Haven/Sketchfab downloads, and AI-generated models via Hyper3D Rodin and Hunyuan3D. v1.5.5 added viewport screenshots ([mcpservers.org listing](https://mcpservers.org/servers/ahujasid/blender-mcp); [glama README](https://glama.ai/mcp/servers/@ahujasid/blender-mcp/blob/7636d13bded82eca58eb93c3f4cd8708dfdfbe8b/README.md)). It needs the Blender GUI with the add-on running, so it is not a pure headless CLI route.
- **Claude Code skills for headless Blender exist.** One "Blender Pipeline" skill runs headless scripts or MCP to convert assets into self-contained GLBs with embedded PBR. It also enforces poly budgets via decimation, normalizes transforms/scale, renders turntable previews and writes JSON node manifests ([mcp.directory blender-pipeline](https://mcp.directory/skills/blender-pipeline); [mcpmarket Blender 3D Asset Pipeline](https://mcpmarket.com/es/tools/skills/blender-3d-asset-pipeline)). These are third-party skill listings with no evaluation data.
- **three.js procedural route (img2threejs).** img2threejs is an open-source agent skill for Claude Code, Codex and OpenCode. It "rebuilds an object from one reference image as procedural Three.js code", emitting TypeScript THREE.Group factories built from primitives, procedural shaders and generated geometry. Its pipeline is staged: suitability check, then a detailed spec, then successive build passes, then browser-preview comparison against the reference. Quality gates cover structural detail, material realism, correct attachments and visual-review score, and the agent refines the spec or code when a review fails. The hierarchy "can include pivots, sockets, colliders, and destruction groups" ([img2threejs on SourceForge, mirror of github.com/img2threejs/img2threejs](https://sourceforge.net/projects/img2threejs.mirror/)).
- **GLTFExporter in Node needs care.** It depends on browser APIs, so textures need canvas/Blob fallbacks. Common fixes are polyfilling Blob/FileReader (e.g. the `vblob` package), using the `three-stdlib` exporter, or using `node-three-gltf`. Binary export: `await exporter.parseAsync(scene, { binary: true })` ([three.js forum: GLTF Exporter in Node backend](https://discourse.threejs.org/t/gltf-exporter-in-node-backend/44748); [forum: server-side Blob issue](https://discourse.threejs.org/t/nodejs-threejs-gltfexporter-server-side-blob-issue/4040); [node-three-gltf](https://github.com/Brakebein/node-three-gltf); [GLTFExporter docs](https://threejs.org/docs/examples/en/exporters/GLTFExporter.html)).
- **CAD-as-code (CadQuery/OpenSCAD) is well studied, for mechanical parts.** CAD-Recode fine-tuned Qwen2-1.5B to emit CadQuery sketch-extrude code from point clouds. On DeepCAD it reports mean Chamfer distance 3.43 → 0.30 and IoU 77.6% → 92.0% versus CAD-SIGNet ([CAD-Recode arXiv 2412.14042, ICCV 2025](https://arxiv.org/abs/2412.14042v2)). CADCodeVerify/CADPrompt (ICLR 2025) benchmark VLM-written CadQuery on 200 prompts ([arXiv 2410.05340](https://arxiv.org/html/2410.05340v1)).
- **Direct mesh-as-text (LLaMA-Mesh)** fine-tunes an LLM to emit OBJ vertex/face text ([LLaMA-Mesh, NVIDIA, arXiv 2411.09595](https://arxiv.org/html/2411.09595v1)). It requires a fine-tuned model, so it does not apply to a general agent.
- **Practitioners favor text-based CAD formats.** In the "Show HN: AI in SolidWorks" thread (roughly Jan 2026), commenters reported that text-based formats (OpenSCAD, Replicad, custom DSLs) worked better than binary CAD APIs. One reported a 75% failure rate on LLM-written SolidWorks C#/VBA scripts. Another (jehna1) used Replicad, a TypeScript CAD library, with live browser rendering while Claude edited one code file ([HN thread mirror](https://hn.nuxt.dev/item/46591100)).

### Route comparison (synthesis for game assets; see Inferences for basis)

| Route | Runs here today | Hierarchy / pivots | Materials | Skinning / animation | LLM evidence |
|---|---|---|---|---|---|
| three.js script + GLTFExporter (Node or headless browser) | Yes (Node, three 0.186) | Full Object3D tree. Pivot = parent Group origin | MeshStandardMaterial → glTF PBR. Vertex colors OK | SkinnedMesh + AnimationClip export supported | img2threejs, practitioner use. No formal benchmark found |
| glTF-Transform writing documents directly | Yes (4.5) | Full node tree, explicit TRS | Full PBR + extensions | Skins/animations are raw accessors (verbose) | No LLM-specific evidence found. Best used as a post-process (dedup, weld, prune, validate) |
| Blender bpy (headless `blender -b -P`, or `pip install bpy`) | Needs install (bpy wheel needs Python 3.11/3.13) | Parenting, origins, modifiers, bmesh | Shader nodes (only Principled BSDF maps cleanly to glTF) | Armatures, actions, NLA | Strongest research base (LL3M, SceneCraft, MeshCoder, 3DCodeBench) |
| BlenderMCP | Needs Blender GUI + add-on | Same as bpy | Same | Same | Popular. Viewport screenshots give a visual loop |
| trimesh / pygltflib (Python) | Likely (pip) | trimesh Scene graph. pygltflib is raw glTF | Basic PBR | Weak / manual | No LLM evidence found |
| CSG/SDF (manifold-3d, three-bvh-csg) | Yes (npm/pip) | Produces single meshes. Hierarchy via host lib | From host | None | VoxelCodeBench: boolean ops among the hardest for LLMs |
| OpenSCAD / CadQuery / build123d | Install needed | Mostly flat solids. STL/STEP-centric | Minimal | None | Good CAD literature (CAD-Recode, CADCodeVerify). Wrong output style for stylized game props |

### Inferences
- For this environment, the lowest-friction route is three.js Group-factory code exported with GLTFExporter, run in Node with polyfills or in a Playwright headless browser, then post-processed with glTF-Transform. It also renders previews in the same engine the game uses, which makes visual feedback faithful.
- Blender is worth installing (`pip install bpy` under Python 3.11/3.13, or a portable Blender tarball) when assets need bevels/modifiers, UV unwrapping, armature rigging or baked textures. It is also where the published RAG/critic techniques were validated.
- Raw glTF-Transform authoring is too low-level to be the primary modeling surface. An LLM would have to emit vertex buffers by hand. It shines as a deterministic validator and optimizer.

### Gaps
- No head-to-head study was found comparing LLM success in three.js versus bpy for the same assets. SpatialBabel reportedly shows a model's F1 shifting 5.7x purely with the scene-code language ([benchmarklist SpatialBabel](https://benchmarklist.com/benchmarks/spatialbabel/)), so language choice matters, but which language wins for three.js was not established.
- No LLM-specific evidence was found for trimesh, pygltflib, manifold-3d or build123d.

## 2. What research finds and which strategies improve quality

### Takeaway
Across papers, the same few levers recur. Decompose into parts with a planner. Retrieve API docs or examples (RAG). Feed execution errors back (cheap, large gain). Render multi-view images and have a VLM critique them, with a separate verification step. Keep code parametric and named for local edits. Executable code is now easy for frontier models. Spatially and physically correct geometry is the bottleneck.

### Cited Findings
- **LL3M (UChicago, Aug 2025).**
  - Agents: planner, retrieval, coding, critic, verification and user-proxy.
  - Models: GPT-4o for planning/retrieval, Claude 3.5 Sonnet for coding, Gemini 2.0 Flash for critique/verification.
  - The critic renders 5 views with EEVEE and the VLM flags problems such as disconnected geometry. The verification agent compares before/after renders to confirm fixes landed.
  - BlenderRAG (a RAG index of Blender API docs) raised complex function calls per asset from 1.20 to 5.86 (~5x) and cut errors from 3.29 to 2.43 (~26%) over 17 objects.
  - Timing: ~4 min initial creation, ~6 min auto-refinement, ~38 s per user edit.
  - Limitations: ~41% of user edits needed 3–4 follow-ups to fix spatial errors (~59% succeeded in one go). The VLM sometimes misses disconnected parts; for example, a watering can's handle stayed detached after auto-refinement ([LL3M](https://arxiv.org/html/2508.08228v1)).
- **3DCodeBench (Google et al., June 2026).**
  - Scope: 26K multimodal prompts, 212 categories, 12 VLMs, scored on executability, physical plausibility and semantic alignment.
  - Bottleneck: physical plausibility, not executability. Models frequently produce disconnected parts and wrong structural alignments.
  - Feedback effect: multi-turn Blender error feedback raised executability from ~70% to >97% ([3DCodeBench search summary / emergentmind](https://www.emergentmind.com/papers/2606.01057); [PDF](https://arxiv.org/pdf/2606.01057)). Per-model scores could not be extracted from the PDF via the fetch tool.
- **VoxelCodeBench (Meta, Apr 2026).**
  - Shape-correctness scores: GPT-5 87.9%, Claude Sonnet 4.5 80.4%, GPT-5 Mini 80.4%, Claude Opus 4 69.4%, Gemini Pro 19.5%.
  - Difficulty: geometric construction is the hardest category; GPT-5 drops to 66.7% from 87.5% on symbolic tasks. Only GPT-5 consistently handled boolean intersections.
  - Error causes: invalid/hallucinated API attributes ~40% of failures, timeouts/crashes ~25%.
  - Extra examples in context: mixed results. They helped weak models (Gemini Pro +24.8 pp) but hurt strong ones (Claude 3.5 Sonnet −34.8 pp), attributed to context dilution ([VoxelCodeBench arXiv 2604.02580](https://arxiv.org/html/2604.02580v1)). The Gemini figure seems anomalously low; treat it with caution.
- **SceneCraft (ICML 2024).** Builds a scene graph blueprint of spatial relations, converts relations into numerical layout constraints, refines iteratively with GPT-V critique of renders, and keeps a learned library of reusable script functions for self-improvement without fine-tuning ([SceneCraft](https://arxiv.org/pdf/2403.01248)).
- **CADCodeVerify (ICLR 2025).** The VLM generates and answers validation questions about renders of its own CAD output, then corrects. With GPT-4 this gave 7.30% lower point-cloud distance and +5.0% success rate over prior work ([arXiv 2410.05340](https://arxiv.org/html/2410.05340v1)).
- **BlenderAlchemy (Stanford, ECCV 2024).** A VLM edit generator plus a state evaluator search over Blender edit sequences (materials, lighting). "Imagined" reference images from an image-gen model supply visual grounding for abstract language goals ([BlenderAlchemy arXiv 2404.17672](https://arxiv.org/html/2404.17672v1)).
- **MeshCoder (NeurIPS 2025).** Introduces a custom expressive Blender Python API layer and part-decomposed object-code pairs. Code with semantic parts helps both editing and LLM shape understanding ([MeshCoder](https://arxiv.org/html/2508.14879v1)).
- **img2threejs (practitioner skill).** Uses a reference image, then a written spec, then staged builds with quality gates and browser preview comparison ([img2threejs](https://sourceforge.net/projects/img2threejs.mirror/)).

### Inferences
- **Highest value per cost for a CLI agent:**
  1. Always execute and feed errors back. This is nearly free and took executability from ~70% to >97%.
  2. Render multi-view previews (front/side/top/3-quarter) and have the agent inspect the PNGs. Claude Code can read images.
  3. Plan parts before coding (a named part list with dimensions and attachment points).
  4. Keep a small, curated API cheat-sheet in context rather than many examples, given VoxelCodeBench's finding that extra examples hurt strong models.
  5. Add a verification pass that checks specific claimed fixes, not just a general critique.
- **A reusable helper library helps** (SceneCraft's library learning, MeshCoder's custom API, img2threejs factories). Examples: `box(w,h,d, at, name)`, `attach(child, parentSocket)`, `wheel(radius, width)`. It reduces API hallucination, which was the top error class in VoxelCodeBench.

### Gaps
- 3DCodeBench per-model tables (including Claude 4.x results) could not be extracted.
- No reviewed study used a three.js/WebGL renderer for the critique loop. All used Blender renders.
- 3D-GPT and "3D-Premise" were not fetched this session and are not covered.

## 3. Known LLM failure modes in 3D and mitigations

### Takeaway
The dominant failures are spatial: disconnected or floating parts, misaligned and intersecting parts, wrong axes/orientation, and imprecise placement. API hallucination comes second. VLM critique catches some but not all of them. Deterministic geometric checks plus explicit conventions are the reported or implied mitigations.

### Cited Findings
- **Disconnected parts and incorrect structural alignment** are the most frequent physical-plausibility failures ([3DCodeBench](https://www.emergentmind.com/papers/2606.01057)). The 3DCodeBench taxonomy also lists axis/orientation violations ([PDF summary](https://arxiv.org/pdf/2606.01057)).
- **Imprecise spatial placement** is LL3M's main limitation (41% of edits needed 3–4 rounds). VLM critics miss disconnected components and misidentify spatial artifacts ([LL3M](https://arxiv.org/html/2508.08228v1)).
- **API hallucination** (e.g. invented enum members) accounts for ~40% of failures, and vocabulary confusion ("frustum", "capsule", "prism") also occurs ([VoxelCodeBench](https://arxiv.org/html/2604.02580v1)).
- **Practitioner reports** ([HN "Show HN: AI in SolidWorks"](https://hn.nuxt.dev/item/46591100)):
  - Wrong plane selection.
  - "Surprisingly bad at spatial reasoning unless prompted specifically" (akiselev).
  - "Half an hour generating absolute nonsense" on OpenSCAD gears.
  - Failure on rounded soap-mold shapes.
  - Mitigations that worked: describing relationships ("to the left of") instead of raw coordinates and solving numbers last; render-to-PNG-and-inspect loops; snapshots to revert bad changes.
- **Axis conventions** (doc knowledge, not fetched this session):
  - glTF 2.0 is right-handed, +Y up, +Z forward, units in meters ([Khronos glTF 2.0 spec, "Coordinate System and Units"](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)).
  - Blender is Z-up. Its glTF exporter's "+Y Up" option, on by default, converts on export ([Blender manual: glTF 2.0](https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html)).
  - three.js is Y-up and matches glTF.

### Inferences
- **State conventions in the prompt and code.** For example: +Y up, −Z or +Z as the model's forward (pick one, matching how the game's tractor code orients meshes), 1 unit = 1 m, ground contact at y=0, pivot at the base center for props, and wheel pivots at the axle center. In bpy, author Z-up and rely on the exporter's +Y-up conversion rather than mixing conventions.
- **Run deterministic post-export checks.** These catch what VLM critics miss:
  - Bounding box dimensions vs. spec.
  - min.y ≈ 0.
  - Per-part connectivity/overlap via bbox or BVH distance between parent and child.
  - Node names present.
  - Triangle count budget.
  - Normals facing outward. The rendered back-face/dark-face test or `material.side` checks help here.
  - glTF validator pass. glTF-Transform can inspect and run dedup/weld/prune.
- **Rotations:** have the agent use helper functions with degrees and named axes (e.g. `rotY(deg)`) rather than raw radians/Euler orders, to reduce rotation/units confusion. This is inferred from the API-hallucination and spatial-error data, not directly tested in a source.
- **Flipped normals and pivots:** no source reviewed quantified these specifically for LLM output. They are plausible given hand-built geometry (custom BufferGeometry winding).

### Gaps
- No quantitative data was found on Y-up/Z-up confusion rates, flipped normals or pivot errors specifically.
- No study measured how deterministic geometric checks compare to VLM critique.

## 4. Practical prompts and patterns practitioners report

### Takeaway
Practitioners who get good results run a tight loop: write code, execute, render a PNG preview, inspect, and fix. They work from a spec or reference image, build models from small named parametric parts, and keep snapshots to revert. Domain-specific helper layers (custom CLIs/DSLs, factory functions) outperform raw low-level APIs.

### Cited Findings
- **Claude Code + OpenSCAD.** Claude "knows how to use OpenSCAD to generate preview PNGs and inspect it" and cycles back. One user produced a printable STL in ~5 minutes but moved to FreeCAD when precision constraints grew ([HN thread](https://hn.nuxt.dev/item/46591100)).
- **Replicad + live browser render.** One code file plus real-time browser rendering while Claude edits ([HN thread](https://hn.nuxt.dev/item/46591100)).
- **Higher-level abstractions.** Custom CLIs that turn intent into structured operations beat direct API calls, and relationship-based placement beat explicit coordinates ([HN thread](https://hn.nuxt.dev/item/46591100)).
- **img2threejs pattern.** Reference image, then spec, then staged build passes, then browser preview vs. reference with gating scores. Outputs a THREE.Group factory with pivots, sockets and colliders ([img2threejs](https://sourceforge.net/projects/img2threejs.mirror/)).
- **Blender pipeline skills.** Normalize transforms/scale, enforce poly budgets, render turntable previews, and emit a JSON node manifest alongside the GLB ([mcp.directory blender-pipeline](https://mcp.directory/skills/blender-pipeline)).
- **LL3M's user-guided refinement.** Localized code edits instead of regeneration preserve shape coherence ([LL3M](https://arxiv.org/html/2508.08228v1)).

### Inferences
Suggested agent recipe for this project, synthesized from the above:
1. Write a part spec: a table of named parts with dimensions in meters, parent, attachment point/pivot, color/material, and a forward axis.
2. Generate a three.js Group factory from a small helper lib, with one named node per part.
3. Export a GLB via GLTFExporter in Node (polyfills) or in a headless browser.
4. Run glTF-Transform plus scripted checks: bbox, ground contact, connectivity, tri count, names.
5. Render 4–5 fixed-camera PNGs with the game's own lighting and have the agent critique them against the spec or reference.
6. Verify each claimed fix with a before/after comparison.
7. Iterate with localized edits.

### Gaps
- No X/Reddit threads with quantified results were reviewed. Practitioner evidence here is limited to one HN thread and skill listings, which are self-descriptions, not evaluations.
