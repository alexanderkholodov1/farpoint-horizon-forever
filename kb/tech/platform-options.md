# Platform options: Godot vs Web vs Hybrid (as of 2026-11-14)

Purpose: facts for choosing the stack for a ~24 h, two-person, multi-agent build that must run in a browser via link and support 1-4 player co-op. This file does NOT make the choice. Items marked "(inference)" are reasoning, not sourced fact. "Fetched" means read from the cited page during this research; some pages were summarised by a fetch tool, so verify any number you will depend on.

## 0. Local machine check (this machine, 2026-11-14)

| Item | Result |
|---|---|
| `godot` on PATH | NOT found (`Get-Command godot` empty). |
| Godot installed | YES, via Steam: `C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`. Running it with `--version` prints `4.7.2.stable.steam.ed1daf0bf`. Not on PATH, so agents must call it by full path (or add an alias). |
| Godot export templates | Present in `...\Godot Engine\editor_data\export_templates\4.7.2.stable\` including `web_nothreads_release.zip` (~10.2 MB), `web_release.zip` (threaded), `web_dlink_*` (GDExtension variants). So web export from the editor/CLI should work without downloading templates (inference: templates are version-matched to the editor, 4.7.2). |
| scoop apps | 7zip, age, ffmpeg, gpg, mise, scoop, sops, tesseract, tesseract-languages, vcredist2022. No Godot in scoop (the scoop `extras` bucket has godot manifests, not installed). |
| Node.js | v22.23.2 |
| npm | 10.9.8 |
| pnpm | 12.11.2 |
| git | 2.55.0.windows.4 |
| GitHub CLI `gh` | `C:\Program Files\GitHub CLI\gh.exe` |
| Python | 3.13.7 |
| bun / deno | not installed |
| `C:\Program Files`, `AppData\Local` | No other Godot executables found (searched 3 levels deep for `*godot*`). |

Note: the Steam binary name looks like a legacy Steam depot name but reports 4.7.2; treat `--version` output as truth. Mobile/Android/iOS templates also exist but are irrelevant.

## 1. Godot

### 1.1 Version
- Latest stable: **4.7.2-stable, released 18 Aug 2026**. 4.7-stable was 18 Jun 2026; 4.7.1 on 14 Jul 2026. 4.8-beta3 exists (9 Nov 2026) - do not use for a hackathon. Source: https://godotengine.org/download/archive/ (fetched).
- 4.7 added wasm64 web exports (lifting the 4 GB limit); web still WebGL 2 / Compatibility renderer only; WebGPU web export is NOT in 4.7 (one outlet's initial claim was corrected). Source: third-party coverage, https://app.cinevva.com/news/2026-06-19-godot-4-7-released and https://digitalproduction.com/2026/06/23/godot-4-7-turns-up-hdr/ (search snippets, not official notes; lower confidence).

### 1.2 Web export status
Source for this block: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html (fetched).
- **Single-threaded export** exists since 4.3 and is the default; needs no special server setup, works on itch.io and with macOS/iOS. Official article: https://godotengine.org/article/progress-report-web-export-in-4-3/ .
- **Threaded export** needs SharedArrayBuffer, which needs a secure context plus headers `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. If headers cannot be set, enabling "Progressive Web App > Enable" in the export preset applies a service-worker workaround. Without either, a threaded build will not run.
- **Do we need threads?** Docs say threading brings multithreading and low-latency audio. A turn-based/UI sim does not need it (inference). Use single-threaded: no header problem on any host.
- **GitHub Pages**: gives on-the-fly gzip (docs page above). Custom response headers are not documented as supported by the Pages limits page (https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits ; page silent on headers) - so threaded export would rely on the PWA service-worker workaround (inference). Pages limits: published site <= 1 GB, soft 100 GB/month bandwidth, soft 10 builds/h (not applied to custom Actions workflow), deploy times out at 10 min (same page).
- **itch.io**: does not compress on the fly (docs page above); single-threaded builds are the usual choice; itch has a "SharedArrayBuffer support" checkbox for threaded builds, with some reports of flakiness (forum posts https://itch.io/post/9581121 , https://itch.io/post/12633201). Pre-compress or keep the build small.
- **Cloudflare Pages** supports a `_headers` file (up to 100 rules) so COOP/COEP can be set natively; free limits: 20,000 files/site, 25 MiB per file, 500 builds/month. Source: https://developers.cloudflare.com/pages/platform/limits/ (fetched). Note the 25 MiB per-file cap: the engine `.wasm` (see size below) may exceed it uncompressed - verify the actual file size before choosing (inference; limit is on asset file size).
- **Renderer/browser**: WebAssembly + WebGL 2.0 required; only Compatibility renderer works; Chromium or Firefox recommended, Safari has WebGL 2 issues. Min versions in 4.4 requirements: Firefox 79, Chrome 88, Edge 79, Safari 15.2, Samsung Internet 15 (https://docs.godotengine.org/en/4.4/about/system_requirements.html via search snippet).
- **Size/load**: no official "typical" number. Community reports: default 4.x web wasm ~20-42 MB uncompressed, a few MB with Brotli/gzip; a .pck depends on assets (forum, e.g. https://forum.godotengine.org/t/export-optimising-a-build-for-size/94584). Local templates here: `web_nothreads_release.zip` is ~10.2 MB zipped (measured on this machine), consistent with this. Docs: wasm compresses to ~1/4 with gzip. Measure your own export before the demo.
- **Mobile**: works but slower than native; iOS reports of WebGL context loss/crashes and load hangs (forum: https://forum.godotengine.org/t/webgl-context-loss-and-app-crash-in-godot-4-3-exported-web-on-ios-browsers/81024 , https://forum.godotengine.org/t/problems-with-iphone-when-exporting-to-html5/67937). Anecdotal; one mid-range Android write-up: 22 s load, 612 MB RAM. Treat judges opening on a phone as a risk (inference).
- **C# on web**: docs state C# projects in Godot 4 cannot currently be exported to web. So GDScript only (docs page above).

### 1.3 UI toolkit, charts, forms
- Godot has Control nodes (containers, Tree, ItemList, TabContainer, Theme, RichTextLabel, LineEdit, OptionButton, Sliders) - suitable for forms and dashboards (general knowledge, no source fetched). There is no built-in chart widget; charts must be custom `_draw()`, Line2D, or an addon (inference; not verified against asset library). Text-heavy, table-heavy, responsive layouts are more laborious than HTML/CSS (inference). Web build means UI renders to a canvas: no native browser text selection, accessibility, or browser form autofill (inference).

### 1.4 Orbit visualization
- 2D (Line2D, `_draw`, shaders) or 3D (MeshInstance3D spheres, ImmediateMesh/paths) both possible. Web is limited to Compatibility renderer (WebGL 2), so no Forward+ effects; fine for stylised orbits (inference). Keplerian propagation is trivial to write in GDScript; no SGP4 library bundled (inference).

### 1.5 Multiplayer on web
Source: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html and https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html (fetched).
- Peers: ENet (UDP - not usable in browsers), WebSocketMultiplayerPeer, WebRTCMultiplayerPeer. Web exports offer WebSockets and WebRTC.
- **WebSocket** needs a server that is reachable by all browsers: a headless Godot server (native export, must be hosted somewhere with wss/TLS since pages are https) or any relay (inference: https page requires wss://).
- **WebRTC** is available in web exports out of the box; needs a signaling server (typically a small WebSocket server relaying SDP) and, for peers behind strict NATs, STUN/TURN (docs page is silent on STUN/TURN). Native non-web needs the webrtc-native GDExtension.
- Free hosting for the relay/signaling: see section 2.3 (Cloudflare Workers/Durable Objects, Render free, etc.). No Godot-specific free hosting was verified.
- Net: co-op in Godot web = you must stand up a server-side component regardless; the high-level RPC API removes client code work but not the server. For a turn-based game with 4 players, a plain WebSocket relay holding authoritative JSON state is enough (inference).

### 1.6 CI export to GitHub Pages
- `barichello/godot-ci` Docker image: tags up to **4.7.2** (latest, pushed ~3 months ago per Docker Hub), also `mono-*` tags. Source: https://hub.docker.com/r/barichello/godot-ci/tags (fetched) and repo https://github.com/abarichello/godot-ci (README gives a GitHub Actions template `.github/workflows/godot-ci.yml`; says export preset names must match and `export_presets.cfg` must be committed).
- `firebelley/godot-export` action exists (supports Godot 4 and 3) but the fetched page did not show a release date or web example: https://github.com/firebelley/godot-export . Maintenance status unverified.
- Deploy step: GitHub-documented `actions/upload-pages-artifact` + `actions/deploy-pages` custom workflow (https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site). Pages on private repos: the fetched pages did not state plan rules; free accounts typically need a public repo (unverified - check repo visibility).
- Local alternative: this machine already has 4.7.2 + web templates, so a developer can export locally with the editor binary in headless mode (`--headless --export-release "Web" path`; standard Godot CLI, not sourced here).

### 1.7 Scene files and merge risk
- `.tscn`/`.tres` are text; docs say "mostly human-readable and easy for version control systems to manage", Godot "aims to be VCS-friendly and generate mostly readable and mergeable files". Sources: https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html , https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html (both fetched). Docs give no merge-conflict guidance. Node `unique_id` appears only in files saved by 4.6+. Ignore `.godot/`. Set `core.autocrlf=input` or use generated `.gitattributes`.
- Risk (inference): two agents editing the same `.tscn` (node order, sub_resource ids, ext_resource ids) produce hard-to-read conflicts, and agents cannot visually verify scenes. Mitigation: one owner per scene; build UI in code or in small per-feature scenes; keep game data in JSON/`.tres` per entity.

### 1.8 AI-agent fluency with GDScript / Godot 4
- Evidence is mostly vendor blogs. Recurrent failure modes: Godot 3 syntax in Godot 4 (KinematicBody, `yield` vs `await`, old `connect` signatures, `move_and_slide` args), https://dev.to/ziva/7-godot-4-api-calls-your-ai-assistant-still-gets-wrong-3ep6 ; a ranking by an AI-in-engine vendor names Claude Opus least prone to drift (self-interested, https://www.summerengine.com/blog/best-llm-for-godot ). Agents cannot see the scene tree without running the project; agents that run it and read errors do better (same vendors). No independent benchmark found. Compared with TypeScript/React, GDScript training data is smaller (inference).

## 2. Web stack

### 2.1 Candidate stacks (versions from the npm registry on 2026-11-14; each `npm view <pkg>`; pages `https://www.npmjs.com/package/<pkg>`)
| Package | Version | License |
|---|---|---|
| react | 19.3.1 | MIT |
| svelte | 5.57.3 | MIT |
| vue | 3.5.45 | MIT |
| vite | 8.3.8 | MIT |
| three | 0.187.0 | MIT |
| @react-three/fiber | 9.8.2 | MIT |
| phaser | 4.2.1 | MIT |
| pixi.js | 8.23.0 | MIT |
| chart.js | 4.6.1 | MIT |
| echarts | 6.1.0 | Apache-2.0 |
| d3 | 7.9.2 | ISC |
| uplot | 1.6.32 (last modified Mar 2025) | MIT |
| satellite.js (SGP4/TLE) | 7.2.0 | MIT |
| cesium (CesiumJS) | 1.147.0 | Apache-2.0 |
| worldwindjs (NASA Web WorldWind package) | 1.9.5 | Apache-2.0 (npm metadata; project status not checked) |

- Fits (inference): TypeScript + React or Svelte + Vite for the dashboard/forms/timeline; Three.js (or plain SVG/Canvas for a 2D orbit view) for visualization; Chart.js or ECharts for resource charts. All text-based source, file-per-component, friendly to parallel agents and strongly represented in AI training data (inference).
- CesiumJS is Apache-2.0 and free for commercial and non-commercial use (https://github.com/CesiumGS/cesium, fetched) but is heavy for a stylised orbit view and its default imagery uses Cesium ion (token requirement not confirmed from the page) - likely overkill (inference). satellite.js is only needed for real TLE data; for designed orbits Kepler maths is enough (inference).

### 2.2 Static hosting
| Host | Free limits (fetched) | Source |
|---|---|---|
| GitHub Pages | site <= 1 GB, soft 100 GB/mo, soft 10 builds/h (n/a for Actions deploys). Custom headers not documented. | https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits |
| Cloudflare Pages | 20,000 files, 25 MiB/file, 500 builds/mo, `_headers` supported | https://developers.cloudflare.com/pages/platform/limits/ |
| Vercel Hobby | 100 GB fast data transfer, 100 deployments/day, 1M CDN requests/mo; over limit you wait ~30 days. Hobby connects to personal repos, not Git orgs. Commercial-use rules not verified. | https://vercel.com/docs/plans/hobby , https://vercel.com/docs/limits |
| Netlify Free | 300 credits/mo hard limit; 1 GB transfer = 20 credits; production deploy = 15 credits; deploy previews/branch deploys not metered | https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/ |

### 2.3 Real-time co-op for up to 4 players
All figures fetched on 2026-11-14.
| Option | Facts | Source |
|---|---|---|
| **PartyKit hosted** | **Hosted PartyKit platform shut down: deploys stopped 16 Oct, shutdown 23 Oct 2026. Do not use.** Successor: open-source PartyServer (ISC, npm `partyserver` 0.5.10) on your own Cloudflare account, repo labelled "Work in Progress". | https://docs.partykit.io/ , https://github.com/cloudflare/partykit |
| **Cloudflare Durable Objects** (free) | Free plan: SQLite-backed DOs only; 100,000 requests/day, 13,000 GB-s/day, 5 GB storage; operations fail once exceeded. One DO per room fits a 4-player room (inference). WebSocket hibernation plan restrictions not confirmed. Needs Wrangler/Cloudflare account. | https://developers.cloudflare.com/durable-objects/platform/pricing/ |
| **Colyseus** | Node game-server framework, MIT; npm `colyseus` 0.18.12, `@colyseus/core` 0.18.28 (0.18 release announced on docs). Hosting: Colyseus Cloud (free tier not stated), Vultr image, or Docker. Needs a host with a Node process (Render free spins down after 15 min idle, ~1 min cold start, 750 h/mo; WebSocket traffic keeps it awake). Official JS client plus community Godot SDK exists (unverified). | https://docs.colyseus.io/deployment , https://render.com/docs/free |
| **Socket.IO** | npm `socket.io` 4.8.4 MIT. Same hosting need as Colyseus (Render free etc.). | npm |
| **Firebase** (Spark, no card) | Realtime Database: 100 simultaneous connections, 1 GB stored, 10 GB/mo download. Firestore: 20K writes/day, 50K reads/day, 1 GiB. 4 players x several sessions is fine. No server code needed; client SDK only. | https://firebase.google.com/pricing |
| **Supabase Realtime** | Free: 200 concurrent connections, 100 messages/s, 100 channels/connection, 256 KB broadcast payload. | https://supabase.com/docs/guides/realtime/limits |
| **Liveblocks** | Free: 500 monthly active rooms, 10 concurrent connections per room (>= 4 players OK). Free allowed for commercial use with watermark. | https://liveblocks.com/pricing |
| **Yjs + y-webrtc** | MIT; needs a signaling server (default public ones `signaling.yjs.dev`, two herokuapp URLs - status unknown, likely unreliable; npm shows y-webrtc last modified 2023-12-28). P2P mesh fine for 4 peers. No TURN, so some networks fail. | https://github.com/yjs/y-webrtc , npm |
| **Trystero** | npm 0.27.0 MIT, serverless-style WebRTC signaling over public relays (Nostr/BitTorrent etc.). Reliability unverified. | npm |

Design note (inference): a turn/phase-based game with <=4 players and a JSON state document is the easy case. Lowest-ops options: Firebase RTDB (no server), or one Cloudflare Worker + Durable Object per room. If the game is strictly deterministic from a shared config + action log, the room server can be a dumb relay.

## 3. Hybrid
- Godot -> JS: `JavaScriptBridge.eval()`, `get_interface()`, `create_callback()`. Pitfalls from docs (https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html , fetched): callbacks must be stored in a variable or are garbage collected; callback method must take exactly one Array argument; `eval` returns null for unsupported types (objects/arrays) so exchange JSON strings; floats may lose precision; returns null outside web, so guard with `OS.has_feature("web")`; some browser actions need a user gesture.
- Patterns (inference): (a) web shell + Godot in an `<iframe>`, state exchanged by `postMessage` JSON through a small `JavaScriptBridge` adapter; (b) Godot owns everything, JS only for multiplayer SDKs; (c) JS owns UI/multiplayer/data, Godot is a render-only viewer fed the state snapshot. The Godot canvas must load the 10+ MB engine in addition to the web app (load cost), and two toolchains double the CI and merge surface. Iframe and cross-origin isolation: a threaded Godot build inside an iframe requires the parent to also be cross-origin isolated (inference) - another reason to use single-threaded.
- Value only if 3D orbit visuals are a must-win and Godot skills are strong (inference); Three.js can do an orbit view with less integration risk.

## 4. Comparison (qualitative; 1 = poor, 5 = strong; judgments are inference unless sourced above)
| Criterion | Godot web | Web stack (TS + React/Svelte + Three/SVG) | Hybrid |
|---|---|---|---|
| Time to first playable | 3 (editor workflow, agents blind to scenes) | 5 (hot reload, agents can run/test headless) | 2 (two toolchains + bridge) |
| UI/dashboard/forms/charts effort | 2 (no chart widget, canvas text) | 5 (HTML/CSS, chart libs) | 4 |
| Visualization quality | 4 (3D/shaders, Compatibility renderer only) | 4 (Three.js/Canvas/SVG) | 5 |
| Multiplayer effort | 2 (WebSocket/WebRTC + you host relay) | 4 (BaaS or DO, mature JS SDKs) | 3 |
| Deploy effort | 3 (godot-ci image up to 4.7.2; headers/size caveats) | 5 (static + Vite; any host) | 2 |
| Merge-conflict risk, parallel agents | 2 (shared `.tscn`, binary-ish imports) | 4 (per-file components, JSON data) | 3 |
| AI-agent fluency | 3 (Godot 3/4 drift, evidence vendor-only) | 5 (inference: dominant training data) | 3 |
| Performance modest laptop/phone | 3 (10+ MB engine, iOS crash reports) | 4 (small bundle; WebGL still needed for 3D) | 2 |

## 5. Facts that decide it
1. Does the team already have Godot skill? Agents cannot see Godot scenes; this is the biggest swing (inference).
2. Is 3D visual fidelity required, or are 2D/stylised orbits fine? If 2D/stylised, web wins on UI-heavy scope.
3. Must it work on phones/iOS Safari for judges? Godot web has documented iOS issues.
4. Multiplayer hosting: can the team create a free Cloudflare/Firebase/Supabase account? That decides the co-op approach; PartyKit hosted is dead.
5. Actual size of your Godot web export vs host limits (Cloudflare 25 MiB/file; itch.io no on-the-fly compression).
6. Repo visibility (public needed for free GitHub Pages in most cases - unverified here).

## 6. Measured on the team's laptop (2026-11-14 spike)
A minimal Godot 4.7.2 project, exported headless to the web and run in a real browser engine (headless Microsoft
Edge driven by Playwright), proved the chain the team needs for "Godot made locally, published on the web, Firebase
through JavaScript":
- Export: `godot --headless --path . --export-release "Web" build/index.html` with the single-threaded template
  (`variant/thread_support=false`): 2.8 s, exit 0. No COOP/COEP headers needed, so GitHub Pages can host it.
- Sizes: `index.wasm` 37.7 MB raw, 9.7 MB gzip-compressed (what a browser downloads when the host compresses);
  `index.js` 0.27 MB; the game's own `index.pck` 15 KB for the test scene.
- Browser log: "OpenGL ES 3.0 (WebGL 2.0) - Compatibility", "Emscripten 4.0.20, single-threaded".
- Round trip, both directions, every second: a page script standing in for Firebase called a Godot callback
  (`JavaScriptBridge.create_callback`, kept in a member variable) with a JSON string; Godot parsed it, updated the
  screen, and answered through `JavaScriptBridge.eval("window.reportFromGodot(...)")`. First answer from Godot 2.6 s
  after the page started loading (local server).
- Pitfalls found: (1) every file in the project folder is packed unless excluded: `node_modules` made the pack 25 MB
  until a `.gdignore` file was put in it; (2) JSON numbers arrive in Godot as floats (`2` becomes `2.0`): cast where an
  integer is meant; (3) Godot draws on a canvas, so browser tests read the console, not the page's DOM; (4) the
  editor on the desktop has no `JavaScriptBridge`: guard with `OS.has_feature("web")` and test online play in the
  exported build.
