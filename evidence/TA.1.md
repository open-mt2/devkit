# TA.1 — Test harness + CI baseline

- agent: agent-01
- date: 2026-10-30
- issue: https://github.com/open-mt2/devkit/issues/2

## Command

```bash
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/src:/workspace/src" -v "$PWD/scripts:/workspace/scripts" \
  -v "$PWD/build-coverage:/workspace/build-coverage" \
  -v "$PWD/coverage:/workspace/coverage" \
  --entrypoint bash openmt2/client -c 'cd /workspace && ./scripts/coverage.sh'
```

## Before

- `ctest`: 22/22 "passing" in the default Release build — but `NDEBUG` disabled every
  `assert`, so the suite was partly vacuous.
- No coverage tooling, no shared test header, no `-UNDEBUG`.

## After

- `ctest`: **22/22 passing in Debug with asserts active** (0.30 s).
- Coverage: **13.0 %** (11 973 / 91 964 project lines), 293 instrumented objects,
  full per-file report in `coverage/summary.txt`.
- `scripts/coverage.sh` (gcov only, no new dependency), exposed as the `coverage`
  entrypoint command, with a `--check` ratchet mode.

## Changes

- `pkg_eterbase` — `tests/support/TestAssert.h` (D15 reference implementation),
  `-UNDEBUG` on test targets, `test_crc32` converted. PR:
  https://github.com/open-mt2/pkg_eterbase/pull/1
- `devkit` — `scripts/coverage.sh`, `coverage` entrypoint command, ignore rules.
- Two latent failures surfaced once asserts became active:
  - `pkg_eterlib` — `CIME::GetText` appends to the destination string; the test
    reused its buffer. PR: https://github.com/open-mt2/pkg_eterlib/pull/1
  - `pkg_prterrainlib` — fixture used `long` (8 bytes on LP64) for the on-disk
    `LONG` water heights. PR: https://github.com/open-mt2/pkg_prterrainlib/pull/1

## Remaining for TA.1

- Roll `tests/support/TestAssert.h` + `-UNDEBUG` out to the other 15 packages.
- Wire `coverage --check` into CI once a baseline is recorded.

## Rollout (15 packages)

Each package received its own copy of `tests/support/TestAssert.h` and the
`-UNDEBUG` compile option, through branch `task/TA.1-rollout`:

`pkg_cwebbrowser`, `pkg_effectlib`, `pkg_etergrnlib`, `pkg_eterimagelib`,
`pkg_eterlib`, `pkg_eterlocale`, `pkg_eterpack`, `pkg_eterpythonlib`,
`pkg_gamelib`, `pkg_mileslib`, `pkg_prterrainlib`, `pkg_scriptlib`,
`pkg_speedtreelib`, `pkg_spherelib`, `pkg_userinterface`.

Verified together in the image (Debug, asserts active): 22/22 CTest pass.

## CI fallout

Two repos (`pkg_eterlib`, `pkg_prterrainlib`) had failing workflows: the runners
only installed lzo/zip/jpeg, so `find_package(OpenGL REQUIRED)` in the fetched
EterBase dependency failed. Fixed by adding `libgl1-mesa-dev`, `libglu1-mesa-dev`,
`libsdl2-dev` and `libfreetype-dev` to their install steps.
