# Windows / Linux parity — task breakdown (agent execution sheet)

> Companion to `docs/planning/windows-parity.md` (v0.3). This file is the **execution source of
> truth**: task order, state, evidence and estimates.
>
> - `agent` = agent-days (one AI agent, container build/test loop included, verification
>   included).
> - `human` = working days for **one senior engineer** already familiar with the codebase.
>   Conversion used: **bulk ×3 · standard ×2.5 · design ×2** (design tasks resist
>   parallelisation, bulk tasks are where agents gain the most).
> - Both are point estimates with a range. Assume ±50% before T0.1 has run.
> - Rollups may differ by ±1 day from §8 of the plan (which rounds).

> Each task is mirrored as a GitHub issue in `open-mt2/devkit`, with one milestone
> per wave (`Wave A` … `Wave 5`); PRs close them with `Closes #<n>`. Issue #1 holds
> the D1–D16 decisions.

---

## 0. How to work this file

1. **Read `1. Decisions` first.** A task whose `deps` include an unchecked decision must
   not start.
2. **Claim** a task: change `- [ ]` to `- [~]` and add `  - owner: <agent-id>`.
3. **Close** a task: change to `- [x]`, add `  - evidence: evidence/<ID>.md`, and link the
   commit/PR.
4. **Block**: `- [!]` + `  - blocked: <reason>`.
5. **One task per commit series.** Branch `task/<ID>-<slug>`, commit prefix `[<ID>]`.
6. **Deps are hard gates** unless explicitly marked `soft`.
7. Never reformat, rename or "fix while moving" in a structural task (Wave B).
8. Run the task's `verify` command before declaring done, and paste the output into its
   evidence file.

### Evidence file format

Create `evidence/<ID>.md` with exactly:

```markdown
# <ID> — <title>
- agent: <id>
- date: YYYY-MM-DD
- command: <verify command>
- before: <output / hash / screenshot reference>
- after: <output / hash / screenshot reference>
- notes: <files touched, deviations, follow-ups>
```

### Handoff report (what an agent returns when a task closes)

```
<ID> done.
changed: <paths>
tests: <n> added, <n> updated — `ctest` <pass/total>
evidence: evidence/<ID>.md
follow-ups: <new tasks or "none">
```

---

## 1. Status

- [x] Plan v0.3 written (`docs/planning/windows-parity.md`)
- [x] Decisions settled (see §2)
- [~] Wave A complete
- [ ] Wave B complete (optional)
- [ ] Waves 0–4 complete
- [ ] Wave 5 scoped only (not executed)

Progress: **6 / 37 tasks**, **16 / 16 decisions**.

---

## 2. Decisions (prerequisites)

Settle these before starting the tasks they block. Tick and record in the plan's §11.

- [x] **D1 — Renderer policy**
  - options: (a) GL compat everywhere · (b) dual backend, D3D9 on Windows
  - recommended: **a**
  - blocks: T1.4, T1.5, T4.1
- [x] **D2 — Window/input policy**
  - options: (a) SDL2 everywhere · (b) keep Win32 + DirectInput on Windows
  - recommended: **a**
  - blocks: T1.2, T1.3
- [x] **D3 — Python 2.7 on Windows**
  - options: (a) vendor PSF `python27.dll` + `dlltool` import lib · (b) cross-build CPython 2.7 · (c) per-platform interpreters
  - recommended: **a**
  - blocks: T2.4
- [x] **D4 — DevIL**
  - options: (a) replace with stb_image/stb_image_write · (b) keep
  - recommended: **a**
  - blocks: T2.1
- [x] **D5 — libjpeg**
  - options: (a) keep · (b) replace with stb
  - recommended: **a**, pending T2.2 audit
  - blocks: T2.2
- [x] **D6 — IME / CJK input**
  - options: (a) SDL2 text input on both · (b) no-op on Linux + IMM on Windows
  - recommended: **a**, may ship after parity
  - blocks: T1.6
- [x] **D7 — Build logic location**
  - options: (a) devkit only · (b) presets in every `pkg_*`
  - recommended: **a**
  - blocks: T0.2
- [x] **D8 — Cross toolchain**
  - options: (a) MinGW-w64 · (b) clang-cl + xwin + MSVC-built `extern/`
  - recommended: **a**
  - blocks: T0.1, T2.3
- [x] **D9 — Path / case handling**
  - options: (a) normalise in the VFS · (b) per-OS behaviour
  - recommended: **a**
  - blocks: T3.3
- [x] **D10 — Bitness**
  - options: (a) 64-bit both · (b) 32-bit both · (c) as-is
  - recommended: **a**
  - blocks: T0.3, Wave 2
- [x] **D11 — Renderer abstraction style**
  - options: (a) custom `IRenderBackend` under the D3D9 façade · (b) bgfx/sokol/Diligent/wgpu · (c) D3D9→Vulkan translator
  - recommended: **a**
  - blocks: T1.7, Wave 5
- [x] **D12 — Shader strategy**
  - options: (a) synthesise from fixed-function state · (b) D3D9 bytecode → SPIR-V · (c) both
  - recommended: **c**
  - blocks: T5.2
- [x] **D13 — Current shader no-op**
  - options: (a) ignore · (b) log/count and record parity delta · (c) implement on GL now
  - recommended: **b** now, (c) inside T5.2
  - blocks: T1.8
- [x] **D14 — Repository topology**
  - options: (a) single monorepo · (b) 3-layer split · (c) 2 repos · (d) 16 + superbuild
  - recommended: **b** (§4.5 of the plan)
  - blocks: TB.1
- [x] **D15 — Test framework**
  - options: (a) hand-rolled `TEST_ASSERT` + shared header · (b) doctest/Catch2 · (c) GoogleTest
  - recommended: **a**
  - blocks: TA.1
- [x] **D16 — Change ordering**
  - options: (a) tests → merge → parity · (b) parity first · (c) another order
  - recommended: **a**
  - blocks: all waves

---

## 3. Execution order (DAG)

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

Critical path: `TA.1 → TA.2 → TA.8 → TB.1 → TB.2 → TB.3 → T0.2 → T1.1 → T1.2 → T1.4 → T1.7 → T1.5 → T3.1 → T3.2`

Wave 5 is deferred and not on the path. If Wave B is dropped, `T0.2` follows `T0.1`
directly.

---

## 4. Wave A — Test baseline (executes first)

> Gate: TA.1–TA.4 + TA.8. TA.5–TA.7 are the coverage tail and must not block Wave 0.

- [x] **TA.1 — Test harness + CI baseline**
  - wave: A · repo: all, devkit · profile: standard
  - owner: agent-01
  - evidence: evidence/TA.1.md
  - agent: 0.5 d (0.5–1) · human: 1.5 d (1–2)
  - deps: D15
  - scope: shared `tests/support/TestAssert.h`; make `ctest` runnable locally and in the image; coverage report (`llvm-cov`/`gcov`) per package.
  - done: 22/22 existing tests green; coverage report produced for all 16 packages.
  - verify: `ctest --output-on-failure` and `scripts/coverage.sh`
  - risk: none

- [x] **TA.2 — Pure-logic characterization tests**
  - wave: A · repo: EterBase, EterLocale, SphereLib, EterImageLib, EterLib · profile: standard
  - owner: agent-01
  - evidence: evidence/TA.2.md
  - agent: 2 d (1.5–3) · human: 5 d (4–7)
  - deps: TA.1
  - scope: CRC32, TEA, LZO round-trip, `FileBase`/`MappedFile`, timer, locale tables, `GrpMath`, ray/OBB (`GrpDetector`), DXT codecs.
  - done: each listed module has invariant tests; no GPU or device needed.
  - verify: `ctest -R "crc|tea|lzo|file|locale|math|detector|dxt"`
  - risk: low

- [x] **TA.3 — Binary formats, fixtures, fuzzing**
  - wave: A · repo: EterPack, EterGrnLib, SpeedTreeLib, UserInterface · profile: bulk
  - owner: agent-01
  - evidence: evidence/TA.3.md
  - agent: 3.5 d (3–4) · human: 10 d (8–12)
  - deps: TA.1
  - scope: pack (`EIX`/`EPK`/zip), `.gr2` reader, `treecache` reader, network packet (de)serialisation; synthetic fixture generator committed as code; libFuzzer targets.
  - done: round-trip + malformed-input tests; fuzz targets build and survive a 60 s run; **no game assets committed**.
  - verify: `ctest -R "pack|gr2|treecache|packet"` and `scripts/fuzz-smoke.sh`
  - risk: fixture licensing — generate, never copy assets

- [x] **TA.4 — Headless renderer goldens**
  - wave: A · repo: EterBase, EterLib, devkit · profile: standard
  - owner: agent-02
  - evidence: evidence/TA.4.md
  - agent: 3.5 d (3–4) · human: 8.5 d (7–10)
  - deps: TA.1
  - scope: scripted offscreen scenes under llvmpipe/OSMesa; PNG hashes committed; `glReadPixels` based now, `Readback()` formalises it in T1.7; image-diff tool reused by T3.2/T5.4.
  - done: ≥10 scenes pinned; diff tool reports per-scene similarity; runs headless in CI.
  - verify: `ctest -R render` and `scripts/render-diff.sh <a> <b>`
  - risk: golden flakiness — pin container and driver versions, use perceptual tolerance

- [x] **TA.5 — Headless audio / effect / model**
  - wave: A · repo: MilesLib, EffectLib, EterGrnLib · profile: standard
  - owner: agent-03
  - evidence: evidence/TA.5.md
  - agent: 1.5 d (1.5–2) · human: 4 d (3–6)
  - deps: TA.1
  - scope: miniaudio `ma_backend_null`; deterministic effect update; skinning/animation math against reference values.
  - done: tests run with no sound device and no GPU.
  - verify: `ctest -R "miles|effect|grn"`
  - risk: low

- [ ] **TA.6 — Python binding smoke tests**
  - wave: A · repo: ScriptLib, EterPythonLib, UserInterface · profile: standard
  - agent: 1.5 d (1.5–2) · human: 4 d (3–6)
  - deps: TA.1
  - scope: boot the embedded interpreter headless; import every module; snapshot the exposed API surface.
  - done: interpreter boots in CI; API snapshot committed.
  - verify: `ctest -R "python|scriptlib"`
  - risk: highest-value safety net before T2.4

- [ ] **TA.7 — Coverage ratchet**
  - wave: A · repo: devkit · profile: standard
  - agent: 0.5 d · human: 1 d
  - deps: TA.2
  - scope: per-module baselines; CI fails on regression only.
  - done: ratchet enforced in CI.
  - verify: `scripts/coverage.sh --check`
  - risk: do not set absolute targets

- [ ] **TA.8 — Pre-refactor snapshots**
  - wave: A · repo: all · profile: standard
  - agent: 0.5 d (0.5–1) · human: 1.5 d (1–2)
  - deps: TA.2–TA.6
  - scope: freeze render hashes, pack transcripts, model/collision outputs, API surface into `golden/`.
  - done: `golden/` committed; every later wave diffs against it.
  - verify: `scripts/golden-check.sh`
  - risk: snapshots must be taken **before** Wave B

---

## 5. Wave B — Structural consolidation (optional, recommended)

> Pure moves only. Can run in parallel with T0.1. Dropping this wave saves 5 agent-days
> here and costs ~1–2 days per cross-cutting task afterwards.

- [ ] **TB.1 — Merge engine layers L0–L3 into `neoeter`**
  - wave: B · repo: all · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–5)
  - deps: TA.8, D14
  - scope: `git filter-repo --to-subdirectory-filter src/<role>` per repo; move-only commit; `src/{platform,io,image,render,audio,model,terrain,effect}`.
  - done: same targets, same 22 CTest cases, same golden hashes.
  - verify: `scripts/golden-check.sh && ctest --output-on-failure`
  - risk: history loss — tag every old repo `final` before merging

- [ ] **TB.2 — Create `neoeter-python` and `client`**
  - wave: B · repo: all · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–5)
  - deps: TB.1
  - scope: `neoeter-python` = scriptlib + eterpythonlib; `client` = gamelib + userinterface; move-only commit.
  - done: same golden hashes; target graph unchanged.
  - verify: `scripts/golden-check.sh`
  - risk: cross-repo include paths — see TB.3

- [ ] **TB.3 — Compatibility shims + devkit rewire**
  - wave: B · repo: devkit · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–4)
  - deps: TB.1, TB.2
  - scope: keep include roots (`<EterBase/...>`) and target aliases (`EterBase::EterBase` → `Neoeter::Platform`); replace `packages.map` + `fetch-packages.sh` with `fetch-sources.sh` (3 repos).
  - done: `build.sh` and the image work unchanged against the new layout.
  - verify: `docker build -t openmt2/client . && docker run --rm openmt2/client`
  - risk: shim must be temporary and documented

- [ ] **TB.4 — Archive old repositories**
  - wave: B · repo: org · profile: standard
  - agent: 0.5 d · human: 1.5 d (1–2)
  - deps: TB.3
  - scope: tag `final`, archive read-only, update org docs and CI; optionally delete the `cwebbrowser` stub while moving.
  - done: the 3 new repos are the only writable source of truth.
  - verify: `git ls-remote` on old repos returns archived tags
  - risk: downstream users pinning old repos

---

## 6. Wave 0 — Foundation

- [x] **T0.1 — Toolchain spike (read-only)**
  - owner: W-Kanzashi / Codex
  - evidence: evidence/T0.1.md
  - commit: 849322e (implementation; final evidence in this branch)
  - wave: 0 · repo: devkit · profile: design
  - agent: 1 d (1–2) · human: 2.5 d (2–4)
  - deps: D8
  - scope: cross-configure all packages with `i686-w64-mingw32-cmake` and `OPENMT2_RENDERER=GL`; collect a per-package compile-error inventory.
  - done: ranked blocker list replaces the assumptions in the plan.
  - verify: `scripts/spike-windows.sh > evidence/T0.1.log`
  - risk: results may reshape Wave 1 — that is the point

- [ ] **T0.2 — Build harness**
  - wave: 0 · repo: devkit · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–6)
  - deps: D7, D8, TB.3 (soft)
  - scope: `cmake/toolchain-i686-windows-gnu.cmake`, `CMakePresets.json`, `windows` subcommand in `docker/entrypoint.sh`, `scripts/build-windows.sh`, `dist/` assembly.
  - done: `docker run … windows` configures and fails only on missing deps.
  - verify: `docker run --rm openmt2/client windows`
  - risk: preset duplication — one preset file, two targets

- [ ] **T0.3 — Data-width audit**
  - wave: 0 · repo: all · profile: standard
  - agent: 1 d (0.5–1.5) · human: 2.5 d (2–4)
  - deps: D10
  - scope: find `long`, `size_t`, pointer casts and struct-layout assumptions in pack/mesh/treecache readers.
  - done: documented audit + list of required `static_assert`s.
  - verify: `grep -rn "long\b\|size_t" src/*/include` + evidence table
  - risk: silent corruption if skipped

---

## 7. Wave 1 — Platform unification

- [ ] **T1.1 — Replace `__LINUX__` with explicit macros**
  - wave: 1 · repo: all · profile: bulk
  - agent: 1.5 d (1–2) · human: 4.5 d (3–6)
  - deps: T0.2
  - scope: `OPENMT2_PLATFORM_*`, `OPENMT2_RENDERER_GL`, `OPENMT2_SDL_WINDOW` across 39 files; behaviour-preserving.
  - done: no new `__LINUX__`; Linux output unchanged.
  - verify: `grep -rl "__LINUX__" src | wc -l` + golden hashes
  - risk: accidental behaviour change — split into per-package commits

- [ ] **T1.2 — SDL2 window and event loop on both targets**
  - wave: 1 · repo: EterLib · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–5)
  - deps: T1.1, D2
  - scope: `MSWindow.cpp`, `MSApplication.cpp`, `GrpScreen.cpp`; delete `CreateWindow`/`WndProc` path.
  - done: no `CreateWindowEx` in tree; window opens under Wine.
  - verify: `grep -rn "CreateWindowEx" src` + Wine smoke
  - risk: IME/IMC message plumbing

- [ ] **T1.3 — SDL2 input**
  - wave: 1 · repo: EterLib · profile: standard
  - agent: 1 d (1–1.5) · human: 2.5 d (2–4)
  - deps: T1.1, D2
  - scope: `Input.cpp` on SDL2; delete `DirectInput8Create`; audit DIK↔SDL coverage (wheel, buttons, focus loss).
  - done: no `dinput.h` outside legacy headers.
  - verify: `grep -rn "DirectInput8Create" src`
  - risk: scancode gaps on non-US layouts

- [ ] **T1.4 — GL function loader for Windows**
  - wave: 1 · repo: EterBase · profile: standard
  - agent: 1.5 d (1.5–2) · human: 4 d (3–5)
  - deps: T1.2
  - scope: runtime proc loading (`SDL_GL_GetProcAddress` or vendored glad) for `glActiveTexture`, `glGenFramebuffers`, `glCompressedTexImage2D`, `glClipControl`, …; request GL 3.0+.
  - done: renderer initialises on Windows; no unresolved `gl*`.
  - verify: `nm -u dist/metin2client.exe | grep " gl"` is empty
  - risk: GL 1.1-only `opengl32.dll` on real Windows

- [ ] **T1.5 — Enable compat renderer on Windows**
  - wave: 1 · repo: EterBase · profile: standard
  - agent: 0.75 d (0.5–1) · human: 2 d (1.5–3)
  - deps: T1.4, T1.7, D1
  - scope: flip the file-level gate on `Direct3DDevice9Compat.cpp`; drop `<d3dx9.h>`/`<dinput.h>` from `DirectXMathCompat.h:23`; link `opengl32`.
  - done: Windows links the GL renderer without the DirectX SDK.
  - verify: `docker run --rm openmt2/client windows`
  - risk: none after T1.7

- [ ] **T1.6 — IME / text input**
  - wave: 1 · repo: EterLib · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–6)
  - deps: T1.2, D6
  - scope: SDL text events (`SDL_START_TEXTEDITING`/`SDL_TEXTINPUT`) or documented limitation; retire `msctf.h`/`Dimm.h` from the live path.
  - done: one implementation for both targets.
  - verify: `ctest -R ime` + manual CJK check
  - risk: CJK parity is already broken on Linux — scope creep

- [ ] **T1.7 — Renderer seam skeleton**
  - wave: 1 · repo: EterBase · profile: design
  - agent: 2 d (1.5–2.5) · human: 4 d (3–5)
  - deps: T1.4, D11
  - scope: `IRenderBackend`, `RenderState`, `RenderHandle`, `RenderCaps`, `DrawCall`; move the 240 GL calls / 58 symbols into `eterbase/src/backends/gl/`. Pure pass-through, **no Vulkan code**.
  - done: `grep -rn "gl[A-Z]" eterbase/src` matches only `backends/gl/**`; Linux screenshots byte-identical.
  - verify: `scripts/golden-check.sh`
  - risk: time-box — any feature work here is out of scope

- [ ] **T1.8 — Fixed-function feature matrix**
  - wave: 1 · repo: all · profile: standard
  - agent: 0.5 d · human: 1.5 d (1–2)
  - deps: T1.3, D13
  - scope: enumerate the 68 `D3DRS_*`, 25 `D3DTSS_*`, transform/light/material/FVF combinations actually used; record the shader no-op delta.
  - done: matrix checked in; T5.2 uses it as its test plan.
  - verify: `scripts/feature-matrix.sh --check`
  - risk: matrix drift — generate, don't hand-write

---

## 8. Wave 2 — Dependency convergence

- [ ] **T2.1 — Remove DevIL**
  - wave: 2 · repo: UserInterface · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–5)
  - deps: D4
  - scope: `MarkImage.cpp`, `MarkManager.cpp:442`, `GuildMarkUploader.h`, `PythonApplicationModule.cpp:337` → stb_image/stb_image_write (+ DDS encode).
  - done: `IL` gone from every CMakeLists and include.
  - verify: `grep -rn "IL/il.h\|target_link_libraries.*IL" src`
  - risk: DDS/mark encoding parity — golden images cover it

- [ ] **T2.2 — libjpeg audit**
  - wave: 2 · repo: EterLib · profile: standard
  - agent: 0.5 d · human: 1 d
  - deps: D5, T2.1
  - scope: keep or replace; update CMake accordingly.
  - done: documented decision + build green.
  - verify: `docker run --rm openmt2/client`
  - risk: low

- [ ] **T2.3 — Cross-build Windows dependencies**
  - wave: 2 · repo: devkit · profile: standard
  - agent: 2 d (1.5–2.5) · human: 5 d (4–6)
  - deps: T0.2
  - scope: SDL2, zlib, lzo2, libzip (optional jpeg) via ExternalProject/vcpkg overlay; pinned; baked into the image.
  - done: toolchain file resolves everything without host libraries.
  - verify: `find build-windows -name "*.a" | wc -l` + configure log
  - risk: hidden host-lib leakage — check with `objdump -p`

- [ ] **T2.4 — Python 2.7 for Windows**
  - wave: 2 · repo: EterPythonLib, devkit · profile: design
  - agent: 3 d (2–4) · human: 6 d (4–9)
  - deps: D3, TA.6 (recommended)
  - scope: vendor PSF `python27.dll` + `dlltool` import lib (or cross-build); wire into CMake; ship in `dist/`.
  - done: `metin2client.exe` boots the interpreter and loads the `.pyc` set.
  - verify: `wine dist/metin2client.exe --version` + ctest
  - risk: **highest variance task** — start early

- [ ] **T2.5 — CMake platform hygiene**
  - wave: 2 · repo: all · profile: standard
  - agent: 0.5 d · human: 1 d
  - deps: T0.2
  - scope: remove unconditional `dl`/`pthread` (`userinterface:101-102`, `mileslib:101`, `scriptlib:99`, `eterpythonlib:100`); make `eterbase:35` `OpenGL::GL` platform-aware.
  - done: no POSIX libs linked on Windows.
  - verify: `nm -u dist/metin2client.exe | grep -E "dlopen|pthread"` empty
  - risk: low

---

## 9. Wave 3 — Parity and packaging

- [ ] **T3.1 — Windows packaging**
  - wave: 3 · repo: devkit · profile: standard
  - agent: 1.5 d (1–2) · human: 4 d (3–5)
  - deps: T2.3, T2.4
  - scope: `dist/` with `.exe`, `SDL2.dll`, `python27.dll`, assets, `treecache/`, pack archives — mirroring `build.sh`.
  - done: trees differ only by binary + runtime DLLs.
  - verify: `diff -r dist-linux dist-windows` (expected diff limited to binaries)
  - risk: asset drift between targets

- [ ] **T3.2 — Automated smoke test**
  - wave: 3 · repo: devkit · profile: design
  - agent: 2 d (1.5–2.5) · human: 4 d (3–5)
  - deps: T3.1, TA.4
  - scope: Wine + Xvfb boot to login screen; screenshot; compare with the Linux run.
  - done: CI fails on crash/black screen on either target.
  - verify: `scripts/smoke.sh windows && scripts/smoke.sh linux`
  - risk: Wine timing/flakiness — retries + fixed seeds

- [ ] **T3.3 — Parity audit**
  - wave: 3 · repo: all · profile: standard
  - agent: 1 d (1–1.5) · human: 2.5 d (2–4)
  - deps: T3.2, D9
  - scope: input mapping, window modes, audio devices, path/case handling, locale/codepage, IME.
  - done: pass/fail checklist per item.
  - verify: `evidence/T3.3.md` checklist
  - risk: case-sensitivity bugs surface late

---

## 10. Wave 4 — Removal

- [ ] **T4.1 — Delete legacy surface**
  - wave: 4 · repo: all · profile: standard
  - agent: 0.5 d · human: 1 d
  - deps: T1.5, T2.1
  - scope: pragma block `UserInterface.cpp:41-58`, `StdAfx.h:23-40`, `miles/MSS.H`, `directxsdk`, `extern/` expectations, `_fltused`/`NvOptimus` exports.
  - done: `grep -r "mss32\|SpeedTreeRT.lib\|directxsdk\|dinput"` empty.
  - verify: the grep above
  - risk: removing too early breaks the native fallback

- [ ] **T4.2 — CI + docs**
  - wave: 4 · repo: devkit · profile: standard
  - agent: 0.5 d · human: 1.5 d (1–2)
  - deps: T3.1
  - scope: two-target matrix, artefacts, rewrite README "platform parity", retire `build.bat` path.
  - done: green pipeline; docs describe one pipeline.
  - verify: CI green on both presets
  - risk: low

---

## 11. Wave 5 — Renderer seam, deferred (NOT scheduled)

> Excluded from every total. Only start when a Vulkan backend is actually wanted.

- [ ] **T5.1 — Vulkan backend spike**
  - wave: 5 · repo: EterBase · profile: standard
  - agent: 2 d (1.5–3) · human: 4 d (3–6)
  - deps: T1.7
  - scope: swapchain + clear + one textured quad behind `IRenderBackend`, `OPENMT2_RENDERER=vulkan`; throw the spike away afterwards.
  - done: quad renders; GL build untouched.
  - verify: `docker run --rm -e OPENMT2_RENDERER=vulkan …`
  - risk: proves or disproves the seam — cheap on purpose

- [ ] **T5.2 — Program synthesis + shader translation**
  - wave: 5 · repo: EterLib, EterBase · profile: design
  - agent: 5 d (4–6) · human: 10 d (8–14)
  - deps: T1.8, T5.1, D12
  - scope: fixed-function → GLSL/SPIR-V generator (uber-shader keyed by `RenderState`); D3D9 bytecode → SPIR-V (`vkd3d-shader` evaluation); closes the GL shader no-op.
  - done: feature matrix and all shader effects render on both backends.
  - verify: `scripts/render-diff.sh gl vulkan`
  - risk: **largest unknown of the whole programme**

- [ ] **T5.3 — Full Vulkan backend**
  - wave: 5 · repo: EterBase · profile: design
  - agent: 8 d (6–12) · human: 16 d (12–24)
  - deps: T5.2
  - scope: PSO cache, descriptor sets, frames-in-flight, deferred destruction, DXT upload, render targets, swapchain rebuild.
  - done: feature matrix passes on Vulkan.
  - verify: full ctest + render-diff
  - risk: sync bugs are expensive; budget contingency

- [ ] **T5.4 — Cross-backend conformance harness**
  - wave: 5 · repo: devkit · profile: standard
  - agent: 2 d (1.5–2.5) · human: 5 d (4–6)
  - deps: T3.2, TA.4
  - scope: scripted scenes through `Readback()`, image diff GL vs Vulkan and Linux vs Windows.
  - done: CI reports per-scene similarity.
  - verify: `scripts/render-diff.sh`
  - risk: perceptual thresholds need tuning

---

## 12. Rollup

### Wave totals (agent-days / human-days, point estimates)

| Wave | Tasks | Agent | Human |
|---|---|---|---|
| A — test baseline (minimum: TA.1–TA.4, TA.8) | 5 | 10 | 26.5 |
| A — tail (TA.5–TA.7) | 3 | +3.5 | +9 |
| B — consolidation | 4 | 5 | 13.5 |
| 0 — foundation | 3 | 3.5 | 9 |
| 1 — platform unification | 8 | 10.25 | 26.5 |
| 2 — dependency convergence | 5 | 7.5 | 17 |
| 3 — parity and packaging | 3 | 4.5 | 10.5 |
| 4 — removal | 2 | 1 | 2.5 |
| **Total (minimum baseline + B)** | **30** | **41.75** | **105.5** |
| **Total (full baseline + B)** | **33** | **45.25** | **114.5** |
| 5 — Vulkan (deferred, excluded) | 4 | 17 | 35 |

### Calendar view

- **Solo senior engineer**: ~105.5 working days ≈ **21 weeks ≈ 5 months** (minimum
  baseline), ~23 weeks with the full test tail.
- **Two to three engineers in parallel**: **8–11 weeks** (Wave A parallelises well across
  packages; Waves 1–2 parallelise across repos, but T1.7/T1.5 and Wave 5 do not).
- **AI agents (3 in parallel)**: 32–47 agent-days ≈ **3–4 weeks**, dominated by Wave A
  throughput and T2.4 variance.
- Critical path (any staffing): TA.1 → TA.2 → TA.8 → TB.1 → TB.2 → TB.3 → T0.2 → T1.1 →
  T1.2 → T1.4 → T1.7 → T1.5 → T3.1 → T3.2 ≈ **24–30 working days**.

### Where the risk sits

| Task | Why | Contingency |
|---|---|---|
| T2.4 | Cross-building/embedding Python 2.7 for Windows | +50–100% |
| T1.7 | Seam must stay a pass-through | hard time-box, no feature work |
| TA.3 / TA.4 | Fixtures and golden flakiness | +30% |
| T5.2 | Fixed-function → SPIR-V | +100% (deferred anyway) |
