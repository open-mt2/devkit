# Pre-refactor goldens (TA.8)

These files freeze the deterministic behaviour that Wave B (repository moves)
and Waves 0–4 (platform work) must preserve. They are hashes and text
transcripts, not game assets, so nothing licensed lives here.

Check them from the devkit image after a build:

```bash
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/src:/workspace/src" \
  -v "$PWD/build:/workspace/build" \
  -v "$PWD/scripts:/workspace/scripts" \
  -v "$PWD/golden:/workspace/golden" \
  --entrypoint bash openmt2/client -c 'cd /workspace && ./scripts/golden-check.sh'
```

`OPENMT2_BUILD_DIR` overrides the default `build/` directory.

## What is frozen

| File | Source | Pinned by |
|---|---|---|
| `render.sha256` | `src/EterLib/tests/golden/render/*.png` | TA.4, 12 headless scenes |
| `api.sha256` | `src/*/tests/data/python_api_*.txt` | TA.6, embedded Python 2.7 surface |
| `ctest-tests.txt` | `ctest -N` | TA.1–TA.6, sorted test inventory (41 tests) |
| `transcripts/pack.txt` | `test_pack_formats`, `test_eterpack` | TA.3 pack/provider behaviour |
| `transcripts/model.txt` | `test_gr2_reader`, `test_grn_reference` | TA.3/TA.5 model readers and reference math |
| `transcripts/collision.txt` | `test_detector`, `test_grpmath` | TA.2 OBB/ray/math invariants |
| `transcripts/packet.txt` | `test_packet` | TA.3 packet wire layout |

The script also re-runs the render goldens and the three Python API tests, so a
file hash matching while the corresponding behaviour regressed is not enough to
pass.

Transcripts include the exit status of every binary. The renderer environment
is pinned by the script (`LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`)
and the Python tests run with `OPENMT2_AUDIO_BACKEND=null`.

## Refreshing a golden

Only refresh after reviewing the change. `--update` refuses to write a new
baseline when a check fails.

```bash
# normal refresh (tests must pass first)
docker run ... --entrypoint bash openmt2/client -c 'cd /workspace && ./scripts/golden-check.sh --update'

# deliberate Python API change: rewrite the package snapshots and the hashes
docker run ... -e OPENMT2_UPDATE_PYTHON_API=1 \
  --entrypoint bash openmt2/client -c 'cd /workspace && ./scripts/golden-check.sh --update'
```

`--update` also calls `test_render_golden --update`, so a renderer change must
be reviewed as a PNG diff before the new hashes are accepted.

## Rules

- Do not refresh a golden to make a red check green; fix the regression or
  record why the behaviour change is intended in the task's evidence file.
- Wave B is move-only. If the file paths in a manifest change, update the
  manifest paths in the same PR and state that the hashes are unchanged.
- Add a new artefact here when a later task introduces one that must survive
  the refactor; keep the list in this README in sync.
