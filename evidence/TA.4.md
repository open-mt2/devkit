# TA.4 — Headless renderer goldens

- agent: agent-02
- date: 2026-10-30
- command: `ctest -R render` and `scripts/render-diff.sh <a> <b>`
- before: 34/34 CTest pass after TA.3. The renderer had smoke coverage only (`EterLib_SmokeTests` constructs objects) and nothing drew a frame. There was no offscreen GL target, no PNG capture, no image-diff tool and no committed render baseline.
- after: 35/35 CTest pass (1/1 with `-R render`). 12 scripted scenes render headless through `CGraphicDevice` + the D3D9 compatibility façade and match their committed goldens at 100% similarity. Two consecutive runs produce byte-identical PNGs. A mutated `depth_test` golden fails the gate (89.58% similarity, exit 1) and `render-diff.sh` reports it as `FAIL`.
- notes: uses the EGL surfaceless platform (no Xvfb); see below for the PR, the pinned environment and follow-ups.

## Slices

| Repository | PR | Result |
|---|---|---|
| `pkg_eterlib` | [#4](https://github.com/open-mt2/pkg_eterlib/pull/4) | `test_render_golden`, 12 goldens + manifest, CI dependencies |
| `devkit` | this PR | `scripts/render-diff.sh`, `libegl-dev`, task sheet, evidence |

## Harness

`tests/render_golden.cpp` starts `CGraphicDevice` exactly like the client
(`InitBackBufferCount` + `Create`), binds an EGL surfaceless FBO
(`EGL_PLATFORM_SURFACELESS_MESA`, RGBA8 + depth24) as the render target, and
then draws each scene with the same API the game uses: `CGraphicBase` camera /
ortho helpers, `CStateManager`, `DrawPrimitiveUP`, D3D9 textures and state.

The frame is read with `glReadPixels`, flipped to top-down and written as PNG
(zlib). Comparison decodes the committed PNG and counts a pixel as matching
when every channel is within 2/255; the scene passes at 99.5% matching pixels.
`--update` rewrites the goldens and is the only supported way to accept a
renderer change.

Scenes (12): `clear`, `ortho_triangle`, `ortho_blend`, `checker_nearest`,
`texture_modulate`, `texture_wrap`, `depth_test`, `perspective_cube`,
`cull_backface`, `fog_linear`, `viewport`, `alpha_test`.

## Pinned environment

| Item | Value |
|---|---|
| Mesa (image) | 22.3.6, llvmpipe / LLVM 15, GL 4.5 compatibility |
| Target | 160×120 RGBA8, depth24, no MSAA, dither off |
| Env | `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe` |

Cross-driver check: the same binary and goldens were run in `ubuntu:24.04`
with Mesa **25.2.8** (llvmpipe / LLVM 20) and produced byte-identical pixels
(all 12 at 100%, `max_delta=0`). The tolerance remains as a safety net for
future changes.

## Commands and output

```
$ ctest --test-dir build -R render --output-on-failure
1/1 Test #23: render_golden ....................   Passed    0.24 sec

100% tests passed, 0 tests failed out of 1
```

```
$ scripts/render-diff.sh src/EterLib/tests/golden/render \
      build/src/EterLib/tests/render-output
scene                    similarity  max_d      mae  status
alpha_test.png              100.00%      0    0.000  PASS
checker_nearest.png         100.00%      0    0.000  PASS
clear.png                   100.00%      0    0.000  PASS
cull_backface.png           100.00%      0    0.000  PASS
depth_test.png              100.00%      0    0.000  PASS
fog_linear.png              100.00%      0    0.000  PASS
ortho_blend.png             100.00%      0    0.000  PASS
ortho_triangle.png          100.00%      0    0.000  PASS
perspective_cube.png        100.00%      0    0.000  PASS
texture_modulate.png        100.00%      0    0.000  PASS
texture_wrap.png            100.00%      0    0.000  PASS
viewport.png                100.00%      0    0.000  PASS

12/12 scenes passed (threshold=99.50%, max delta=2)
```

Negative control (mutated `depth_test` golden):

```
[FAIL] depth_test           similarity= 89.58% max_delta=160 mae= 9.375 pixels=19200
[summary] 11/12 scenes passed (tolerance=2, min similarity=99.50%)   # exit 1
```

Determinism: two consecutive renders produced identical SHA-256 for every
output PNG; `sha256sum -c tests/golden/render/manifest.sha256` passes.

## Notes / follow-ups

- The D3D9 façade currently renders 2D through a screen-ortho replacement in
  `SetupGLState`; the `ortho_triangle` / `viewport` goldens pin that behaviour
  before T1.7 touches it.
- T1.7's `Readback()` should replace the direct `glReadPixels` call; the
  harness is isolated in `support/OffscreenGL.cpp` so only that file changes.
- TA.8 should freeze these hashes into the devkit `golden/` tree; until then
  the goldens live next to the test that owns them.
- `render-diff.sh` is the shared tool for T3.2 (black-screen detection) and
  T5.4 (backend comparison); it accepts files or directories and has a `--json`
  mode.
- The EGL/GLX path is Linux-only; the Windows target will need its own
  offscreen context (or a D3D readback) when T1.5/T1.7 land.
