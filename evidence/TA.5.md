# TA.5 — Headless audio / effect / model

- agent: agent-03
- date: 2026-10-30
- command: `ctest -R "miles|effect|grn"` (plus full `ctest` and `test_miles_headless` negative control)
- before: 35/35 CTest pass after TA.4, but the task's verify filter matched **zero** tests: the package suites were named `MilesLib_SmokeTests`, `EffectLib_SmokeTests` and `EterGrnLib_SmokeTests`, so `ctest -R "miles|effect|grn"` printed `No tests were found!!!`. No test asserted which miniaudio backend was in use; the engine read the host device list and only fell back to null by luck. Particle updates were exercised one step at a time; nothing pinned a fixed-step sequence or seeded randomness. Skinning had a translation-only case and animation had constant-curve blends, but no rotation reference values.
- after: 38/38 CTest pass. `ctest -R "miles|effect|grn"` runs 3/3 (`test_miles_headless`, `test_effect_determinism`, `test_grn_reference`). Audio boots against `ma_backend_null` with `OPENMT2_AUDIO_BACKEND=null` and works without a sound card. Particle physics over a fixed 0.5 s step matches hand-computed positions/velocities, repeated runs are bit-identical, and seeded emission reproduces bit-for-bit. World-pose rotation, two-bone weighted skinning, curve sampling and a keyframed pose all match hand-computed reference values. None of the new tests create a GL context.
- notes: files and follow-ups below. No production behaviour changed except the opt-in audio backend switch.

## Slices

| Repository | PR | Result |
|---|---|---|
| `pkg_mileslib` | [#2](https://github.com/open-mt2/pkg_mileslib/pull/2) | `OPENMT2_AUDIO_BACKEND=null` forces `ma_context` to `ma_backend_null`; `test_miles_headless` |
| `pkg_effectlib` | [#2](https://github.com/open-mt2/pkg_effectlib/pull/2) | read-only particle accessors; `test_effect_determinism` |
| `pkg_etergrnlib` | [#3](https://github.com/open-mt2/pkg_etergrnlib/pull/3) | `test_grn_reference` (world pose, skinning, curves, animation) |
| `devkit` | [#83](https://github.com/open-mt2/devkit/pull/83) | task sheet, evidence |

## Commands and output

Before:

```
$ ctest --test-dir build -R "miles|effect|grn" --output-on-failure
Test project /workspace/build
No tests were found!!!

$ ctest --test-dir build -N | tail -1
Total Tests: 35
```

After:

```
$ ctest --test-dir build -R "miles|effect|grn" --output-on-failure
    Start 25: test_miles_headless
1/3 Test #25: test_miles_headless ..............   Passed    0.01 sec
    Start 28: test_grn_reference
2/3 Test #28: test_grn_reference ...............   Passed    0.00 sec
    Start 33: test_effect_determinism
3/3 Test #33: test_effect_determinism ..........   Passed    0.01 sec

100% tests passed, 0 tests failed out of 3
```

```
$ ctest --test-dir build --output-on-failure
100% tests passed, 0 tests failed out of 38
```

Negative control — the audio test rejects a non-null selection instead of
silently relying on the host backend:

```
$ OPENMT2_AUDIO_BACKEND=bogus ./build/src/MilesLib/tests/test_miles_headless
test_miles_headless: ... Assertion `MilesCompatInternal::UseNullAudioBackend()' failed.
Aborted (core dumped)   # exit 134
```

## What is pinned

### Audio (`pkg_mileslib`)

`OPENMT2_AUDIO_BACKEND=null` is read once when the engine singleton is created.
The holder creates a `ma_context` limited to `ma_backend_null`, passes it to
`ma_engine_init`, and uninitialises it after the engine. Both MilesLib CTest
cases set the variable through `ENVIRONMENT`.

`test_miles_headless` asserts the env contract, the engine device context
backend (`ma_backend_null`), sample rate/channels (44100/2), a 3D sample
load/position/release cycle, listener open/close and a full
`CSoundManager` create/volume/fade/update/destroy cycle.

### Effects (`pkg_effectlib`)

`test_effect_determinism` builds a `CParticleSystemData` with a point emitter,
zero-direction emission, gravity 9.8 and air resistance 0.1, then advances a
real `CParticleSystemInstance` four times with a fixed 0.5 s step:

- emission: 2 particles/s at 0.5 s/step -> exactly 4 particles;
- first particle: `position = (7.317, 0, -12.3699)`,
  `velocity = (4.374, 0, -11.9511)`, lifetime `8.5` after three steps;
- a second system built the same way reproduces position/velocity bit-for-bit;
- with `srandom(1234)`, the `EMITTER_ADVANCED_TYPE_OUTER` random velocity is
  reproduced bit-for-bit by a second run.

Only read-only getters were added to `CParticleInstance`
(`GetPosition`, `GetVelocity`, `GetLifeTime`).

### Models (`pkg_etergrnlib`)

`test_grn_reference` uses no assets and no GPU:

- `GrannyBuildWorldPose` with a root translated `(1,2,3)` and rotated 90 deg
  about Z, and a child offset `(2,0,0)`: root matrix `(0,1 / -1,0)` with
  translation `(1,2,3)`, child at `(1,4,3)`;
- `GrannyDeformVertices` with two bones (Rz90 and `+10` on Y): pure bone 0,
  pure bone 1 and a `128/127` byte-weight blend. Expected positions
  `(0,1,0)`, `(1,10,0)` and `(127/255, 1398/255, 0)`; normals likewise;
- `GrannySampleCurveVec3`/`GrannySampleCurveQuat`: linear `0 -> (10,20,30)`
  samples at 25 %, clamping at both ends, and identity -> Rz90 slerp at 50 %
  gives Rz45;
- end to end: a keyframed animation sampled at 25 % yields position `x = 2.5`
  and orientation Rz(22.5 deg); the built world matrix is `cos/sin(22.5)` with
  translation `(2.5,0,0)`.

## Notes / follow-ups

- The null backend is opt-in, not the default: the shipping client can still
  use ALSA/PulseAudio/etc. `TA.8` should record the audio backend alongside the
  existing char/metric goldens if audio output becomes an oracle.
- `CParticleSystemData` requires at least one texture-animation frame for
  `OnUpdate` to step particles at all; the test uses a null placeholder image
  to avoid GPU work. Worth remembering when adding any effect tooling.
- Per-particle randomness still comes from the process-global `random()`.
  Seeding is now characterised, but a future per-system RNG (T5.x) would be a
  behaviour change and must update this test deliberately.
- The tests are CPU-only; the Windows preset will run them unchanged once the
  cross-compiled test binaries exist (T0.x/T3.x).
