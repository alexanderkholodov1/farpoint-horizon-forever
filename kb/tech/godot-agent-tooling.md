# Godot agent tooling: letting AI agents operate Godot 4.7, see the game and make 3D models

Researched 2026-11-14 for the two-person SK-Horizons team (Windows 11, Godot 4.7.2 Steam, Claude Code mainly, plus Cursor and Codex).
Facts come from GitHub API/README reads and official docs fetched today; each has a URL. "(inference)" marks reasoning not
verified by a source. Star counts and dates are as of 2026-11-14.

## 0. This machine (read-only check, 2026-11-14)

| Item | Result |
|---|---|
| Godot | `C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`, `--version` = `4.7.2.stable.steam.ed1daf0bf`. Not on PATH (`where godot` finds nothing). |
| Blender | **Installed**: `C:\Program Files\Blender Foundation\Blender 4.3\blender.exe`, version 4.3.2 (2024-12-17). Not on PATH. |
| Node / npx | v22.23.2 (mise) and `C:\Program Files\nodejs`; `npx` available. |
| Python | 3.13.7 on PATH. |
| uv / uvx | **Not installed** (needed by Godot AI, Blender MCP, Windows-MCP). |
| Claude Code | 2.1.325. |
| Edge/Chrome on PATH | `where msedge chrome` finds nothing on PATH (Edge is installed in the standard location; Playwright found it in the 2026-11-14 spike, see `platform-options.md` section 6). |
| Existing repo assets | `tests/look/autoshot.gd` + `tests/look/autoshot.tscn` (screenshot-by-script), `tests/ci/fuzz.gd`; no `.mcp.json` yet. |

## 1. MCP servers and editor plugins for Godot 4.x

Two architectures exist (source for the split: the READMEs below):
- **Headless-script servers**: the MCP server spawns `godot` itself with a helper `.gd` script. No editor plugin. Cannot see the open editor.
- **Editor-bridge plugins**: an addon inside the running editor opens a socket; the MCP server talks to it. Can read the live scene tree, take viewport screenshots, run the game and read errors.

### Comparison

| Tool | Type | Stars / last push | License | Godot support | Verdict |
|---|---|---|---|---|---|
| hi-godot/godot-ai | editor addon + Python server | 3,532 / 2026-11-14 (releases v4.4.1 2026-11-03, v4.4.0 2026-11-02, v4.3.1 2026-10-24) | MIT | README: "Godot 4.7+" | **Best fit, most active** |
| satelliteoflove/godot-mcp | editor addon + npm server | 185 / 2026-11-13 (godot-mcp-v4.2.0 2026-11-09) | MIT | README badge: Godot 4.5+ | **Best for playtesting** |
| Coding-Solo/godot-mcp | headless-script server (npm) | 6,648 / 2026-04-16, no GitHub releases, 76 open issues | MIT | no version range stated; UID tools need 4.4+ | Simple, stale since April; no screenshots |
| 3ddelano GDAI MCP | editor addon + server | 103 / 2026-09-11 | "All rights reserved" (no SPDX license) | README: 4.1+ | Avoid (licence, see below) |
| youichi-uda/godot-mcp-pro | editor addon | 643 / 2026-09-24 | proprietary, "$15 one-time" (SPDX NOASSERTION) | "Godot 4" | Paid, closed; skip |
| ee0pdt/Godot-MCP | editor addon + server | 622 / **2025-03-19** | MIT | old | Abandoned for 8 months; skip |
| bradypp/godot-mcp | server (fork lineage of Coding-Solo) | 90 / 2025-05-31 | MIT | unstated | Stale; skip |
| KeeVeeG/godot-mcp | editor addon | 31 / 2026-07-12 | MIT | unstated | **Archived**; skip |

Sources: GitHub API for each repo, e.g. https://api.github.com/repos/hi-godot/godot-ai, https://api.github.com/repos/satelliteoflove/godot-mcp,
https://api.github.com/repos/Coding-Solo/godot-mcp, https://api.github.com/repos/3ddelano/gdai-mcp-plugin-godot,
https://api.github.com/repos/youichi-uda/godot-mcp-pro, https://api.github.com/repos/ee0pdt/Godot-MCP,
https://api.github.com/repos/bradypp/godot-mcp, https://api.github.com/repos/KeeVeeG/godot-mcp.
Release lists: https://api.github.com/repos/hi-godot/godot-ai/releases, https://api.github.com/repos/satelliteoflove/godot-mcp/releases.

### 1.1 hi-godot/godot-ai ("Godot AI")  -- primary recommendation
- Repo: https://github.com/hi-godot/godot-ai , README https://raw.githubusercontent.com/hi-godot/godot-ai/main/README.md , tools https://raw.githubusercontent.com/hi-godot/godot-ai/main/docs/TOOLS.md
- Claims 46 MCP tools / 120+ operations, "21,000+ monthly active installs" (self-reported, anonymous telemetry; see risks).
- Does: scene tree read (`scene_get_hierarchy`), node create/set property/find, scene open/save, script create/attach/patch (GDScript validated), signals, UI, materials, animation (incl. AnimationTree), particles, cameras, environments, audio buses, import options; `batch_execute` with rollback; `project_run` (play, waits for game liveness, returns recent errors); `logs_read` (plugin/game/editor logs, including parse errors and Debugger errors-tab rows); `test_run` (runs GDScript test suites inside the editor with its own `McpTestSuite`); **`editor_screenshot`** with sources `viewport` (editor 3D), `viewport_2d`, `cinematic` (renders through the scene's Camera3D, no gizmos) and `game` (running game framebuffer; needs the `_mcp_game_helper` autoload and a `project_run` cycle). It cannot screenshot the editor UI chrome (docs: https://raw.githubusercontent.com/hi-godot/godot-ai/main/docs/screenshot-testing.md ). Optional "vision routing" replaces images by text descriptions (docs/vision-routing.md).
- Godot version: README says "Godot 4.7+" (the team's 4.7.2 qualifies). Verify on first install.
- Install (README quick start): install uv (Windows: `irm https://astral.sh/uv/install.ps1 | iex`, or `winget install --id=astral-sh.uv -e`); copy the addon from AssetLib or a GitHub release into `addons/godot_ai/` (do not extract over an existing install; use the dock's Update button); enable under Project > Project Settings > Plugins; in the "Godot AI" dock press **Configure** per client. It writes configs for 26 clients incl. Claude Code, Claude Desktop, Codex, Cursor, VS Code (TOML for Codex; JSON for others; Claude Code via `claude mcp add`). Default scope is user; set editor setting `godot_ai/mcp_client_scope=project` for per-project registration. Use the dock-generated command: a bare `http://127.0.0.1:8000/mcp` entry will not authenticate (README). Client config details: https://raw.githubusercontent.com/hi-godot/godot-ai/main/docs/client-configuration.md
- Ports: Python server HTTP 8000, editor plugin WebSocket 9500 (docs/port-conflicts.md exists). Two people each on their own laptop: no clash. One person with two editors: clash (inference).
- Windows: supported install path is PowerShell + uv. GDScript fully supported; C# text-only.
- Other agents: same MCP server works for Cursor and Codex (listed clients).

### 1.2 satelliteoflove/godot-mcp
- Repo: https://github.com/satelliteoflove/godot-mcp , README https://raw.githubusercontent.com/satelliteoflove/godot-mcp/main/README.md , install guide https://raw.githubusercontent.com/satelliteoflove/godot-mcp/main/INSTALL.md
- 21 tools / 86 actions, designed so an agent can verify its own work: `godot_editor_edit run frozen=true`, `godot_game_time step/step_until` (deterministic), `godot_runtime_state digest` (live positions/state as JSON, cheap versus screenshots), `godot_input` (actions, keys, joypad, mouse), `godot_exec` (run GDScript inside the running game), `godot_editor_read screenshot_game`, editor error log, `godot_scene3d` (engine-computed 3D transforms/bounding boxes), `godot_docs` (version-matched Godot docs as markdown), `godot_profiler`, `godot_validate_meshes`, animation/tilemap/gridmap/resource tools. By design it does not duplicate what file edits can do (creating scenes means writing `.tscn` text).
- Read/write tool split, so `*_read` tools can be auto-allowed; `--read-only` flag exists.
- Godot 4.5+ (needs the Logger class). Node 20+. MIT.
- Install: register `npx -y @satelliteoflove/godot-mcp` (JSON `{"mcpServers":{"godot-mcp":{"command":"npx","args":["-y","@satelliteoflove/godot-mcp"]}}}`), then `npx @satelliteoflove/godot-mcp --install-addon <project path>`, enable the plugin. Node is already on this machine (no uv needed).
- Small project (185 stars) but very active; bus factor one (inference).

### 1.3 Coding-Solo/godot-mcp
- Repo https://github.com/Coding-Solo/godot-mcp , README https://raw.githubusercontent.com/Coding-Solo/godot-mcp/main/README.md , npm `@coding-solo/godot-mcp`.
- 14 tools: `launch_editor`, `run_project`, `stop_project`, `get_debug_output`, `get_godot_version`, `list_projects`, `get_project_info`, `create_scene`, `add_node`, `load_sprite`, `export_mesh_library`, `save_scene`, `get_uid`, `update_project_uids`. No screenshots, no editing of existing nodes, sprite loading is 2D only. Works by running Godot with a bundled `godot_operations.gd` (no addon).
- Registration: `claude mcp add godot -e GODOT_PATH="C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" -- npx @coding-solo/godot-mcp`; Cursor via `.cursor/mcp.json` or Settings > MCP; generic JSON `{"mcpServers":{"godot":{"command":"npx","args":["@coding-solo/godot-mcp"],"env":{"GODOT_PATH":"..."}}}}`.
- Cursor note from README: MCP tools require Agent chat, which needs a paid Cursor plan.
- Most-starred, but last commit 2026-04-16 and no tagged releases; superseded in capability by 1.1/1.2 (inference).

### 1.4 GDAI MCP (3ddelano)
- https://github.com/3ddelano/gdai-mcp-plugin-godot , README https://raw.githubusercontent.com/3ddelano/gdai-mcp-plugin-godot/main/README.md , site https://gdaimcp.com
- Features per README: scene/node/script creation, property get/set, debugger and log access, `res://` file search, screenshots of editor and running game. Godot 4.1+. Works with Cursor, Windsurf, Claude, VS Code.
- Licence: copyright 2025 Delano Lourenco, "All rights reserved"; README FAQ says commercial game use is fine but **the plugin must not be committed to a public game repository**. Sources disagree on price (Summer Engine's guide https://www.summerengine.com/blog/godot-mcp-servers-guide.md calls it paid; that vendor competes with it). Our project is public open source, so the plugin would have to be kept out of git (inference: unnecessary friction when MIT alternatives exist).

### 1.5 Others seen
- Godot AssetLib has many newer "MCP" entries (e.g. Godot MCP Toolkit, Godot .NET MCP for 4.6+, Godot AI Workbench) found through search: https://godotengine.org/asset-library/asset/5375 . Not evaluated; most are low-visibility. A comparison from Summer Engine (a competing commercial product) is a March 2026 snapshot and unreliable on features.
- Summer Engine is a separate AI-first Godot fork (not Godot itself); out of scope (inference: we must stay on stock 4.7.2 for the web export).

### 1.6 How MCP servers are registered (Claude Code, Cursor, Codex)
- Claude Code: `claude mcp add <name> -- <command> <args>` (user scope default `local`; add `--scope project` to write a shared `.mcp.json` at repo root). Docs: https://code.claude.com/docs/en/mcp . On native Windows, `npx` is a `.cmd` shim, so use `cmd /c npx ...` if the plain form fails (inference from the cmd wrapper advice in the Blender and Windows-MCP READMEs below; verify).
- Project `.mcp.json` format: `{"mcpServers": {"name": {"command": "...", "args": [...], "env": {...}}}}`. Project-scope servers require each person to approve them once in Claude Code (godot-ai README says the same).
- Cursor: `.cursor/mcp.json` (project) or `~/.cursor/mcp.json`; same JSON shape (Coding-Solo README).
- Codex: `~/.codex/config.toml` with `[mcp_servers.name]` `command=`/`args=`, or `codex mcp add name -- cmd args` (shown in https://raw.githubusercontent.com/ahujasid/mcp-for-blender/main/README.md and https://raw.githubusercontent.com/CursorTouch/Windows-MCP/main/README.md).

## 2. Godot's built-in hooks for agents

Source for all flags: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html (page is the Godot 4.7 stable docs). Binary below = the Steam exe from section 0.

| Flag | Use |
|---|---|
| `--headless` | = `--display-driver headless --audio-driver Dummy`; no window. |
| `--path <dir>` | project dir containing `project.godot`. |
| `-s, --script <file>` | run a `.gd` extending `SceneTree`/`MainLoop`. |
| `--check-only` | with `--script`: parse for errors, then exit. |
| `--import` | open editor, import resources, quit (run after adding assets and before export on a fresh checkout/CI). |
| `--export-release <preset> <path>` / `--export-debug` | export; target directory must exist; editor build only. Measured here: `godot --headless --path . --export-release "Web" build/index.html` 2.8 s (`platform-options.md` section 6). |
| `--quit` / `--quit-after <n>` | exit after 1 / N iterations (n frames). Essential so agent runs terminate. |
| `--write-movie <file.avi|.png>` | render frames to a movie or PNG sequence at fixed FPS (`--fixed-fps`); combine with `--quit-after` for frame count. Needs a real renderer (see screenshots). |
| `--rendering-driver <d>` / `--disable-render-loop` / `--fixed-fps <n>` | renderer selection, render only on request, deterministic timing. |
| `--lsp-port`, `--dap-port`, `--debug-server <uri>` | override LSP / DAP / debug server ports (editor builds). |

Docs warning: unknown arguments are silently ignored, so a typo gives no error.

Practical error-reading recipes (inference unless noted):
- Syntax check one script: `godot --headless --path . --check-only --script res://scripts/x.gd` (parse only; it will not catch every cross-script type error).
- Whole-project load check: `godot --headless --path . --import` or run the main scene with `--quit-after 60`; read stderr and the log. The game log on this machine is at `%APPDATA%\Godot\app_userdata\SK-Horizons - Mission Architect\logs\godot.log` (from `CLAUDE.md`).
- CI export check: the same headless export command as above.

### 2.1 GDScript language server (LSP) and debug adapter (DAP)
- Source: https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html
- LSP default port **6005** (Editor Settings > Network > Language Server); DAP default **6006** (Network > Debug Adapter). A Godot editor must be running on the project; the editor/IDE then connects to the port. Docs do not say whether it works with `--headless`; (inference) an agent-side LSP client would need the editor running, so it is not a good agent hook compared with MCP.
- Claude Code has an `LSP` tool for configured language servers (this session lists it); wiring GDScript to port 6005 would need an LSP-over-TCP bridge (inference, unverified; not recommended for week-long hackathon).
- Since Godot 4.5 external-editor flags are auto-detected for VS Code, JetBrains, etc.; enable "Auto Reload Scripts on External Change" so agent file edits show up in the open editor (same page).
- DAP is only useful for breakpoint debugging in an IDE; agents get errors from logs instead.

### 2.2 Screenshot of a running scene
- **Non-headless**: from any script, `await RenderingServer.frame_post_draw` then `get_viewport().get_texture().get_image().save_png(path)`. The repo's `tests/look/autoshot.gd` already does this and was reported working on Godot 4.5.1 and 4.7.1 on Linux (Compatibility renderer) (`CLAUDE.md`). Run it with a real renderer and a quit: `godot --path . res://tests/look/autoshot.tscn --quit-after N` (inference on exact invocation). On this laptop the project must use `gl_compatibility` (AMD iGPU crash with Forward+ per `CLAUDE.md`).
- **Headless**: `--headless` uses the Dummy rendering server, so the viewport texture has no data and `get_image()` returns null/empty. Community threads: https://ask.godotengine.org/150510/godot-headless-not-same-godot-window-cant-render-the-backend . So agents must run windowed (a window flashes on screen) to capture. Or use `--write-movie out.png --quit-after N` (also needs rendering; inference).
- Editor-based capture through MCP: Godot AI `editor_screenshot` (viewport/cinematic/game) and satelliteoflove `screenshot_game`, no OS screen control needed.
- Web build: see section 3.1.

### 2.3 Test frameworks
| Framework | Godot 4.7 | Headless CI | Licence |
|---|---|---|---|
| gdUnit4 (MikeSchulze/gdUnit4) | v6.2.3 (2026-11-01) notes "fresh Godot 4.7 editor"; compatibility table: v6.2.x = Godot 4.5-4.7.1, master v7.0.0 = 4.7, 4.7.1, 4.8.dev7 | command-line tool for CI, JUnit XML + HTML reports, `gdunit4-action` GitHub Action | MIT |
| GUT (bitwes/Gut) | v9.7.1 on branch `godot_4_7` for 4.7.x (main branch = 4.6.x) | CLI (`gut_cmdln.gd`; detail in https://gut.readthedocs.io , not verified here) | MIT |

Sources: https://github.com/MikeSchulze/gdUnit4 (releases API https://api.github.com/repos/MikeSchulze/gdUnit4/releases), https://github.com/bitwes/Gut (README https://raw.githubusercontent.com/bitwes/Gut/main/README.md, releases https://api.github.com/repos/bitwes/Gut/releases).
Notes: gdUnit4 v6.2.3 says 4.7 introduced stricter return-value type checking (changes in v9.7.0 of GUT too: "Compatibility changes for Godot 4.7"); older addon versions can break on 4.7. Pin matching versions. Godot AI also ships its own `test_run`. For a hackathon (inference): a plain `tests/*.gd` script run by `godot --headless --script` (like `fuzz.gd`) plus Godot AI/gdUnit4 for logic is enough; do not spend time on a full framework unless game logic (scoring, mission math) needs regression tests.

## 3. Seeing the game

### 3.1 Web build with Playwright (verified on this machine)
- The 2026-11-14 spike drove headless Microsoft Edge with Playwright against the Godot web export (`platform-options.md` section 6). WebGL needs flags such as `--use-angle=swiftshader` (and typically `--enable-unsafe-swiftshader`, `--ignore-gpu-blocklist`; the exact flags are as verified by the lead; extra two are inference) in headless mode. Page logs show "OpenGL ES 3.0 (WebGL 2.0) - Compatibility".
- Godot draws on a canvas, so tests read console output and canvas screenshots (`page.locator('canvas').screenshot()`), not DOM. JavaScript hooks (`JavaScriptBridge`) round trip was proven.
- Playwright MCP (Microsoft): https://github.com/microsoft/playwright-mcp , Apache-2.0, 39,637 stars, pushed 2026-11-13, releases v0.0.85 (2026-11-09). Gives an agent browser tools through MCP with accessibility snapshots; for a canvas game the snapshot is nearly empty, so screenshots are the useful part (inference). A plain Playwright script (node/python) run by the agent via Bash gives more control (custom launch args, console capture) and needs no MCP (inference; recommended).
- Serve locally (`python -m http.server` in `build/`) and keep `.gdignore` in `node_modules` (pitfall from the spike).

### 3.2 Desktop editor: screen-control options (Windows)
| Option | Facts | Risk |
|---|---|---|
| CursorTouch/Windows-MCP | https://github.com/CursorTouch/Windows-MCP, MIT, 11,669 stars, pushed 2026-11-14, release v0.8.9 (2026-11-12). Windows 10/11, **needs Python 3.14+** (we have 3.13; uv would download one), uses UI accessibility tree plus screenshots, mouse/keyboard, latency 0.2-0.5 s per action. Register: `claude mcp add --transport stdio windows-mcp -- uvx windows-mcp serve` (README); Codex via `config.toml`; if "Connection closed", use full path to `uvx.exe`. | Controls the whole desktop with the user's rights (can click anything, run shell-type tools); prompt injection from on-screen text; the laptop has the user's logged-in sessions. Heavy for a 2-person team on VivoBook-class hardware (inference). |
| Claude Code built-in computer use / other | Not verified here. | n/a |
| mediar-ai/terminator | https://github.com/mediar-ai/terminator, MIT, 1,671 stars, last push 2026-06-02. | Less active. |

Recommendation (inference): use the editor-bridge MCP screenshot (Godot AI/satelliteoflove) plus script screenshots; use Windows-MCP only as a fallback for tasks MCP cannot do (editor dialogs, import errors popups, AssetLib), and only supervised.

## 4. 3D models

### 4.1 Blender and Blender MCP
- **Blender 4.3.2 is installed** (`C:\Program Files\Blender Foundation\Blender 4.3\blender.exe`; not on PATH). Godot 4 `.blend` import requires Blender 3.0+ (3.5+ recommended), official build, and the path under Editor Settings > Filesystem > Import > Blender > Blender Path (https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). Recommended: export `.glb` from Blender and commit that, so the other person does not need Blender (docs: every team member needs Blender for `.blend` import).
- **ahujasid blender-mcp, now `ahujasid/mcp-for-blender`** (GitHub API reports full_name `ahujasid/mcp-for-blender`): https://github.com/ahujasid/mcp-for-blender , MIT, 34,413 stars, pushed 2026-11-13; PyPI package `mcp-for-blender` (the `uvx blender-mcp` command still works per README). README https://raw.githubusercontent.com/ahujasid/mcp-for-blender/main/README.md
  - Features: create/modify/delete objects, materials, **arbitrary Blender Python (`execute_blender_code`)**, multi-angle/wireframe viewport views and renders for visual self-check, Poly Haven assets, Sketchfab and Poly Pizza models, AI model generation (Meshy, Tripo, Hyper3D Rodin, Hunyuan3D; paid/keys or its "premium" plan).
  - Install: `uvx mcp-for-blender setup` (installs uv if needed, configures Claude Code, Codex, Cursor, etc., installs and enables the Blender addon) or manual: `claude mcp add blender uvx mcp-for-blender`, `codex mcp add blender -- uvx mcp-for-blender`, `uvx mcp-for-blender install-addon`. In Blender press N > "MCP for Blender" tab > Start MCP Server. Socket port 9876 (`BLENDER_PORT`). Only run one MCP server instance per Blender. Windows: bare `uvx` may fail with `spawn uvx ENOENT` in GUI clients; use full path or `cmd /c uvx`.
  - Risks: arbitrary code in Blender ("ALWAYS save your work", README); telemetry: minimal anonymous usage record by default, content collection opt-in only (README "Telemetry Control").
- Alternative without MCP (inference): the agent writes a Python script and runs `"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" -b --python make_ship.py` to produce a `.glb` (Blender CLI `-b` background, `--python`; standard Blender CLI). Reproducible, committed as source, no socket, no setup. For a stylized spacecraft/planet game this is probably the most robust path. Cannot "see" the result unless the script also renders a PNG (`bpy.ops.render.render(write_still=True)`), which the agent can then view.
- Godot-native alternative (inference): procedural meshes and primitives (`CSGBox3D`, `MeshInstance3D` with `SphereMesh`, `CylinderMesh`) assembled by the agent; satelliteoflove's `godot_validate_meshes` helps for procedural meshes.

### 4.2 Free model sources and licences
| Source | Terms | Notes / URL |
|---|---|---|
| NASA 3D Resources | Site: "All of these assets are free to download and use"; repo says "free and without copyright"; defers to NASA media guidelines. Formats include GLB, Blender, FBX, STL, OBJ-like (site lists 3ds, Blender, FBX, GLB, LWO, Max, Maya, OpenVSP, STL). | https://science.nasa.gov/3d-resources/ , https://github.com/nasa/NASA-3D-Resources . Guidelines https://www.nasa.gov/nasa-brand-center/images-and-media/ : NASA content generally not copyrighted in the US; **credit NASA as source; NASA insignia (meatball) and logotype (worm) are protected** and may not be embedded without approval; no implied endorsement; third-party material is marked with its own copyright. Check each model's own notes (some are contractor/ESA/JAXA content, inference). Mission-themed hackathon: credit "NASA" and keep logo textures off models. |
| Kenney | CC0, attribution not required, commercial OK. | https://kenney.nl/support ; assets https://kenney.nl/assets . Has Space Kit, Space Station Kit etc. (inference from catalogue; verify pack names). |
| Poly Pizza | Per-model licence, mostly CC-BY with some CC0; CC-BY requires credit (title, author, link, licence). Poly.pizza pages returned 404 for /about and /faq today; licence details come from secondary guides, so read each model page. | https://poly.pizza ; secondary: https://app.cinevva.com/guides/free-3d-model-sites . Keep a `CREDITS.md` in the repo. |
| Sketchfab | Per-model: most downloadable models CC BY; ~2000+ CC0; some CC BY-NC / ND exist. Credit required unless CC0; avoid NC/ND for this project (open source + judging; inference). Free downloads/API reported still working in 2026; the store moved to Fab (single secondary source). | https://help.sketchfab.com/en/articles/16152215-crediting-users-for-3d-model-downloads , https://sketchfab.com/developers/download-api/guidelines |
| Poly Haven | CC0 (textures/HDRIs/models). | https://polyhaven.com/faq (not fetched today; licence widely documented as CC0; verify). |

Rule (inference): only CC0, NASA public domain, or CC-BY with a logged credit; reject NC/ND and anything without a clear licence; record each asset's URL, author and licence in `CREDITS.md`.

### 4.3 glTF import into Godot 4
- glTF 2.0 (`.glb` or `.gltf`) is the recommended format; `.blend` works through Blender, FBX through ufbx (4.3+), OBJ lacks skeletons/animation/PBR (docs link above).
- Blender export tips from the docs: enable Backface Culling in Blender materials and re-export (Blender glTF export disables it, hurting performance); for blend shapes enable deformation bones.
- Web budget (inference): keep models low-poly; the exported wasm is already 9.7 MB gzipped, check pack size on the host limits in `platform-options.md`.

## 5. GDScript fluency of agents

Source for syntax facts: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html (4.7 docs).

Known drift pitfalls (agents trained on Godot 3 or early 4 code):
| Wrong (Godot 3 / old) | Right (Godot 4) |
|---|---|
| `yield(get_tree().create_timer(1), "timeout")` | `await get_tree().create_timer(1).timeout` (docs: `yield` kept only as a keyword for transition) |
| `onready var x = $X` | `@onready var x = $X` ; do not combine `@onready` with `@export` (warning `ONREADY_WITH_EXPORT` is an error by default) |
| `export(int, 1, 100) var v` | `@export_range(1, 100) var v: int` |
| `KinematicBody`/`KinematicBody2D` + `move_and_slide(vel)` | `CharacterBody3D`/`2D`, `velocity` property, `move_and_slide()` with no args |
| `connect("sig", self, "_on_x")`, `emit_signal("sig")` | `sig.connect(_on_x)`, `sig.emit()`; `signal health_changed(old, new)` |
| `setget` | `set(value):` / `get:` blocks (always called in 4.x) |
| `Spatial`, `Position3D`, `rand_range`, `OS.get_ticks_msec()` | `Node3D`, `Marker3D`, `randf_range`, `Time.get_ticks_msec()` |
| `instance()` | `instantiate()` |
| `tool` | `@tool` |
| Shadowing engine methods | unreliable in 4.x, warning `NATIVE_METHOD_OVERRIDE` |
Also: JSON numbers from JavaScript arrive as floats (cast); Godot 4.7 has stricter return-type checks that break older addon code (gdUnit4 and GUT notes above); abstract classes (`@abstract`) and variadics exist from 4.5; typed dictionaries from 4.4 (docs).
(The migration list above is common knowledge compiled by the author, consistent with the docs page; only the rows quoted from the docs are source-verified.)

Mitigations (inference unless sourced):
1. Pin in `AGENTS.md`: "Godot 4.7.2 stable, GDScript 2, typed GDScript, Compatibility renderer; never emit Godot 3 APIs" plus the table above as a cheat sheet (the repo's `AGENTS.md` already says 4.7).
2. Make the official docs available: satelliteoflove's `godot_docs` tool fetches version-matched docs; otherwise point agents to `https://docs.godotengine.org/en/stable/classes/class_<name>.html`.
3. Always close the loop: after each script edit run `godot --headless --path . --check-only --script <file>` or `logs_read`/`get_open_script_errors` through MCP; run the game 60 frames with `--quit-after` and fail on any `ERROR`/`SCRIPT ERROR` in output; commit a `tests/smoke.sh`.
4. Add the check to CI (GitHub Actions) with the headless export (measured 2.8 s here).
5. Use typed GDScript and keep scripts small; enable warnings as errors for critical ones in `project.godot` (inference).
6. Edit `.tscn` by MCP or by Godot only when unsure; hand-edited `.tscn` is fragile (UIDs, `load_steps`); Coding-Solo has `update_project_uids` (UID needs 4.4+).

## 6. Recommendation (concrete toolkit)

Install order, per person (both laptops identical):
1. **Add Godot to PATH or a project script**: define `GODOT="C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"` in a `tools\godot.cmd` wrapper (inference) and tell agents the path in `AGENTS.md`. Value: headless export, check-only, smoke run, CI parity. Zero install.
2. **Smoke/screenshot scripts in the repo** (`tests/look/autoshot.gd` already exists; add `tests/smoke.gd` and a `run_checks` script). Value: agents see output as PNG and errors as text without any MCP. Zero risk.
3. **Install uv** (`winget install --id=astral-sh.uv -e`), needed by Godot AI and Blender MCP.
4. **Godot AI (hi-godot/godot-ai)** as the main Godot MCP: scene tree, node/script edit, run, logs, screenshots (viewport/cinematic/game), tests. Register from its dock for Claude Code (per-project scope), and each person presses Configure for Cursor/Codex. Commit `addons/godot_ai/` or document installing it from the Release (inference: decide on one; MIT allows committing, but dock warns against extracting over installs).
5. **satelliteoflove/godot-mcp** as an optional second server for playtesting (deterministic stepping, input injection, runtime-state digest) if running two MCP servers against one editor is acceptable (inference: unverified that both addons coexist; try one at a time first). It needs Node only, which exists.
6. **Playwright script** (not MCP) for the web build: launch Edge with `--use-angle=swiftshader`, screenshot the canvas, capture console. Value: proves the published artifact works, which is what judges run.
7. **Blender**: already installed; start with scripted `blender -b --python` to produce `.glb`, add **mcp-for-blender** only if the team wants interactive modelling; use Kenney CC0 and NASA models first (cheapest). Log credits in `CREDITS.md`.
8. **Windows-MCP** last and only if needed (supervised).

Registration cheat sheet (adapt paths):
- Claude Code, project-scope shared file `.mcp.json` (committed), then each person approves once. Godot AI: use the dock-generated entry (needs auth header). satelliteoflove: `claude mcp add --scope project godot-mcp -- npx -y @satelliteoflove/godot-mcp`. Blender: `claude mcp add blender -- uvx mcp-for-blender`.
- Cursor: same servers in `.cursor/mcp.json` (Agent mode, paid plan per Coding-Solo README).
- Codex: `codex mcp add blender -- uvx mcp-for-blender`; Godot AI dock writes the TOML.
- Both people need the Godot editor open on the project for the editor-bridge servers to answer; one editor per laptop.

What each is good for:
- Scripts + CLI: reliable, scriptable checks (compile, export, smoke).
- Godot AI: building and inspecting scenes, seeing viewport/game screenshots.
- satelliteoflove: autonomous playtest loops with cheap structured state.
- Playwright: published-build verification.
- Blender (script or MCP): custom ship/planet models.

Avoid:
- GDAI MCP (all-rights-reserved, not allowed in a public repo, paid reports conflict).
- ee0pdt/Godot-MCP, bradypp, KeeVeeG (stale or archived), Godot MCP Pro (closed, paid).
- Relying on Coding-Solo as the only tool (no screenshots, no node edit, stale since April).
- `--headless` for any rendering/screenshot (Dummy renderer).
- LSP/DAP wiring for agents (requires running editor, little payoff).
- Windows-MCP as a default (whole-desktop control, Python 3.14+ requirement).
- AI model generators needing paid keys unless the team accepts the cost.
- Non-credited Poly Pizza/Sketchfab models and any NC/ND licence.

## 7. Main risks
1. **Godot AI says 4.7+ only and is young (v4.x releases weekly)**: an update can break the flow; pin its version and read CHANGELOG before updating (README warns "Update promptly" for certificate issues, and the dock handles updates).
2. **Telemetry**: Godot AI and Blender MCP send anonymous usage; satisfy privacy expectations (opt-out settings exist per their docs: https://raw.githubusercontent.com/hi-godot/godot-ai/main/docs/TELEMETRY.md ).
3. **Arbitrary code execution**: Blender `execute_blender_code`, `godot_exec`, Windows-MCP: run only on the dev laptops, save work first, keep read-only flags where possible.
4. **GPU**: the team's AMD iGPU crashed Forward+; screenshots via MCP rely on a rendered editor, keep Compatibility renderer (`CLAUDE.md`).
5. **Editor must be open** for editor-bridge tools; two people editing the same `.tscn` causes merge pain (see `collaboration.md`).
6. **Windows quirks**: `npx`/`uvx` spawn failures in GUI clients; uv PATH; Python 3.14 requirement for Windows-MCP.
7. **Licence hygiene** for assets in a public repo (section 4.2).
8. **Unverified here (no installs allowed)**: none of these servers was run; Godot 4.7.2 compatibility of satelliteoflove and Godot AI rests on their README statements.
