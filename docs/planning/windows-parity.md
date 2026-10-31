# Windows / Linux parity plan

> **Status:** v0.4 — decisions accepted, execution started — for review, no code changes yet
> **Date:** 2026-10-30
> **Scope:** OpenMT2 client (`open-mt2/pkg_*`), devkit build image, and the `speedtreebkr` baker
> **Owner:** TBD
>
> **v0.2:** adds the renderer-backend seam as a *socle* for a future Vulkan backend
> (§4.4, decisions D11–D13, tasks T1.7–T1.8 and Wave 5). No Vulkan code is in scope.
>
> **v0.3:** adds the test-first baseline (Wave A), the repository consolidation into
> `neoeter` (§4.5, Wave B, decisions D14–D16).


This document is the working plan for making the client build **one codebase, two
targets**, with **no proprietary dependencies** and **the smallest possible
dependency set shared by both targets**. It is meant to be iterated: §5 holds the
open decisions, §11 the decision log.

---

## 1. Goal and non-goals

### Goal

1. **Single source tree.** Windows and Linux compile the *same* platform layer, not
   two parallel implementations.
2. **Behavioural parity ("iso").** Same assets, same UI, same input, same rendering
   output on both targets.
3. **No proprietary software** in the build or runtime dependency graph.
4. **Nearly identical dependencies** for both targets, so adding a feature never
   means solving it twice.
5. **`.exe` producible from the Linux Docker image**, so a Windows user can pull the
   image and build without MSVC, `vcvars`, `msbuild`, or a `.sln`.
6. **Replaceable renderer backend.** The GL renderer sits behind a seam (§4.4), so a
   future Vulkan backend can be added without touching game code.

### Non-goals (this plan)

- Implementing a Vulkan (or any second) backend. Only the seam is in scope (Wave 5 is
  scoped and sized, not scheduled).
- Replacing the embedded Python 2.7 interpreter with Python 3 (separate programme).
- Replacing game assets, textures, models, or `.spt` source data.
- Server-side work.
- 32-bit Windows *as the shipping target* until D10 is decided.

---

## 2. Definitions

| Term | Meaning in this document |
|---|---|
| **Parity / iso** | Same source, same dependency set, same asset layout; artefacts differ only by executable format and the platform runtime DLLs. |
| **Platform layer** | Window creation, event loop, input, GL context, IME/text input, audio backend. |
| **Proprietary** | Anything not redistributable under an open-source licence: D3D9/D3DX9, DirectInput, DDraw, DShow, Miles, SpeedTreeRT runtime, Granny, IE/ActiveX. |
| **Characterization test / golden master** | A test that pins *current* behaviour (a hash, a transcript, a rendered image) so a refactor can be proven not to change it. Used where a clean unit test is impossible or too expensive. |
| **Coverage ratchet** | A recorded per-module coverage baseline; CI fails on regression, not on an absolute target. |
| **Done** | `docker run … windows` and `docker run … build` both succeed from a clean image, produce interoperable `dist/` trees, and pass the smoke test in T3.2. |


---

## 3. Current state (audit, HEAD of all `pkg_*` repos)

Total client source: **~286k lines** across 16 packages.

### 3.1 Already replaced — good news

| Proprietary component | Replacement | Evidence |
|---|---|---|
| Granny 3D (`granny2.dll`) | Clean-room reader: `GrannyCompat.h`, `Gr2Reader.cpp`, `Gr2Decompress.c` | `etergrnlib/include/EterGrnLib/GrannyCompat.h:1-8`, `GrannyReadEntireFileFromMemory` at `:715`; no `LoadLibrary` of granny anywhere |
| SpeedTreeRT (`SpeedTreeRT.dll`) | `SpeedTreeRTCompat.cpp` consuming baked `treecache/*.tree` | `speedtreelib/src/SpeedTreeRTCompat.cpp:325` (`LoadBakedGeometry`), `:920` (search paths) |
| Miles (`mss32.dll`) | `MilesLib` on **miniaudio** + `MSSCompat.h` | `mileslib/CMakeLists.txt:94-104`; only a stale `#pragma comment(lib,"mss32.lib")` remains |
| D3D9 | GL 2.1+ implementation in `eterbase/src/Direct3DDevice9Compat.cpp` (1545 lines) | Linux-only today, see §3.2 |
| IE / ActiveX browser | Stub | `cwebbrowser/src/CWebBrowser.cpp` (72 lines) |

### 3.2 The platform split (the real work)

Windows currently compiles a second platform implementation. Two backends coexist:

| Area | Linux path | Windows path |
|---|---|---|
| Renderer | `Direct3DDevice9Compat.cpp` (GL), file gated `#if defined(__LINUX__)` at line 11 | real D3D9 + `directxsdk/d3dx9.h` |
| Window / event loop | SDL2 (`MSWindow.cpp:94-128`, `MSApplication.cpp`, `GrpScreen.cpp:759-790`) | `CreateWindow`/`WndProc` (`MSWindow.cpp:180`) |
| Input | SDL2 scancodes (`Input.cpp:4`, `:92`) | DirectInput8 (`Input.cpp:33`) |
| IME / text input | no-op stubs (`IME.cpp:2211-2214`, `:2308-2313`) | IMM/TSF (`IME.cpp`, `msctf.h` 12k lines, `Dimm.h` 6.5k lines) |
| Headers | `Platform/Platform.h` + `DirectXMathCompat.h` shims | `<windows.h>`, `<d3d9.h>`, `<dinput.h>` (`eterlib/include/EterLib/StdAfx.h:23-40`) |
| Link deps | SDL2, OpenGL, JPEG, Freetype, pthread, dl | mss32, SpeedTreeRT, dinput8, ddraw, strmiids, dmoguids, dxguid, version, imagehlp (`userinterface/src/UserInterface.cpp:41-58`) |
| Build entry | `scripts/build.sh` (CMake) | `scripts/build.bat` → `Metin2Client.sln` + MSVC + `extern/` |

Counts: **39 files** contain `__LINUX__` gates, **82 files** contain `_WIN32`
branches. The D3D9 API surface itself is not the problem — the renderer headers
(`GrpBase.h`, `GrpDevice.cpp`, …) already compile against the compat shim on Linux.

### T0.1 measured Windows blockers (2026-10-30)

The diagnostic i686 run is recorded in `evidence/T0.1.log`, with reproduction
instructions in `evidence/T0.1.md`. D10 still selects x86_64 for shipping. This
probe does not establish 64-bit compatibility or runtime/rendering parity.

Ranked by the earliest observed gate and package reach:

1. **Toolchain (T0.2):** the unmodified image lacks both the cross-CMake wrapper
   and MinGW C++. All 16 packages fail configuration. The probe provides explicit
   CMake cross arguments when the wrapper is absent. Adding only
   `g++-mingw-w64-i686` in a disposable diagnostic image exposes the next gates.
2. **Target LZO (T2.3):** 11 packages stop at `EterBase/CMakeLists.txt:34`:
   EterBase, EterLib, MilesLib, EterGrnLib, SpeedTreeLib, PRTerrainLib, EffectLib,
   ScriptLib, EterPythonLib, GameLib, UserInterface. These are configuration
   blockers, not eleven independently observed compiler defects.
3. **Target libzip (T2.3):** EterPack stops at its CMake dependency check. Host
   pkg-config directories are excluded from the probe.
4. **DirectX SDK headers (T1.1/T1.5/T4.1):** SphereLib configures but all four
   compilation units fail on `directxsdk/d3dx9.h`. Keep-going compilation records
   every attempted unit. Passing `OPENMT2_RENDERER=GL` alone does not enable the
   future shared renderer path; current packages report the variable unused.

EterLocale, EterImageLib and CWebBrowser build static libraries successfully.
These are standalone package results, not an integrated executable/link test.
Remaining SDL/OpenGL, Python, audio, image and platform-code risks in §3.2–3.3
remain **unmeasured behind these gates**. Repeat this inventory after T2.3;
do not infer that packages blocked at configure time have clean source code.

### 3.3 Dependency inventory

| Dependency | Linux source | Windows source today | Licence | Direction |
|---|---|---|---|---|
| SDL2 | apt | — | zlib | **share** (needed on Windows) |
| OpenGL | apt (`OpenGL::GL`) | `opengl32` via D3D9 client | system | **share** (loader needed, see D1) |
| miniaudio | built in image | — | public domain | **share** (vendored, header-only) |
| zlib | apt | `extern/` (MSVC) | zlib | **share** (cross-build) |
| lzo2 | apt | `extern/` (MSVC) | GPL-2.0+ | **share** (cross-build; required by pack format) |
| libzip | apt | `extern/` (MSVC) | BSD-3 | **share** (cross-build) |
| libjpeg | — | — | IJG | **remove** (D5 revised in T2.2: replaced by `stb_image_write`) |
| DevIL (`IL`) | apt | `extern/` (MSVC) | LGPL-2.1 | **remove** (D4) |
| Python 2.7 | built in image | `extern/` (MSVC) | PSF | **decide** (D3) |
| DirectX SDK | — | `extern/` | proprietary | **remove** |
| Miles / SpeedTreeRT / Granny | — | `bin/`, `extern/` | proprietary | **already removed** |

Note: `scripts/build.sh:166` already excludes `*.dll` from `dist/`, so the legacy
proprietary DLLs are not shipped today.

---

## 4. Target design

### 4.1 One platform stack

```
            ┌──────────────────────────── one code path ────────────────────────────┐
 app        │ GameLib · UserInterface · EffectLib · PRTerrainLib · …                │
 renderer   │ D3D9-compatible API  →  Direct3DDevice9Compat (OpenGL 2.1+/3.0)       │
 window     │ CMSWindow / CMSApplication / Input  →  SDL2                          │
 audio      │ MilesLib  →  miniaudio                                               │
 model/mesh │ EterGrnLib → clean-room Gr2 reader · SpeedTreeLib → treecache        │
 platform   │ Platform.h + DirectXMathCompat.h (single shim for every target)      │
 image      │ stb_image / stb_image_write                                          │
```

### 4.2 Macro scheme

Replace the implicit `__LINUX__` / `_WIN32` split with explicit switches:

| Macro | Meaning |
|---|---|
| `OPENMT2_PLATFORM_WINDOWS` / `OPENMT2_PLATFORM_LINUX` | target OS (set by CMake) |
| `OPENMT2_RENDERER_GL` | use the compat renderer (both targets) |
| `OPENMT2_SDL_WINDOW` | use SDL2 for window/event/input (both targets) |

`__LINUX__` stays defined for legacy third-party guards, but no new code may use it.

### 4.3 Artefacts

```
dist/
├── metin2client        # ELF          ┐
├── metin2client.exe    # PE32/PE32+   ├ same assets, same treecache, same pack/
├── config / config.exe #              ┘
├── SDL2.dll            # Windows only
├── python27.dll        # Windows only
├── BGM/ lib/ mark/ miles* / pack/ screenshot/ upload/ treecache/
└── *.txt, *.cfg (game data)
```

`miles/` is legacy naming for the sound data directory and stays until a separate
asset rename.

### 4.4 Renderer backend seam (socle for a future Vulkan backend)

This is **not** a Vulkan implementation. It is the boundary that makes one possible
later without touching game code.

Today the renderer is a single translation unit: `eterbase/src/Direct3DDevice9Compat.cpp`
calls OpenGL directly (**240 call sites, 58 distinct `gl*` symbols**), and the app above
it already speaks D3D9 (`IDirect3DDevice9`, `IDirect3DTexture9`, `IDirect3DVertexBuffer9`,
`IDirect3DIndexBuffer9`, `IDirect3DVertexShader9`, `IDirect3DPixelShader9`,
`IDirect3DSurface9`, `IDirect3D9`, … in `DirectXMathCompat.h:1618-2200`). That
concentration is a gift: the seam is mostly mechanical.

Target layering:

```
GameLib / UserInterface / EterLib   — unchanged, still speak D3D9
        │
        ▼
D3D9 façade                          — state tracking only, no GL
        │  RenderState snapshot + DrawCall
        ▼
IRenderBackend                       — the seam
        ├── GL backend      (now, pass-through to OpenGL 2.1)
        └── Vulkan backend  (later, PSO cache + explicit sync)
```

Illustrative contract (names only, not final):

```cpp
struct RenderCaps  { uint32_t maxTextureSize; bool dxt1, dxt5, twoSidedStencil, separateAlphaBlend; };
struct RenderState { /* render states, texture-stage states, transforms, lights, material, FVF */ };
struct RenderHandle{ uint32_t id; uint32_t generation; };   // opaque, backend-owned
struct DrawCall    { RenderHandle vs, ps, vb, ib; uint32_t minVertex, numVertices, startIndex, primCount; };

class IRenderBackend {
public:
    virtual bool         Init(const BackendDesc&) = 0;
    virtual void         Shutdown() = 0;
    virtual RenderCaps   Caps() const = 0;
    virtual RenderHandle CreateTexture(...), CreateVertexBuffer(...), CreateIndexBuffer(...) = 0;
    virtual void         Destroy(RenderHandle) = 0;
    virtual void         BeginFrame() = 0;
    virtual void         ApplyState(const RenderState&) = 0;  // GL: set state · Vulkan: bind PSO
    virtual void         Draw(const DrawCall&) = 0;
    virtual void         Present() = 0;
    virtual bool         Readback(...) = 0;                   // screenshots, conformance
};
```

The contract is deliberately the same for two very different consumption styles:

- **GL backend — immediate.** `ApplyState` issues `glEnable`/`glMatrixMode`/… on the spot;
  `Draw` issues `glDrawElements`.
- **Vulkan backend — compiled.** `ApplyState` hashes the snapshot into a pipeline-state
  cache entry; `Draw` binds that PSO plus a descriptor set and records a command. No
  immediate-mode calls.

**Invariants to protect now** (cheap now, expensive later). These are the actual
deliverable of the socle:

| # | Invariant | Why it matters |
|---|---|---|
| R1 | No `gl*` symbol outside `eterbase/src/backends/gl/` | keeps the backend replaceable |
| R2 | `RenderHandle` opaque; no `GLuint`/`GLenum` above the backend | Vulkan handles are not integers |
| R3 | State changes populate `RenderState`; the backend never reads `IDirect3DDevice9` | the Vulkan PSO key can only be derived from a snapshot |
| R4 | Exactly one `Draw()` entry point with an explicit snapshot | no per-draw GL in `Grp*` code |
| R5 | Capability queries (`Caps()`) instead of `#ifdef` feature tests | feature sets differ between GL and Vulkan |
| R6 | Explicit frame boundaries (`BeginFrame`/`Present`) | GL sync is implicit; Vulkan needs semaphores/fences |
| R7 | No readbacks outside `Readback()` | GPU stalls and Vulkan layout transitions |
| R8 | Backend chosen at configure time (`OPENMT2_RENDERER=gl`) | one binary per backend, no runtime `#if` maze |

**What the seam must model but not implement yet** — this is where the real Vulkan
cost lives:

1. **Fixed-function → program.** Vulkan has no fixed pipeline, and this client leans on
   fixed-function heavily: **68 distinct `D3DRS_*`**, **25 `D3DTSS_*`**, 57 `SetTransform`,
   501 `SetTextureStageState`, 11 `SetLight`, 9 `SetMaterial`, 53 `SetFVF`. A Vulkan
   backend must turn each state snapshot into a program (state→shader synthesis, or an
   uber-shader keyed by the snapshot). The GL backend gets this for free from GL 2.1.
2. **Shaders are currently ignored.** On the GL path `CreateVertexShader` /
   `CreatePixelShader` return dummy objects, `SetVertexShader*`/`SetPixelShader*` are
   no-ops, and `D3DXAssembleShaderFromFileA` returns an empty 64-byte buffer
   (`DirectXMathCompat.h:1898-1912`, `:2162-2168`). One creation site each
   (`GrpVertexShader.cpp:39`, `GrpPixelShader.cpp:37`), loaded per effect. Vulkan cannot
   ignore them → D12.
3. **Resource lifetime and synchronisation.** `IDirect3DResource9` uses refcounting and
   GL frees on `Release`; Vulkan needs deferred destruction, layout transitions and
   frames-in-flight.
4. **Presentation.** `Reset`/`Present`/resize must become an `ISwapchain`-style
   abstraction with out-of-date handling, not `SDL_GL_SwapWindow` (`GrpScreen.cpp:759-790`).

**Ordering.** Build the seam as **T1.7 inside Wave 1**, as a pure pass-through with zero
behaviour change, *before* T1.5 hardens the GL calls into the Windows path. Write the
feature matrix (**T1.8**) at the same time: it is the contract the Vulkan backend will be
tested against, and it doubles as the parity checklist.

The `Readback()` entry point is shared with the parity harness: the offscreen
render-diff used to compare Linux vs Windows (T3.2) becomes the same tool that compares
GL vs Vulkan (T5.4).

### 4.5 Repository topology (Neoeter)

Today the client is **16 repositories, ~286k lines**, one CMake target and one test
binary per repository (22 CTest cases, ~3,900 lines of tests). This plan touches
**every** repository: `T1.1` alone edits 39 files spread across all 16. Every
cross-cutting change is a 16-PR coordination problem, and an agent has to track 16
checkouts.

The dependency graph extracted from `target_link_libraries` is already clean — almost
no upward or sideways edges:

```
L0  spherelib · eterlocale · eterimagelib · cwebbrowser      (leaves)
L1  eterbase (lzo, GL) · eterpack (libzip)
L2  eterlib (SDL2, GL, freetype, jpeg)                       ← 53k lines
L3  mileslib · etergrnlib · speedtreelib · prterrainlib · effectlib
L4  scriptlib · eterpythonlib                                (Python 2.7)
L5  gamelib
L6  userinterface                                            ← 66k lines
```

That is the important finding: **a repository split can follow the graph instead of
history.** The current names (`EterBase`, `EterLib`, `EterLocale`, …) are historical and
carry no architectural meaning.

#### Options

| Option | Repos after | Pros | Cons |
|---|---|---|---|
| 1. Single `neoeter` monorepo (engine + bindings + game) | 1 (+ devkit, + baker) | one PR per cross-cutting change, one CI, one version, trivial for agents | Python becomes a CMake option, not a boundary; external consumers get the whole tree unless CMake export is done |
| **2. Three-layer split (recommended)** | 3 (+ devkit, + baker) | "engine has no Python" enforced by the repository; engine reusable and testable alone; renderer work isolated; game stays application-level | cross-layer changes need 2 PRs; 3 CI pipelines |
| 3. Two-repo: `neoeter` (everything but the game) + `client` | 2 | simpler than option 2, keeps the game separate | no hard Python boundary |
| 4. Keep 16 repos + superbuild manifest | 16 | lowest migration risk | does not fix the churn |

**Recommended (option 2):**

| Repo | Contents | Lines |
|---|---|---|
| **`neoeter`** | engine, layers L0–L3: platform, IO, image, render, audio, model, terrain, effect | ~132k |
| **`neoeter-python`** | `scriptlib` + `eterpythonlib` (the Python 2.7 bridge) | ~49k |
| **`client`** | `gamelib` + `userinterface` (Metin2 game) | ~101k |
| `devkit`, `speedtreebkr` | unchanged | — |

This matches the definition already written in `project.md`: *Neoeter is the EterLib
overhaul, bundling the historical client libraries into a mono-repository, available for
Windows and Linux compilations.* The game is not Neoeter; the engine is.

`open-mt2/neoeter` does not exist yet (as of 2026-10-30), so the move can create the
repository with its final layout instead of reshaping an existing one.

#### Layout inside `neoeter`

Group **by role**, but keep **one CMake target per current library** — repository count
is not target count. Nothing is lost, test boundaries stay intact:

```
neoeter/
├── src/
│   ├── platform/   base · math (spherelib) · locale          → Neoeter::Platform
│   ├── io/         pack                                      → Neoeter::IO
│   ├── image/      imagelib                                  → Neoeter::Image
│   ├── render/     EterLib + backends/{gl}                   → Neoeter::Render
│   ├── audio/      MilesLib + miniaudio                      → Neoeter::Audio
│   ├── model/      EterGrnLib + SpeedTreeLib                 → Neoeter::Model
│   ├── terrain/    PRTerrainLib                              → Neoeter::Terrain
│   └── effect/     EffectLib                                 → Neoeter::Effect
├── tests/
└── cmake/
```

Two prunings that should happen **during** the move, not before:

- `cwebbrowser` is a 72-line no-op stub with no working implementation on either target
  (`cwebbrowser/src/CWebBrowser.cpp`). Delete it and the `WebBrowser_*` call sites, or
  keep it as an optional single-file target. Today it only exists to satisfy the linker.
- `spherelib` and `eterimagelib` are small leaves used only by the engine. Folding their
  *targets* into `platform`/`image` is defensible, but keeping them separate costs
  nothing and preserves test granularity. Prefer merging **directories**, not targets.

#### Migration mechanics (pure moves, provable)

1. **Preserve history.** Per old repo: `git filter-repo --to-subdirectory-filter
   src/<role>`, then merge into the new tree. Tag each old repo `final`, archive
   read-only.
2. **One commit that only moves files** and rewrites CMake paths. No code edits. Verify
   against the Wave A baseline: same targets, same 22 CTest cases, same static-library
   hashes / render hashes.
3. **Compatibility shims for one cycle.** Keep the old include roots (`<EterBase/...>`)
   and target aliases (`EterBase::EterBase` → `Neoeter::Platform`), so the devkit and any
   downstream consumer keep building.
4. **Rewire the devkit.** Replace `scripts/packages.map` + `scripts/fetch-packages.sh`
   with `scripts/sources.map` + `scripts/fetch-sources.sh` pulling 3 repos into
   `src/neoeter`, `src/neoeter-python`, `src/client`. As executed, the include
   roots were renamed (`<Neoeter/…>`, `<Client/…>`) instead of shimmed.

#### Ordering advice

Do the consolidation **after** the test baseline (Wave A) and **alongside T0.1**, i.e.
before the parity work. The tests make a pure-move merge provable; the merge cuts the
parity work from 16 repositories to 3. It is **not a prerequisite**: the parity plan
stands without it, and it can be dropped if the schedule tightens.

---

## 5. Decisions to settle (iteration surface)

Each decision blocks at least one task. Recommendations are what I would do; change
them freely, they will be recorded in §11.

| ID | Decision | Options | Recommendation | Blocks |
|---|---|---|---|---|
| **D1** | Renderer policy | (a) GL compat everywhere; (b) dual backend, D3D9 on Windows | **(a)** — parity is the stated goal, and it removes the DirectX SDK from the graph entirely | T1.4, T1.5, T4.1 |
| **D2** | Window/input policy | (a) SDL2 everywhere; (b) keep Win32+DInput on Windows | **(a)** | T1.2, T1.3 |
| **D3** | Python 2.7 on Windows | (a) ship official PSF `python-2.7.18-win32` DLL + generated import lib; (b) cross-compile CPython 2.7 with MinGW; (c) keep per-platform interpreters | **(a)** — fastest, licence-clean, no fork | T2.4 |
| **D4** | DevIL | (a) replace with stb_image/stb_image_write; (b) keep | **(a)** — ~5 call sites, removes an unmaintained dep from both targets | T2.1 |
| **D5** | libjpeg | (a) keep (open source, used by EterLib); (b) replace with stb | **(b) replace**: the T2.2 audit found a single writer call site (screenshots) | T2.2 |
| **D6** | IME / CJK input | (a) implement on SDL2 text input for both; (b) documented no-op on Linux, IMM on Windows | **(a)**, but it can ship after parity | T1.6 |
| **D7** | Where build logic lives | (a) devkit only (presets + entrypoint); (b) presets/CI inside each `pkg_*` | **(a)** for the pipeline, per-package `CMakeLists` fixes as needed | T0.2 |
| **D8** | Cross toolchain | (a) MinGW-w64 (`i686`/`x86_64-w64-mingw32`); (b) clang-cl + xwin + MSVC-built `extern/` libs | **(a)** — (b) keeps MSVC-produced binaries in the graph, contradicting the goal | T0.1, T2.3 |
| **D9** | Path / case sensitivity | (a) normalise in the VFS layer; (b) keep per-OS behaviour | **(a)** — otherwise identical asset trees behave differently | T3.3 |
| **D10** | Bitness | (a) 64-bit on both; (b) 32-bit on both; (c) as-is (Linux x86_64, Windows Win32) | **(a)** — `GrannyCompat` is explicitly 64-bit safe; requires a data-width audit | T0.3, all of Wave 2 |
| **D11** | Renderer abstraction style | (a) custom `IRenderBackend` under the existing D3D9 façade; (b) adopt a portable abstraction (bgfx / sokol_gfx / Diligent / wgpu) and reimplement the façade on it; (c) write a D3D9→Vulkan translation layer (DXVK-style) | **(a)** — keeps the app API that already exists, adds no dependency, and the D3D9 façade is the only stable contract today. Revisit (b) only if a second platform API (Metal, WebGPU) becomes a requirement | T1.7, all of Wave 5 |
| **D12** | Shader strategy for a Vulkan backend | (a) synthesise programs from fixed-function state; (b) translate D3D9 shader bytecode to SPIR-V; (c) both | **(c)** — (a) covers the fixed-function bulk, (b) rescues the real shader effects. Evaluate `vkd3d-shader` (LGPL-2.1, supports SM1–3 bytecode) before writing a translator | T5.2 |
| **D13** | Today's silent shader no-op | (a) leave as-is; (b) log/count ignored shaders and record the parity delta; (c) implement shader support on the GL path now | **(b)** now (cheap, makes the limitation visible), (c) folded into T5.2 | T1.8 |
| **D14** | Repository topology | (a) single `neoeter` monorepo; (b) three-layer split (engine / Python bridge / game); (c) two-repo; (d) keep 16 + superbuild | **(b)** (§4.5) — the layer graph is already clean, and a hard "no Python in the engine" boundary is worth one extra PR per cross-layer change | TB.* |
| **D15** | Test framework | (a) keep the hand-rolled `TEST_ASSERT` + `main` style used by all 22 existing tests; (b) adopt a single-header framework (doctest/Catch2); (c) GoogleTest | **(a)** with a shared `tests/support/` header — zero new dependency, consistent with the no-proprietary/minimal-deps goal; revisit only if CTest reporting becomes limiting | TA.1 |
| **D16** | Change ordering | (a) tests → consolidation → parity; (b) parity → tests → consolidation; (c) tests → parity → consolidation | **(a)** — the baseline makes both later steps provable, and the consolidation is what makes the parity work cheap | TA.*, TB.*, Wave 0 |

---

## 6. Work breakdown

Sizes: **S** ≤ 0.5 agent-day · **M** 1–2 · **L** 3–5. "Agent-day" = one AI agent with a
working build/test loop in the container, including verification.

> **Execution source of truth:** `docs/planning/windows-parity-tasks.md` — checkbox list, one
> block per task, with agent-day *and* human-day estimates, dependencies, verification
> commands and evidence rules. This section stays the narrative view.

**Working rules** (apply to every wave):

1. **Test first.** No task in Waves 0–4 lands without either a test that fails before
   and passes after, or a recorded characterization artefact (render hash, pack
   transcript, collision output) when a unit test is not feasible.
2. **Measure, don't assume.** Every task records its before/after command and output in
   its PR description (the Appendix A commands are the canonical probes).
3. **Pure moves only** in Wave B. No behaviour, naming, or formatting changes in the
   same commit as a file move.
4. `ctest` must be green on Linux before and after every task; from T3.2 onward also
   under Wine for the Windows preset.

### Wave A — Test baseline (executes before anything else)

Goal: pin today's behaviour so that Waves B, 0–4 are provably non-regressive.
Today's coverage is ~3,900 test lines over 286k source lines (**1.4%**), 22 CTest cases,
and **no committed fixtures**.

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **TA.1** | **Harness + CI baseline.** Standardise the shared `tests/support/TestAssert.h` (D15), make `ctest` runnable locally and in the image, publish a coverage report (`llvm-cov`/`gcov`). | all, devkit | S | D15 | 22/22 green; coverage report for every package |
| **TA.2** | **Pure-logic characterization.** CRC32, TEA, LZO round-trip, `FileBase`/`MappedFile`, timer, locale tables, matrix/ray/OBB (`GrpMath`, `GrpDetector`), DXT codecs. | EterBase, EterLocale, SphereLib, EterImageLib, EterLib | M | TA.1 | Each module has invariant tests; no I/O or GPU needed |
| **TA.3** | **Binary formats + fixtures + fuzzing.** Pack (`EIX`/`EPK`/zip), `.gr2` reader, `treecache` reader, network packet serialisation. Commit a small synthetic fixture generator; add libFuzzer targets. | EterPack, EterGrnLib, SpeedTreeLib, UserInterface | **L** | TA.1 | Round-trip + malformed-input tests; fuzz targets build and run 60s clean |
| **TA.4** | **Headless renderer goldens.** Render scripted scenes offscreen (llvmpipe/OSMesa) and store PNG hashes; add the diff tool used later by T3.2/T5.4. Uses `glReadPixels` directly; `Readback()` in T1.7 later formalises it. | EterBase, EterLib, devkit | **L** | TA.1 | ≥10 scenes pinned; diff tool reports per-scene similarity |
| **TA.5** | **Headless audio / effect / model.** miniaudio `ma_backend_null`, deterministic effect updates, skinning/animation math against reference values. | MilesLib, EffectLib, EterGrnLib | M | TA.1 | Tests run with no sound device and no GPU |
| **TA.6** | **Python binding smoke tests.** Boot the embedded interpreter headless, import every module, snapshot the exposed API surface. | ScriptLib, EterPythonLib, UserInterface | M | TA.1 | Interpreter boots in CI; API snapshot committed |
| **TA.7** | **Coverage ratchet.** Record per-module baselines, fail CI on regression. No absolute target. | devkit | S | TA.2 | Ratchet enforced |
| **TA.8** | **Pre-refactor snapshots.** Freeze the artefacts the refactor must preserve: render hashes, pack transcripts, model/collision outputs, API surface. | all | S | TA.2–TA.6 | `golden/` committed; every later wave diffs against it |

**Minimum baseline** (protects this refactor): TA.1–TA.4 + TA.8. The rest is the tail that
raises coverage — valuable, but not a gate for the parity work. TA.6 is strongly
recommended before T2.4 (Python on Windows), where it is the only safety net.

### Wave B — Structural consolidation into Neoeter (optional, recommended)

Pure-move migration per §4.5. Can run in parallel with T0.1 and does not extend the
critical path.

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **TB.1** | Merge engine layers L0–L3 into `neoeter` with history preserved (`filter-repo`); move-only commit. | all | M | TA.8, D14 | Same targets, same 22 CTest cases, same golden hashes |
| **TB.2** | Create `neoeter-python` (scriptlib + eterpythonlib) and `client` (gamelib + userinterface); move-only commit. | all | M | TB.1 | Same golden hashes; target graph unchanged |
| **TB.3** | Devkit rewire: flat `<Neoeter/…>`/`<Client/…>` include roots, 3-repo `sources.map`/`fetch-sources.sh`, golden/build/CI path updates. | devkit | M | TB.1, TB.2 | `fetch-sources.sh` populates `src/` and the build is green |
| **TB.4** | Archive the 16 `pkg_*` repositories read-only, tag `final`, update org docs and CI. | org | S | TB.3 | New repos are the only writable source of truth |

### Wave 0 — Foundation (serial)

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **T0.1** | **Toolchain spike.** Cross-configure all 16 packages with `i686-w64-mingw32-cmake` and `OPENMT2_RENDERER=GL`, collect a per-package compile-error inventory. Read-only: no source changes. | devkit | M | D8 | A ranked blocker list replaces the assumptions in this document |
| **T0.2** | **Build harness.** `cmake/toolchain-i686-windows-gnu.cmake`, `CMakePresets.json`, `windows` subcommand in `docker/entrypoint.sh`, `scripts/build-windows.sh`, `dist/` assembly. | devkit | M | D7, D8 | `docker run … windows` configures and fails only on missing deps |
| **T0.3** | **Data-width audit.** Find `long`, `size_t`, pointer-cast and struct-layout assumptions in pack/mesh/treecache readers; decide 32 vs 64-bit (`D10`). | all | M | D10 | Documented audit + list of required `static_assert`s |

### Wave 1 — Platform unification

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **T1.1** | Replace `__LINUX__` with `OPENMT2_PLATFORM_*` / `OPENMT2_RENDERER_GL` / `OPENMT2_SDL_WINDOW` across 39 files. Mechanical, behaviour-preserving. | all | M | T0.2 | No new `__LINUX__`; Linux output unchanged |
| **T1.2** | Window/event loop: `MSWindow.cpp`, `MSApplication.cpp`, `GrpScreen.cpp` use SDL2 on both targets; delete `CreateWindow`/`WndProc` path. | EterLib | M | T1.1, D2 | No `CreateWindowEx` in tree; Windows window opens under Wine |
| **T1.3** | Input: `Input.cpp` SDL2 on both; delete `DirectInput8Create`; audit DIK↔SDL scancode coverage (wheel, buttons, focus loss). | EterLib | M | T1.1, D2 | No `dinput.h` outside legacy headers |
| **T1.4** | GL loader: Windows `opengl32.dll` exports only GL 1.1; add runtime proc loading (SDL_GL_GetProcAddress or vendored glad) for `glActiveTexture`, `glGenFramebuffers`, `glCompressedTexImage2D`, `glClipControl`, … | EterBase | M | T1.2 | Renderer initialises on Windows; no unresolved `gl*` |
| **T1.5** | Enable `Direct3DDevice9Compat.cpp` on Windows; drop `<d3dx9.h>`/`<dinput.h>` from `DirectXMathCompat.h:23`; link `opengl32`. | EterBase | S–M | T1.4, T1.7, D1 | Windows links the GL renderer without the DirectX SDK |
| **T1.6** | IME/text input: implement on SDL text events or document the limitation. `msctf.h`/`Dimm.h` become Windows-legacy-only. | EterLib | M | T1.2, D6 | One implementation for both targets |
| **T1.7** | **Renderer seam skeleton (§4.4).** Introduce `IRenderBackend`, `RenderState`, `RenderHandle`, `RenderCaps`, `DrawCall`; move the 240 GL calls / 58 symbols out of `Direct3DDevice9Compat.cpp` into `eterbase/src/backends/gl/`. Pure pass-through: no new features, no Vulkan code, output unchanged. | EterBase | M | T1.4, D11 | `grep -rn "gl[A-Z]" eterbase/src` only matches `backends/gl/**`; Linux screenshots byte-identical |
| **T1.8** | **Fixed-function feature matrix.** Enumerate the 68 `D3DRS_*`, 25 `D3DTSS_*`, transform/light/material/FVF combinations the app actually uses; record it as the backend contract. Record the shader no-op (D13). | all | S | T1.3, D13 | Matrix checked in; T5.2 uses it as its test plan |

### Wave 2 — Dependency convergence

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **T2.1** | Remove DevIL: `MarkImage.cpp`, `MarkManager.cpp:442`, `GuildMarkUploader.h`, `PythonApplicationModule.cpp:337` → stb. | UserInterface | M | D4 | `IL` gone from every CMakeLists and include |
| **T2.2** | libjpeg audit: keep or replace (D5); update CMake accordingly. | EterLib | S | T2.1 | Documented decision + build green |
| **T2.3** | Cross-build Windows deps (SDL2, zlib, lzo2, libzip, optional jpeg) via ExternalProject/vcpkg overlay; pinned; baked into the image. | devkit | M | T0.2 | Toolchain file resolves everything without host libs |
| **T2.4** | Python 2.7 for Windows: vendor PSF `python27.dll` + `dlltool` import lib (or cross-build); wire into CMake; ship in `dist/`. | EterPythonLib, devkit | **L** | D3 | `metin2client.exe` boots the interpreter and loads the `.pyc` set |
| **T2.5** | CMake hygiene: remove unconditional `dl`/`pthread` (`userinterface:101-102`, `mileslib:101`, `scriptlib:99`, `eterpythonlib:100`), make `eterbase:35` `OpenGL::GL` platform-aware. | all | S | T0.2 | No POSIX libs linked on Windows |

### Wave 3 — Parity and packaging

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **T3.1** | Windows packaging: `dist/` with `.exe`, `SDL2.dll`, `python27.dll`, assets, `treecache/`, pack archives — mirroring `build.sh`. | devkit | M | T2.3, T2.4 | Trees differ only by binary + runtime DLLs |
| **T3.2** | Automated smoke test: Wine + Xvfb boot to login screen in CI; screenshot comparison with the Linux run. | devkit | M | T3.1 | CI fails on crash/black screen on either target |
| **T3.3** | Parity audit: input mapping, window modes, audio devices, path/case handling, locale/codepage, IME. | all | M | T3.2, D9 | Pass/fail checklist per item |

### Wave 4 — Removal

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **T4.1** | Delete legacy surface: pragma block `UserInterface.cpp:41-58`, `StdAfx.h:23-40`, `miles/MSS.H`, `directxsdk`, `extern/` expectations, `_fltused`/`NvOptimus` exports. | all | S | T1.5, T2.1 | `grep -r "mss32\|SpeedTreeRT.lib\|directxsdk\|dinput"` is empty |
| **T4.2** | CI + docs: two-target matrix, artefacts, rewrite README "platform parity" section, retire `build.bat` path. | devkit | S | T3.1 | Green pipeline, docs describe one pipeline |

### Wave 5 — Renderer seam, deferred (not scheduled; foundation only)

Listed so the seam decisions are traceable and a future Vulkan effort has a scoped
starting point. **Not part of the estimate in §8.**

| ID | Task | Repo | Size | Deps | Done when |
|---|---|---|---|---|---|
| **T5.1** | **Vulkan backend spike.** Swapchain + clear + one textured quad behind `IRenderBackend`, selected with `OPENMT2_RENDERER=vulkan`. Proves the seam is real; throws the spike away afterwards. | EterBase | M | T1.7 | Quad renders; GL build untouched |
| **T5.2** | **Program synthesis + shader translation.** Fixed-function → GLSL/SPIR-V generator (uber-shader keyed by `RenderState`) and D3D9 bytecode → SPIR-V (evaluate `vkd3d-shader`). Also closes the GL-side shader no-op (D13). | EterLib, EterBase | **L** | T1.8, T5.1 | Feature matrix and all shader effects render on both backends |
| **T5.3** | **Full Vulkan backend.** PSO cache, descriptor sets, frames-in-flight, deferred destruction, DXT upload, render targets, swapchain rebuild. | EterBase | **XL** (out of scope for now) | T5.2 | Feature matrix passes on Vulkan |
| **T5.4** | **Cross-backend conformance harness.** Offscreen render of scripted scenes through `Readback()`, image diff GL vs Vulkan (and Linux vs Windows). | devkit | M | T3.2 | CI reports a per-scene similarity score |

---

## 7. Sequencing and parallelisation

Critical path: **TA.1 → TA.2 → TA.8 → TB.1 → TB.2 → TB.3 → T0.2 → T1.1 → T1.2 → T1.4 → T1.7 → T1.5 → T3.1 → T3.2**

```
Wave A ─┬─ TA.1 ─┬─ TA.2 ─┬─ TA.7
        │        ├─ TA.3 ─┤
        │        ├─ TA.4 ─┼─ TA.8 ─┐
        │        ├─ TA.5 ─┤        │
        │        └─ TA.6 ─┘        │
        ▼                          ▼
Wave B ───────────── TB.1 ── TB.2 ── TB.3 ── TB.4
                                      │
T0.1 ─┬─ T0.2 ─┬─ T1.1 ─┬─ T1.2 ── T1.4 ── T1.7 ── T1.5 ─┐
      │        │        ├─ T1.3 ────────────────────┬─────┤
      │        │        ├─ T1.6                  T1.8     ├─ T3.1 ─ T3.2 ─ T3.3 ─ T4.2
      │        ├─ T0.3  └─ T2.1 ─ T2.2              │     │
      │        ├─ T2.3                                │     │
      │        └─ T2.4 (start early, L) ──────────────┴─────┘
      └─ (informs T1.*)
```

Parallelisable: `T1.2`/`T1.3`/`T1.6`/`T2.1`/`T2.3` are independent once `T1.1` lands.
`T2.4` (Python) should start immediately after `T0.1` because it is the only task
that can move the ship date. `T1.7` depends on `T1.4` only for the loader symbol table,
so it can be drafted while `T1.2`/`T1.3` are still in flight.

`T0.1` is read-only and can run during Wave A/B; if Wave B is dropped, `T0.2` starts
right after `T0.1` and the critical path shortens by roughly one day. Wave 5 sits
outside the graph; only the *seam* (`T1.7`, `T1.8`) is on the critical path, and
postponing it is what turns a later Vulkan effort from a seam refactor into a renderer
rewrite.

---

## 8. Estimate

| Wave | Agent-days |
|---|---|
| Wave A — test baseline (minimum: TA.1–TA.4, TA.8) | 9–12 |
| Wave A — tail (TA.5–TA.7) | +5–7 |
| Wave B — consolidation (optional, off critical path) | 3–6 |
| Wave 0 | 2–3 |
| Wave 1 | 8–12 (includes the seam, T1.7 + T1.8) |
| Wave 2 | 5–8 (Python alone 2–4, high variance) |
| Wave 3 | 4–5 |
| Wave 4 | 1–1.5 |
| **Total (minimum baseline + Wave B)** | **32–47** |
| **Total (full baseline + Wave B)** | **37–54** |

Critical path ≈ 24–30 days. With three agents ≈ **4 calendar weeks**. Add 30–50%
contingency; historical cross-platform ports concentrate surprises in the dependency
build, not the code.

Why the test wave is this large: 286k lines with 1.4% test coverage cannot be covered
by unit tests alone. The plan targets the *code the refactor touches* — platform layer,
pack/IO, model readers, renderer, bindings — and uses golden masters for the rest.
Per-layer realistic targets: platform/IO/model **≥60%** line coverage, renderer **≥40%**
(mostly via goldens), GameLib **≥30%**, UserInterface **≥15%** (packet parsing only).

**Cost of postponing the seam:** T1.7 + T1.8 cost **2–3 agent-days now**. Retrofitting
the same boundary after the Windows path is live, with new `gl*` calls spread through
`Grp*` and effect code, is estimated at **6–10 agent-days** and cannot be validated by
"Linux output unchanged" anymore.

Other useful comparisons:
- Wave 5 (real Vulkan backend, T5.1–T5.3) is **~10–20 agent-days** on top, dominated by
  T5.2 (program synthesis) and T5.3 (PSO cache / sync), and it depends on the seam.
- Adopting a portable abstraction (D11-b) instead of the custom seam adds a third-party
  dependency and an unquantified façade rewrite; not estimated here.
- Dropping Wave B saves 3–6 days but costs roughly **1–2 days per cross-cutting task**
  in Waves 1–4 (16 repos instead of 3), so it pays for itself on this plan alone.

---

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Python 2.7 for Win32** | Blocks the executable | Vendor the PSF DLL first (hours), attempt a source cross-build only if a from-source policy is required |
| **Hidden MSVC-isms** in the 82 `_WIN32` files | Extra tasks appear in Wave 1 | T0.1 measures this before committing to the plan |
| **GL loader / context version** on real Windows drivers | Renderer may need GL 3.0+ guarantees | Request the context explicitly through SDL; document the minimum; test on a real GPU, not only Wine/llvmpipe |
| **32/64-bit data layout** (D10) | Silent corruption in pack/model loading | T0.3 audit + `static_assert` on all on-disk structs |
| **Asset licensing** | Legal, not technical | The clean-room engines do not change the licence of `.spt` data, textures, or models; track separately |
| **IME parity** | CJK users cannot type on one target (already true on Linux) | T1.6, can follow parity |
| **`bin/` legacy DLLs resurface** | Proprietary binaries shipped | Keep the `*.dll` exclusion and add a CI check on `dist/` |
| **Shaders are already a no-op on the GL path** | Visual parity with native D3D9 is approximate today; Vulkan is impossible without programs | D13 + T1.8 make it measurable; T5.2 closes it |
| **Seam creep** (T1.7 becomes a renderer rewrite) | Blows the Wave 1 budget | Time-box: pass-through only, no new features, no Vulkan code in T1.7; R1–R8 are the acceptance criteria |
| **GL leakage** (new `gl*` calls above the backend) | The seam rots within weeks | CI check: `grep -rn "gl[A-Z]" eterbase/src` must only match `backends/gl/**` |
| **Feature-matrix drift** (new app state silently unsupported) | Backend diverges invisibly | T1.8 matrix is generated from the code and asserted by T5.4 |
| **Goldens fossilise bugs** | Characterization tests pin current defects as "correct" | Review each golden when created; convert to intent-based unit tests where cheap; goldens are guards, not specifications |
| **Golden-image flakiness** | CI red for driver differences | Pin llvmpipe/OSMesa and container versions; perceptual diff with tolerance; hash only inside the pinned image |
| **Fixture licensing** | Committing game assets (`.gr2`, `.spt`, packs) to the repo | Generate synthetic fixtures in code (TA.3); never commit assets |
| **Test-effort creep** (TA.5–TA.7 never finish) | Blocks the refactor on coverage vanity | Minimum baseline (TA.1–TA.4, TA.8) is the gate; the tail is a ratchet, not a blocker |
| **Big-bang merge loses history or breaks CI** | Hard to bisect, hard to revert | `filter-repo` per repo, move-only commit, tags, dual-publish period, golden-hash verification |
| **Three CI pipelines instead of one** | Maintenance cost | Reusable workflow + single matrix definition shared by the three repos |

---

## 10. Out of scope

- Python 3 migration, script API redesign.
- Asset pipeline / texture format changes.
- Server build.
- Rendering-feature parity beyond what `Direct3DDevice9Compat` already implements.
  Shader effects are no-ops on the GL path today (D13) and are handled in T5.2, not here.
- **Any actual Vulkan/other backend implementation.** Wave 5 is scoped, sized and left
  unscheduled; only the seam (§4.4) is in scope.
- **Code rewrites during the structural merge.** Wave B moves files; renaming,
  reformatting or "fixing while moving" is forbidden.
- **100% coverage, UI visual testing, i18n testing.** The test baseline targets the code
  this refactor touches.
- Packaging/signing/installer for end users.

---

## 11. Decision log

| Date | ID | Decision | Rationale |
|---|---|---|---|
| 2026-10-30 | — | Plan opened, audit recorded in §3 | Baseline for iteration |
| 2026-10-30 | — | v0.2: renderer seam added as a socle (§4.4, T1.7–T1.8, Wave 5); D11–D13 opened | Keep a Vulkan backend possible without an app rewrite |
| 2026-10-30 | — | v0.3: test baseline (Wave A) and repository consolidation (Wave B, §4.5) added; D14–D16 opened | Tests make the refactor provable; 3 repos make it affordable |
| 2026-10-30 | D1 | accepted (a) GL compat everywhere | parity goal; removes the DirectX SDK from the graph |
| 2026-10-30 | D2 | accepted (a) SDL2 everywhere | one window/input implementation |
| 2026-10-30 | D3 | accepted (a) vendor PSF python27.dll + dlltool import lib | fastest; licence-clean; no CPython fork |
| 2026-10-30 | D4 | accepted (a) replace DevIL with stb_image/stb_image_write | removes an unmaintained dependency |
| 2026-10-30 | D5 | accepted (a) keep libjpeg for now | pending the T2.2 audit |
| 2026-10-31 | D5 | revised to (b) replace libjpeg with `stb_image_write` | T2.2 audit: one writer call site, no progressive need; drops a Windows cross-build |
| 2026-10-30 | D6 | accepted (a) SDL2 text input on both targets | may ship after parity |
| 2026-10-30 | D7 | accepted (a) build logic in the devkit | single pipeline, per-package CMake fixes as needed |
| 2026-10-30 | D8 | accepted (a) MinGW-w64 | only option that removes every MSVC-produced binary |
| 2026-10-30 | D9 | accepted (a) normalise paths in the VFS | otherwise identical asset trees diverge |
| 2026-10-30 | D10 | accepted (a) 64-bit on both targets | GrannyCompat is 64-bit safe; data-width audit in T0.3 |
| 2026-10-30 | D11 | accepted (a) custom IRenderBackend under the D3D9 facade | no new dependency; the facade already exists |
| 2026-10-30 | D12 | accepted (c) synthesise programs and translate D3D9 bytecode | covers fixed-function and the real shader effects |
| 2026-10-30 | D13 | accepted (b) log/count ignored shaders now | makes the existing limitation measurable |
| 2026-10-30 | D14 | accepted (b) three-layer split: neoeter / neoeter-python / client | follows the dependency graph |
| 2026-10-30 | D15 | accepted (a) hand-rolled TEST_ASSERT + shared tests/support header | zero new dependency |
| 2026-10-30 | D16 | accepted (a) tests, then consolidation, then parity | the baseline makes later steps provable |

---

## Appendix A — audit commands

Re-runnable against a fresh clone of every `pkg_*`:

```bash
# platform split
grep -rl "__LINUX__" --include=*.cpp --include=*.h --include=*.c . | wc -l   # 39
grep -rl "_WIN32"    --include=*.cpp --include=*.h --include=*.c . | wc -l   # 82

# proprietary remnants
grep -rn "pragma comment(lib" --include=*.h --include=*.cpp .
grep -rn "mss32\|SpeedTreeRT.lib\|directxsdk\|granny2\|#import " --include=*.h --include=*.cpp .

# platform-layer files
grep -rln "SDL_" --include=*.cpp --include=*.h .
grep -rln "IDirect3D\|D3DPRESENT\|DirectInput8Create" --include=*.cpp .

# dependency calls
grep -rn "\bdl\b\|\bpthread\b" --include=CMakeLists.txt .

# renderer seam evidence (§4.4)
grep -o "\bgl[A-Z][A-Za-z0-9_]*" eterbase/src/Direct3DDevice9Compat.cpp | wc -l        # 240 sites
grep -o "\bgl[A-Z][A-Za-z0-9_]*" eterbase/src/Direct3DDevice9Compat.cpp | sort -u | wc -l  # 58 symbols
grep -rn "CreateVertexShader\|D3DXAssembleShaderFromFile" eterlib/include/Platform/DirectXMathCompat.h
grep -rho "D3DRS_[A-Z0-9_]*"  --include=*.cpp --include=*.h . | sort -u | wc -l         # 68
grep -rho "D3DTSS_[A-Z0-9_]*" --include=*.cpp --include=*.h . | sort -u | wc -l         # 25

# test surface (Wave A)
find . -path '*/tests/*' -name '*.cpp' | wc -l                        # 22 files
find . -path '*/tests/*' -name '*.cpp' | xargs cat | wc -l            # ~3,870 lines
grep -rn "add_test" --include=CMakeLists.txt . | wc -l                # 16 (eterbase registers 7 in a loop)

# dependency layering (for §4.5)
for d in */; do echo "## $d"; awk '/target_link_libraries/{f=1;next} f&&/\)/{f=0} f' "$d/CMakeLists.txt"; done
```

## Appendix B — evidence index

| Topic | Location |
|---|---|
| GL renderer, Linux-gated | `eterbase/src/Direct3DDevice9Compat.cpp:11` … `#endif // __LINUX__` |
| D3DX/DInput include switch | `eterlib/include/Platform/DirectXMathCompat.h:23` |
| Legacy link pragmas | `userinterface/src/UserInterface.cpp:41-58` |
| Legacy platform headers | `eterlib/include/EterLib/StdAfx.h:23-40` |
| SDL window path | `eterlib/src/MSWindow.cpp:94-128`, `MSApplication.cpp:4-32` |
| DirectInput path | `eterlib/src/Input.cpp:33` |
| IME parity gap | `eterlib/src/IME.cpp:2211-2214`, `:2308-2313` |
| Granny replacement | `etergrnlib/include/EterGrnLib/GrannyCompat.h:715` |
| SpeedTree replacement | `speedtreelib/src/SpeedTreeRTCompat.cpp:325`, `:920` |
| miniaudio audio | `mileslib/CMakeLists.txt:94-104` |
| Linux-only dep assumptions | `eterbase/CMakeLists.txt:34-35`, `userinterface/CMakeLists.txt:100-102` |
| DevIL call sites | `userinterface/src/UserInterface.cpp:387`, `MarkManager.cpp:442`, `MarkImage.cpp:4` |
| GL call concentration | `eterbase/src/Direct3DDevice9Compat.cpp` — 240 call sites, 58 distinct `gl*` symbols |
| D3D9 interfaces the app uses | `eterlib/include/Platform/DirectXMathCompat.h:1618-2200` (`IDirect3DTexture9`, `…Buffer9`, `…Shader9`, `IDirect3DSurface9`, `IDirect3D9`, `IDirect3DDevice9`) |
| Shaders silently ignored on GL | `eterlib/include/Platform/DirectXMathCompat.h:1898-1912` (dummy shader objects), `:2162-2168` (empty assembled buffer) |
| Shader creation sites | `eterlib/src/GrpVertexShader.cpp:39`, `eterlib/src/GrpPixelShader.cpp:37` |
| Fixed-function surface size | 68 `D3DRS_*`, 25 `D3DTSS_*`, 57 `SetTransform`, 501 `SetTextureStageState`, 53 `SetFVF` |
| Present / resize path | `eterlib/src/GrpScreen.cpp:759-790` (`SDL_GL_SwapWindow`) |
| Test surface today | 22 CTest cases across 16 packages, ~3,870 lines, no committed fixtures |
| Dependency layers | §4.5, extracted from every `CMakeLists.txt` `target_link_libraries` |
| Web-browser stub | `cwebbrowser/src/CWebBrowser.cpp` (72 lines, no-op) |
| Legacy Windows tree | asset repo `extern/`, `Metin2Client.sln` |
