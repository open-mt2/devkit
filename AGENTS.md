# AGENTS.md — OpenMT2 client devkit

Local instructions for AI agents working in this repository.

Global agent rules — tracking, branch and PR policy, test-first, evidence,
GitHub authentication and reporting — live in
[`open-mt2/agent-docs`](https://github.com/open-mt2/agent-docs/blob/main/AGENTS.md).
Read that first. This file only records what is specific to the devkit.

## What this repository is

The Docker development kit for the OpenMT2 client: image definition, build and
packaging scripts. The client sources are fetched at image build time into
`/workspace/src` (16 `pkg_*` repositories) and are **not tracked here**.

```
dockerfile                image definition
docker/                   entrypoint + /workspace scaffold + vendored headers
scripts/build.sh          Linux build + dist packaging
scripts/build-windows.sh  Windows cross-build + dist packaging
scripts/smoke.sh          headless boot smoke (Linux + Wine)
scripts/fetch-*.sh        source and asset fetchers
scripts/bake-trees.sh     SpeedTree geometry cache baker (needs Wine)
docs/planning/            the parity plan and the task sheet (tracked)
evidence/                 per-task command output and notes (tracked)
golden/                   pinned render/format/test baselines (tracked)
src/                      materialized client sources (gitignored)
bin/                      client assets (gitignored, ~2.3 GB)
build/ dist/ treecache/   generated (gitignored)
```

## Read first

1. `docs/planning/windows-parity.md` — the cross-platform / no-proprietary plan.
2. `docs/planning/windows-parity-tasks.md` — the **execution source of truth**:
   38 tasks, 16 decisions, per-task size, dependencies, verification command,
   evidence rules.

Update the task sheet as you work: tick decisions, claim tasks with `- [~]` +
`owner:`, close them with `- [x]` + the evidence path, and keep the counters in
§1 accurate.

## Tracking

Every task is mirrored as an issue in `open-mt2/devkit`, titled `[<ID>] <title>`,
with one milestone per wave and the `parity` label. The task sheet is the source
of truth for scope and state; the issues are the progress view and the place PRs
close (`Closes #<n>`). Assign the issue to yourself when you claim a task, and
keep the sheet's checkbox, owner and counters in sync.

## Build and test

Docker image (already built as `openmt2/client`):

```bash
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/src:/workspace/src" \
  -v "$PWD/build:/workspace/build" \
  -v "$PWD/dist:/workspace/dist" \
  openmt2/client -t --skip-pack
```

Rules for container runs:

- always `--user "$(id -u):$(id -g)" -e HOME=/tmp`, otherwise `dist/` and `build/`
  become root-owned;
- always mount `build/` so runs are incremental;
- vendor markers: `i686-w64-mingw32-gcc`, `x86_64-w64-mingw32-gcc/g++`,
  Wine 8.0 (32- and 64-bit), Python 2.7, CMake 3.25, Ninja, Xvfb + ImageMagick.

## Verification commands

```bash
# Linux build + full test suite (49 CTest cases, all green)
docker run ... openmt2/client -t --skip-pack          # see command above

# Windows cross-build + boot smoke
docker run ... openmt2/client windows
scripts/smoke.sh windows && scripts/smoke.sh linux

# cross-compile probe
docker run ... openmt2/client shell -c 'x86_64-w64-mingw32-g++ --version'

# golden baseline (11 checks, all green)
scripts/golden-check.sh

# repository state
git status --short && git log --oneline -3
```

## Never commit

`src/`, `bin/`, `build/`, `dist/`, `treecache/`, `.local/`, and game assets
(`.gr2`, `.spt`, packs). They are gitignored — do not force-add them.

## Repository topology (target)

16 `pkg_*` repositories are being consolidated into three: `neoeter` (engine),
`neoeter-python` (Python bridge), `client` (game). Until decided and merged (D14),
edit the `pkg_*` repositories, never create per-library repos.
