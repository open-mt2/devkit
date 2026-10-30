# TA.7 — Coverage ratchet

- agent: agent-06
- date: 2026-10-31
- command: `scripts/coverage.sh --check`
- issue: https://github.com/open-mt2/devkit/issues/48
- before: `scripts/coverage.sh --check` compared one `TOTAL` percentage with
  `coverage/baseline.txt`, a file excluded by `.gitignore` and overwritten by
  every non-check run. A clean checkout therefore had no baseline, the check
  could never fail, and no per-module data existed. The devkit also had no CI
  workflow at all (`gh api repos/open-mt2/devkit/actions/workflows` returned
  `total_count: 0`), so nothing enforced it. Finally the Debug suite that
  coverage needs was red: `test_pack_formats` and `test_effect_determinism`
  aborted on `main` (39/41), so no trustworthy baseline could be recorded.
- after: `golden/coverage-baseline.txt` records covered/total lines for all 16
  `src/<Package>` modules, `scripts/coverage.sh --check` fails only when a
  module covers fewer lines than the baseline, and
  `.github/workflows/coverage.yml` runs it for every push and pull request.
  Debug suite is green (41/41), `--check` passes:
  19.3% (19 628 / 101 859 lines). Adding uncovered code does not fail the
  ratchet; losing a covered module or covered lines does.
- notes: files, harness contract, negative controls and the two prerequisite
  package fixes below.

## What changed

| File | Change |
|---|---|
| `scripts/coverage-ratchet.py` | new: `collect` gcov JSON into a per-module summary; `check` compares covered lines per module with the baseline |
| `scripts/coverage.sh` | resets stale `.gcda`, writes `coverage/summary.txt` + `coverage/files.txt`, supports `--check`, `--update`, `--update --force`; dropped the absolute `MIN_COVERAGE` floor |
| `scripts/test-coverage-ratchet.sh` | new: 28-case self-test (aggregation, regression, growth, missing module, new module, corrupt baseline, update policy) |
| `golden/coverage-baseline.txt` | new: committed per-module baseline (16 modules + TOTAL) |
| `golden/README.md` | documents the baseline and its refresh rule |
| `.github/workflows/coverage.yml` | new: builds the image and runs `coverage --check` |

## Why covered lines, not a percentage floor

The task sheet forbids absolute targets. A percentage ratchet also turns red
when a move-only refactor adds uncovered lines (shims, aliases), which Wave B
does by design. Gating the covered-line count per module means:

- adding untested code: passes (percentage may drop);
- deleting tests, dropping a package or skipping targets: fails;
- a move-only refactor: passes with an identical count (Wave B requirement).

Percentages are still reported per module and in total.

## Commands and output

Full run and baseline creation:

```
$ scripts/coverage.sh --update
100% tests passed, 0 tests failed out of 41
[coverage] collecting gcov data (333 objects)
[coverage] 16 modules, 19628/101859 lines (19.3%)
[coverage] baseline written to '/workspace/golden/coverage-baseline.txt'
```

Ratchet:

```
$ scripts/coverage.sh --check --no-build
  CWebBrowser       96.3%     52/54     lines  (baseline 52)
  EffectLib         46.8%   1675/3581   lines  (baseline 1675)
  ...
  UserInterface      5.9%   1576/26879  lines  (baseline 1576)
[coverage] 16 modules, 19628/101859 lines (19.3%)
[coverage] OK: no per-module regression
```

Self-test (no build required):

```
$ scripts/test-coverage-ratchet.sh
28 passed, 0 failed
```

Negative control — one covered line added to the `EterBase` baseline entry:

```
$ COVERAGE_BASELINE=/tmp/baseline-regressed.txt scripts/coverage.sh --check --no-build
FAIL  EterBase: covered lines 2162 < 2163 (-1)
[coverage] FAIL ...
$ echo $?
1
```

`--update` with the same red baseline refuses to rewrite it:

```
$ COVERAGE_BASELINE=/tmp/baseline-regressed.txt scripts/coverage.sh --update --no-build
FAIL  EterBase: covered lines 2162 < 2163 (-1)
error: refusing to rewrite the baseline after a failing check; review the regressions and pass --force to accept them
```

The `--force` path, new modules, missing modules and corrupt baselines are
covered by `scripts/test-coverage-ratchet.sh` (28/28).

## Prerequisite fixes (Debug suite was red)

The ratchet needs a green suite. Two latent assert failures on `main` blocked
the baseline; both are Debug/assert-only (the Release goldens in TA.8 are
unaffected).

| Repo | PR | Failure |
|---|---|---|
| `pkg_eterbase` | https://github.com/open-mt2/pkg_eterbase/pull/4 | `korean_tolower` asserted `ret == tolower(c)` for negative `char` values; `test_pack_formats` aborted in `Stl.cpp:12` |
| `pkg_effectlib` | https://github.com/open-mt2/pkg_effectlib/pull/3 | `test_effect_determinism` never called `CGraphicImageInstance::DestroySystem()`; aborted in `Pool.h:19` at exit |

Both PRs land a failing test/case and the fix, and both were verified in the
Debug coverage build.

## CI

`.github/workflows/coverage.yml` is the first workflow in this repository. It
builds the development image (`WITH_BIN=0`, `WITH_SPEEDTREE=0` — assets are
irrelevant to coverage), mounts the checkout's `scripts/`, `golden/` and a
`build-coverage/` directory, and runs `coverage --check`. The report is uploaded
as an artifact. This PR is stacked on the two package PRs above because the
image fetches `main` from the package repositories.

## Notes / follow-ups

- The baseline is per module (`src/<Package>`), not per file: a per-file
  ratchet would fail on every file split during Wave B.
- Wave B changes the module names (16 packages → 3 repositories). The merge PR
  must refresh the baseline and state that the covered-line total is unchanged.
- Removing the `MIN_COVERAGE` absolute floor is deliberate; it was the only
  absolute target in the script.
- The self-test is not part of CTest (the root `CMakeLists.txt` comes from the
  image); it is a plain script and runs in the image without a build tree.
- Not fixed here: `test_effectlib` has the same missing image-pool teardown but
  does not allocate instances today; call `CGraphicImageInstance::DestroySystem()`
  there if it starts to.
