# Skill design best practices and prior art for an LLM-driven GLB authoring skill (three.js, render/test loop)

Research date: 2026-10-07. The environment for the target skill is Claude Code on Linux with Node, three.js, @gltf-transform, Playwright and Python, with Blender optional.

## Anthropic's official guidance on Agent Skills (frontmatter, descriptions, progressive disclosure, size limits, scripts vs prose, evals, 2025-2026 updates)

### Takeaway
Anthropic's guidance comes down to five rules:
- Keep SKILL.md under 500 lines.
- Write a specific, third-person, slightly "pushy" description that says both what the skill does and when to use it.
- Link reference files only one level deep from SKILL.md.
- Use bundled scripts, which are executed rather than read, for anything deterministic or fragile.
- Build in validate-fix-repeat feedback loops, plus visual analysis where the output can be rendered.

Write evals before writing a lot of prose, with at least 3 scenarios and a baseline run without the skill. The Claude Code-specific frontmatter has grown well beyond `name`/`description` (for example `context: fork`, `allowed-tools`, `paths`, `hooks` and `${CLAUDE_SKILL_DIR}`).

### Cited Findings

**Frontmatter rules**
- Only two frontmatter fields are required, `name` and `description`. `name` allows at most 64 characters (lowercase letters, numbers and hyphens), no XML tags, and not the reserved words "anthropic" or "claude". `description` must be non-empty, at most 1,024 characters, and contain no XML tags. — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- Claude Code accepts many more frontmatter fields:
  - `when_to_use`. It is appended to `description`, and the two together are truncated at 1,536 characters in the skill listing.
  - `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`.
  - `allowed-tools` and `disallowed-tools`. These apply until the next user message.
  - `model`, `effort` (low through max).
  - `context: fork` with `agent`, which runs the skill in an isolated subagent. `background: false` makes the caller wait for that subagent.
  - `hooks`, `paths` (glob patterns that limit when the skill activates), `shell`, `metadata`, `license`, `compatibility` (up to 500 characters). — [Claude Code skills docs](https://code.claude.com/docs/en/skills)
- Outside Claude Code (claude.ai uploads, the Skills API), only `name`, `description`, `license`, `compatibility`, `metadata` and `allowed-tools` are supported. Other fields cause an upload error. — [Claude Code skills docs](https://code.claude.com/docs/en/skills)

**Claude Code runtime features**
- Dynamic context injection. `` !`command` `` (inline) or a ```` ```! ```` block runs before the skill content reaches Claude, and the output replaces the placeholder. A non-zero exit aborts the invocation. It can be disabled with `disableSkillShellExecution`. — [Claude Code skills docs](https://code.claude.com/docs/en/skills)
- Substitutions are available: `$ARGUMENTS`, `$N`, `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_SESSION_ID}` and `${CLAUDE_EFFORT}`. `/skill-doctor` reports each skill's context cost and how often it is invoked. — [Claude Code skills docs](https://code.claude.com/docs/en/skills)
- Skill locations: personal `~/.claude/skills/`, project `.claude/skills/`, nested `<subdir>/.claude/skills/` (loaded for sessions in or below that subdir), plugin and enterprise. — [Claude Code skills docs](https://code.claude.com/docs/en/skills)

**Writing the description**
- Write in the third person, because the description is injected into the system prompt. Include both "what it does" and "when to use it", with concrete trigger terms. Claude picks from what may be 100+ skills using the description alone. — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- skill-creator says Claude currently tends to "undertrigger" skills, so descriptions should be "a little bit pushy". It also says to put all "when to use" information in the description rather than the body. — local copy of Anthropic's skill-creator SKILL.md (anthropics/skills, synced to the user's machine)
- Simple one-step queries may not trigger a skill even when the description matches, because Claude only consults skills for tasks it can't easily do on its own. Trigger evals therefore need substantive prompts. — skill-creator SKILL.md (local copy)

**Size and progressive disclosure**
- There are three levels of disclosure:
  1. Metadata is always in context (~100 words).
  2. The SKILL.md body loads on trigger (ideally under 500 lines).
  3. Bundled files load or run only as needed.

  As a result, "the amount of context that can be bundled into a skill is effectively unbounded". — [Anthropic engineering blog, Oct 16 2025](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills); skill-creator SKILL.md
- Keep the SKILL.md body under 500 lines.
- Keep references one level deep. Claude may only `head -100` a file that is reached through a nested reference.
- Reference files longer than 100 lines should start with a table of contents. skill-creator puts this threshold at more than 300 lines.
- Organise reference files by domain so irrelevant ones are never loaded.

  — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**Degrees of freedom and scripts**
- Match how specific the instructions are to how fragile the task is:
  - "Narrow bridge with cliffs": exact scripts with low freedom.
  - Pseudocode or scripts with parameters: medium freedom.
  - "Open field": prose heuristics with high freedom.

  — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- Scripts are "more reliable than generated code", save tokens (only their output enters context), and give consistent results. Say explicitly whether Claude should execute a script or read it as reference.
- "Solve, don't defer": scripts should handle their own errors.
- Avoid "voodoo constants".
- Make validators verbose, with specific errors such as "Field X not found. Available fields: ...".

  — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- "Sorting a list via token generation is far more expensive than simply running a sorting algorithm". The blog uses this to argue for bundling deterministic code. — [Anthropic engineering blog](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

**Workflow and feedback-loop patterns**
- Give Claude a copyable checklist ("Copy this checklist and track your progress").
- Use the validate → fix → repeat loop ("only proceed when validation passes").
- Use plan-validate-execute: write an intermediate plan file such as `changes.json`, validate it with a script, then apply it.
- Use visual analysis: render the output to images and let Claude inspect them.

  — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- Further guidance:
  - Use consistent terminology.
  - Give one default tool with an escape hatch rather than many options.
  - Don't include time-sensitive information. Old patterns go in a collapsed section.
  - Use fully qualified MCP tool names (`Server:tool`).
  - List dependencies explicitly.

  — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**Evals and iteration**
- Build evaluations before writing much documentation:
  1. Run representative tasks without the skill.
  2. Turn the failures into 3 scenarios.
  3. Measure the baseline.
  4. Write minimal instructions.
  5. Iterate.

  The eval JSON has `skills`, `query`, `files` and `expected_behavior[]`. "There is not currently a built-in way to run these evaluations." — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- "Claude A / Claude B" development: one instance writes the skill and a fresh instance uses it on real tasks. Watch for unexpected exploration paths, missed links, files read repeatedly (move that content into SKILL.md) and files never read (cut them). Test with Haiku, Sonnet and Opus. — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- skill-creator's eval loop:
  - For each eval, spawn a with-skill and a without-skill subagent in the same turn.
  - Store results in `<skill>-workspace/iteration-N/eval-X/`.
  - Grade into `grading.json` (`text`/`passed`/`evidence`).
  - Aggregate into `benchmark.json` (pass rate, time and tokens, mean ± stddev).
  - Review in an HTML viewer.
  - "If all 3 test cases resulted in the subagent writing a `build_chart.py`… bundle that script."
  - Script programmatically checkable assertions.
  - Judge subjective qualities, such as design quality, qualitatively.

  — skill-creator SKILL.md (local copy)
- Description optimisation in skill-creator:
  - Write 20 trigger queries: 8-10 should trigger and 8-10 should not, with the negatives being "near-misses".
  - Split 60/40 into train and test.
  - Run each query 3 times.
  - Iterate up to 5 times with `run_loop.py` (uses `claude -p`).
  - Pick the best description by test score.

  — skill-creator SKILL.md (local copy)

**2025-2026 timeline and security**
- The engineering blog post was published October 16, 2025. On December 18, 2025 Anthropic published Agent Skills as an open standard for cross-platform portability. — [Anthropic engineering blog](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- Security: install skills only from trusted sources, and audit unfamiliar ones, especially their code and any instructions that send Claude to external network sources. — [Anthropic engineering blog](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

### Inferences
**Layout for the GLB skill**
- SKILL.md (under 300 lines) holds:
  - the workflow checklist
  - the authoring default (one recommended path, for example a Node script using three.js scene graph → GLTFExporter or @gltf-transform)
  - the commands for the bundled scripts
- `references/` holds files split by domain, each linked directly from SKILL.md:
  - `references/hierarchy-and-empties.md`
  - `references/materials-textures.md`
  - `references/skinning-bones.md`
  - `references/animation-clips.md`
  - `references/threejs-loading-gotchas.md`
- `scripts/` holds:
  - `inspect` (compact text report)
  - `validate` (deterministic checks)
  - `render` (Playwright → contact sheet PNG)
  - `animate-strip` (frames from each clip)
- `examples/` holds one or two small reference model scripts.

**Description and frontmatter**
- Name the trigger terms in the description: GLB, glTF, 3D model, low-poly asset, rig, bones, animation clip, three.js prop.
- Consider `paths: "**/*.glb, **/models/**"` and `allowed-tools: Bash(node *) Bash(npx *)` to cut down permission prompts.

**Contracts and evals**
- The "plan-validate-execute" pattern fits directly: the model writes a JSON or JS spec of parts, pivots, bones and clips. A validator checks it before building, and an inspector checks the built GLB.
- Seed evals with the Tractor Pickup assets themselves, for example "make a hay bale with a named pivot and a 'roll' clip". Make assertions on GLB inspect output (node names, clip names, bone count, bounding box). Judge appearance qualitatively from the renders.

### Gaps
- Didn't verify whether the anthropics/skills GitHub repo README changed after Dec 2025. skill-creator details come from a locally synced copy, not from fetching the GitHub source.
- Found no official Anthropic guidance specific to image-producing feedback loops beyond "Use visual analysis", such as image count, resolution or token cost per screenshot.

## Existing 3D-related skills and MCP servers: what they do, how they give feedback, what works or fails

### Takeaway
Prior art falls into four groups:
1. Blender-driving MCPs. BlenderMCP is dominant (30.2k stars) and now ships a multi-view `look` tool.
2. Pure-documentation three.js skills, such as CloudAI-X/threejs-skills (3.5k stars, no scripts).
3. Wrappers around generative APIs (Meshy, Tripo, Hyper3D Rodin, Hunyuan3D, fal, 3D AI Studio).
4. A few rigorous "code-as-model" skills with deterministic gates, such as img2threejs, mfranzon/render and spec-3d-model.

Feedback across these comes from scene-info text plus screenshots. The strongest designs run deterministic gates before vision review and keep their state in files.

### Cited Findings

**BlenderMCP (ahujasid/blender-mcp)**
- Stats: 30.2k stars, 2.7k forks, 244 commits. — [GitHub](https://github.com/ahujasid/blender-mcp)
- Tools:
  - `execute_blender_code` (arbitrary Python)
  - `look` (viewport, camera, auto-framed multi-view sheet, animation strip, wireframe, X-ray, rendered)
  - `get_scene_info` (compact summary)
  - `generate_3d` (Tripo, Hunyuan3D, Hyper3D Rodin)
  - `search_assets`/`import_asset` (Poly Haven, Sketchfab, Poly Pizza)
  - telemetry tools

  — [GitHub](https://github.com/ahujasid/blender-mcp)
- Its own warnings: arbitrary code is dangerous, so save work first; complex operations may need step-by-step breakdown; Poly Haven downloads freeze the UI. — [GitHub](https://github.com/ahujasid/blender-mcp)
- Security: on Aug 10, 2026 HN reported that the BlenderMCP maintainer's GitHub account had been compromised. Commenters flagged suspicious commits, and the impact was unclear in the thread. — [HN 49238028](https://hn.algolia.com/api/v1/items/49238028) (primary: tweet by @sidahuj, not fetched)

**Blender export-to-web skill layered on the MCP (vladmdgolam/agent-skills `blender-mcp`)**
- Its rules:
  - The MCP times out on glTF export, so always export with headless `blender --background … --python-expr`.
  - `export_apply=False`. Baking Array modifiers took one file from ~1 MB to ~56 MB.
  - Don't Draco-compress in Blender. Apply Draco last with gltf-transform.
  - Procedural texture nodes are lost on glTF export, so bake them.
  - glTF renames nodes: spaces become `_` and dots are dropped (`RINGS L.001` → `RINGS_L001`).
  - Never run `gltf-transform optimize`, because its simplification destroys detail. Run resize → WebP → Draco separately.
  - NLA strips must be unmuted for animations to export.
- Validation checklist: `gltf-transform inspect` before and after, a Babylon sandbox check, no three.js console errors, and confirming that animations play and that names map correctly. — [skills.cat listing](https://skills.cat/skills/vladmdgolam/agent-skills/blender-mcp)

**Three.js documentation skills**
- CloudAI-X/threejs-skills has 10 skills: fundamentals, geometry, materials, lighting, textures, animation, loaders, shaders, postprocessing and interaction. It targets r160+ APIs, has 3.5k stars, and contains documentation only: "does not include executable scripts" and no feedback loop. — [GitHub](https://github.com/cloudai-x/threejs-skills); [mdskills listing](https://www.mdskills.ai/skills/threejs-skills)
- A freshtechbro/claudedesignskills `blender-web-pipeline` skill exists. Not fetched. — [GitHub](https://github.com/freshtechbro/claudedesignskills/blob/main/.claude/skills/blender-web-pipeline/SKILL.md)

**Code-as-model skills**
- img2threejs rebuilds an object from a reference image as procedural three.js TypeScript:
  - Mandatory state file `.img2threejs/state.json` ("Conversation context is disposable; state.json is the local checklist authority"), with `forge/next.py` printing the next command.
  - Passes are locked and run in order: blockout → structure → form → material → lighting → interaction → optimization.
  - Deterministic gates run before AI vision: `turntable_gate.py` (four views), `self_intersection.py`, `attachment_anchor.py` (pivots/sockets), `diagnose_render.py`, and `interior_difference.py` ("silhouette IoU alone misses major defects").
  - It then builds a comparison sheet, records scores, and chooses exactly one of continue / refine-spec / refine-code / request-input / stop.
  - Correction caps: 3 per pass, 6 in total.
  - Principles: "Scripts enforce, agents judge", "Spec is authoritative", "State is truth, not context". A single viewpoint is not enough; non-planar forms need at least 2 orbit views.

  — [img2threejs SKILL.md](https://github.com/img2threejs/img2threejs/blob/main/SKILL.md)
- mfranzon/render (169 stars): `/render <description>` makes Claude write parametric build123d Python, export GLB/STEP/STL through `viewer/render.py`, and load the result in a three.js viewer (localhost:3123).
  - The viewer has solid, wireframe and X-ray modes, a dimension/bbox overlay and cross-section slicing.
  - The user draws a rectangle on the model to queue a screenshot plus an edit request in `viewer/edits/pending/`. Claude processes these on demand or through `/loop`.

  — [GitHub](https://github.com/mfranzon/render)
- spec-3d-model (Blender, for 3D printing):
  - A JSON spec is the "single source of truth" (constants plus topology), and parts are decomposed into ordered steps. This turns "3D spatial reasoning AI is bad at" into code generation.
  - `manifold_report` must show "boundary edges = 0".
  - Blender renders run automatically after each build.
  - A cheap orthographic preview sketch gates the expensive 3D build.

  — [GitHub](https://github.com/zhuchaokn/spec-3d-model)

**Generative-API wrappers**
- Meshy AI MCP (Node/TS) offers text-to-3D (preview then refine), image-to-3D, texturing, remeshing, rigging (`rig preset STANDARD_HUMANOID` from a GLB URL) and animation tasks (`rigging_task_id`, `action_id`, fps). — [Meshy MCP README](https://cdn.jsdelivr.net/gh/pasie15/meshy-ai-mcp-server@main/README.md); [glama](https://glama.ai/mcp/servers/pasie15/meshy-ai-mcp-server)
- The Tripo3D MCP offers text, image or multiview to 3D, plus animation and stylisation. — [glama](https://glama.ai/mcp/servers/mfrnwmuscm)
- Skills wrapping fal.ai, 3D AI Studio and each::labs return GLB/FBX/USDZ with PBR textures. — [mcpmarket](https://mcpmarket.com/tools/skills/generate-3d-model); [claudemarketplaces](https://claudemarketplaces.com/skills/eachlabs/skills/3d-model-generation)

**glTF and web-3D MCPs**
- A Threlte MCP exposes `analyze_gltf` and `validate_asset`. A three.ws MCP validates, inspects and optimises glTF/GLB and renders avatars. — [policylayer](https://policylayer.com/tools/serifeusstudio-threlte-mcp/validate-asset); [mcpplaygroundonline](https://mcpplaygroundonline.com/mcp-servers/io-github-nirholas-three-ws)
- I found no dedicated, widely used gltf-transform MCP.

**Godot MCPs**
- Claude-GoDot-MCP has about 170 tools, including running the game, simulating input, screenshot feedback, a profiler and debugger errors. Godot MCP Pro has 175 tools. Coding-Solo/godot-mcp launches and controls Godot and captures its debug output. — [PiMPStudios/Claude-GoDot-MCP](https://github.com/PiMPStudios/Claude-GoDot-MCP); [godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro); [dev.co](https://dev.co/ai/mcp/godot-mcp)
- I didn't research Unity MCPs in depth.

### Inferences
- With the target stack, Blender is optional. BlenderMCP's main value is its feedback design: one multi-view contact sheet, an animation strip, wireframe and X-ray modes, and a compact scene summary. That design can be rebuilt in Playwright plus three.js, with no Blender and none of the MCP security exposure.
- If Blender is used, the vladmdgolam rules are directly reusable: headless export, no modifier baking, bake procedural textures, watch for node renaming and NLA mute state, and never run `gltf-transform optimize` blindly.
- img2threejs is the most transferable pattern: a state file, ordered passes, deterministic gates first, a single decision per review, and a hard cap on corrections. For game props a lighter version will do: spec → build → inspect/validate → multi-view render → decide.
- Generative APIs such as Meshy or Tripo fit organic or hero assets that procedural code can't reach. They need network access and API keys, and they produce dense or triangulated meshes with no semantic hierarchy. That conflicts with "named empties, pivots and bones for three.js".

### Gaps
- I couldn't fetch the Unity MCP repos or the Spline and Sketchfab-specific MCPs, so I have no first-hand details on them.
- I found no user-reported success or failure rates for Meshy, Tripo or Rodin rigging when exported GLBs are used in three.js.
- The cloudai-x/threejs-skills fetch didn't report a date.

## Practitioner reports on using LLMs to build 3D game models and low-poly assets

### Takeaway
Practitioners and research agree on four points:
- LLMs are weak at direct 3D spatial reasoning but good at structured code. Decomposing the model into a spec plus code, then rendering several views for critique, is what works.
- Vision critique misses disconnected parts and precise placement errors.
- Starting from existing assets and using Claude as a "scene director" gives better results than modelling from scratch.
- Results are good for prototyping, not production topology.

### Cited Findings

**LL3M (UChicago, arXiv 2508.08228, Aug 11 2025)**
- Agents: a planner (GPT-4o), retrieval over BlenderRAG (1,729 Blender 4.4 doc files), a coder (Claude 3.5 Sonnet) writing Blender Python, a critic (Gemini 2.0 Flash) that looks at 5 rendered views, and a verifier that compares before and after renders. — [arXiv](https://arxiv.org/html/2508.08228v1)
- RAG cut errors from 3.29 to 2.43 per generation and raised complex-operation usage from 1.20× to 5.86×. Timings: about 4 minutes to create, about 6 minutes to auto-refine, about 38 seconds per user edit. About 59% of user edits needed only one instruction; the rest took 3-4. — [arXiv](https://arxiv.org/html/2508.08228v1)
- Limitation: VLMs "occasionally miss disconnected components or precise positioning errors", and placement relative to specific parts needs several iterations. — [arXiv](https://arxiv.org/html/2508.08228v1)

**HN discussions**
- HN "Why can AI generate Super Mario but not a wedge ramp…" (Aug 23 2026), linking spec-3d-model:
  - Stated causes: no parametric-CAD training data, a mismatch between mesh and B-rep representations, and no functional benchmarks.
  - Commenters report success with OpenSCAD, CadQuery and build123d, recommend metric units and context sketches, and say "structured code generation outperforms direct spatial reasoning".

  — [HN 49405520](https://hn.algolia.com/api/v1/items/49405520)
- HN "MCP server for Blender that builds 3D scenes via natural language" (Jul 2025, 151 points, 61 comments):
  - Criticism that generated meshes are triangulated rather than quads, which is bad for UV seams and animation deformation.
  - One user reports success with Claude plus OpenSCAD for 3D-printed parts.
  - Another notes similar results by going straight to three.js.

  — [HN 44622374](https://hn.algolia.com/api/v1/items/44622374)

**Guides and game projects**
- The Rundown guide (May 18, 2026):
  - Make Blender "the source of truth" and Claude "the control layer".
  - Start from existing library assets such as BlenderKit, and treat Claude "like a scene director".
  - Iterate: inspect the scene, give direction, review, then make targeted revisions.
  - Best for prototyping, mockups and animation tests, "not production-ready modeling from scratch".

  — [The Rundown](https://app.therundown.ai/guides/how-to-3d-model-anything-with-claude-blender)
- Game Forge:
  - `npm run shot -- <game> --gpu` runs a headless Playwright bot that plays the game and writes screenshots to `.shots/`.
  - The `/playtest` command means "bot-plays the game, reads screenshots, fixes what's broken".
  - A type-checker runs after every edit, and the skill lives in `.claude/skills/make-game/SKILL.md`.
  - It's a new repo with 0 stars, so treat it as a pattern, not as validated.

  — [GitHub](https://github.com/npmiaman/game-forge)
- chongdashu/threejs-tactics-game is a three.js game vibe-coded with Codex, Claude Code and Agent Skills, including a Playwright testing skill with canvas/WebGL assertions and screenshot diffing. — [GitHub](https://github.com/chongdashu/threejs-tactics-game); [search summary](https://lilys.ai/en/notes/vibe-coding-20260205/vibe-coding-2d-games-claude-agent-skills)
- Show HN: a Playwright Skill for Claude Code exists. Not fetched. — [HN 45642911](https://news.ycombinator.com/item?id=45642911)
- Polyfork takes the "every asset is a small program" approach: low-poly assets with parameters for recolouring and reshaping, exported to GLB, FBX or USDZ. — [polyfork.dev](https://polyfork.dev/)

### Inferences
**Recurring failures to design against**
- Parts floating or disconnected.
- Wrong placement or relative position.
- Wrong axis or orientation, and mirrored chirality (img2threejs explicitly gates chirality).
- Scale mistakes.
- Topology unsuitable for deformation.
- Lost materials or animations on export.

Each of these can be checked deterministically before any vision review:
- connectivity and gap checks between parts
- bounding box against expected dimensions in metres
- +Y up and −Z or +Z forward conventions
- skin weights summing to 1 and no zero-weight vertices
- clip channels targeting existing nodes

**Further pattern implications**
- A metres-based numeric spec of parts, pivots and bones written before any code mirrors the OpenSCAD and spec-3d-model lessons and reduces dependence on spatial reasoning.
- Multi-view rendering (front, side, top, 3/4, plus an animation strip) is the consensus. Use at least 4-5 views, as in LL3M's 5 and img2threejs's turntable.

### Gaps
- I couldn't fetch the threejsresources.com vibe-coding guide (403).
- I found no first-hand Reddit or X threads, or YouTube write-ups, with detailed failure logs for Claude Code authoring rigged or animated GLBs specifically. Most reports cover static props, scenes or CAD.
- I found no quantified comparison of Claude, GPT and Gemini on 3D asset code beyond LL3M's role assignments.

## Agent-harness feedback-loop patterns for skills (compact text plus image output, deterministic checks first, iteration budgets, checklists)

### Takeaway
The best-documented pattern has six parts:
1. Write a structured spec or plan file.
2. Validate it with a script that gives verbose, actionable errors.
3. Build.
4. Run deterministic inspection gates that print compact text.
5. Render one multi-view contact sheet (and an animation strip) for vision review.
6. Make exactly one recorded decision.

A hard iteration cap and a file-based checklist or state keep this loop on track across context loss.

### Cited Findings
- Anthropic's patterns: copyable progress checklists; validate → fix → repeat; plan-validate-execute with an intermediate JSON; verbose validator errors that list the valid alternatives; render to images for visual analysis. — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- Only script output consumes tokens, and the script source does not, so put heavy logic in scripts that print short summaries. — [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- img2threejs:
  - "Scripts enforce, agents judge". Deterministic gates run before AI vision.
  - A side-by-side comparison sheet.
  - One decision per review from a fixed set.
  - Caps of 3 corrections per pass and 6 in total, enforced by the state file.
  - `next.py` prints the exact next command and the loop count.

  — [img2threejs SKILL.md](https://github.com/img2threejs/img2threejs/blob/main/SKILL.md)
- BlenderMCP's `look` returns an "auto-framed multi-view sheet", an animation strip, and wireframe and X-ray modes. That is many views in one image. — [GitHub](https://github.com/ahujasid/blender-mcp)
- LL3M uses a critic that looks at 5 views and a separate verifier that checks the previous critique was actually fixed by comparing before and after renders. — [arXiv](https://arxiv.org/html/2508.08228v1)
- Validation checklist for web GLBs: `gltf-transform inspect` (meshes, textures, texture sizes, animations, accessor duplication), no three.js console errors, animations play, names mapped, file size budgets (under 5 MB optimised in that project). — [skills.cat blender-mcp skill](https://skills.cat/skills/vladmdgolam/agent-skills/blender-mcp)
- In skill-creator, assertions that can be checked programmatically are scripted, and subjective quality is judged qualitatively by a human in a viewer. — skill-creator SKILL.md (local copy)
- Game Forge runs a type-checker after every edit and a headless bot that takes screenshots. — [GitHub](https://github.com/npmiaman/game-forge)

### Inferences
**Concrete loop for the GLB skill**
- `scripts/inspect.mjs model.glb`, built on @gltf-transform/core, prints a short YAML-style report of about 30-60 lines:
  - node tree with names, types (mesh, empty, bone) and TRS values
  - world AABB in metres
  - per-mesh triangle counts and material and texture sizes
  - skins and joint counts
  - clips with duration, channels, target names and missing targets
  - extensions used
- `scripts/validate.mjs model.glb --spec spec.json` exits non-zero with messages like "Expected node 'wheel_FL' (pivot at hub). Found: wheel_fl, Wheel.001". It checks:
  - required names and pivots
  - up and forward conventions
  - bbox within tolerance
  - no NaN values
  - normalised weights and at most 4 influences
  - clips that reference existing nodes
  - texture power-of-two sizes and size limits
- Optionally add the official `gltf-validator` (KhronosGroup, available as an npm package).
- `scripts/render.mjs model.glb` uses Playwright with headless Chromium and three.js. It writes a single PNG contact sheet (front, side, top, 3/4, plus a wireframe or pivot-axes overlay) and, per clip, an N-frame strip. It prints the image paths and console errors as text.
- Store iteration state in a small JSON file next to the model, with a cap of about 3 visual iterations per asset before asking the user.
- Make "exactly one next action" an explicit rule.

### Gaps
- I found no published measurements of the best image resolution, view count or token cost per vision review for 3D critique in Claude. LL3M's 5 views and img2threejs's 4-view turntable are the only concrete numbers I found.
- I didn't fetch a source confirming the current `gltf-validator` npm package name and usage. Verify before relying on it.
