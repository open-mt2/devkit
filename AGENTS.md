# AGENTS.md — OpenMT2 client devkit

Project instructions for AI agents working in this repository.

## What this repository is

The Docker development kit for the OpenMT2 client: image definition, build and
packaging scripts. The client sources are fetched at image build time into
`/workspace/src` (16 `pkg_*` repositories) and are **not tracked here**.

```
dockerfile                image definition
docker/                   entrypoint + /workspace scaffold + vendored headers
scripts/build.sh          Linux build + dist packaging
scripts/build.bat         historical Windows/MSVC script (being retired)
scripts/fetch-*.sh        source and asset fetchers
scripts/bake-trees.sh     SpeedTree geometry cache baker (needs Wine)
docs/planning/            the parity plan and the task sheet (tracked)
src/                      materialized client sources (gitignored)
bin/                      client assets (gitignored, ~2.3 GB)
build/ dist/ treecache/   generated (gitignored)
```

## Read first

Before doing any work, read:

1. `docs/planning/windows-parity.md` — the cross-platform / no-proprietary plan.
2. `docs/planning/windows-parity-tasks.md` — the **execution source of truth**: 37
   tasks, 16 decisions, per-task size, dependencies, verification command, evidence
   rules.

Update the task sheet as you work: tick decisions, claim tasks with `- [~]` +
`owner:`, close them with `- [x]` + the evidence path, and keep the counters in
§1 accurate.

## Tracking

Every task is mirrored as an issue in `open-mt2/devkit`, titled `[<ID>] <title>`,
with one milestone per wave and the `parity` label. The task sheet remains the
source of truth for scope and state; the issues are the progress view and the
place PRs close (`Closes #<n>`). Assign the issue to yourself when you claim a
task, and keep the sheet's checkbox, owner and counters in sync.

Blocked/undecided work is tracked in issue #1 (D1–D16). Deferred work carries the
`deferred` label.

## Hard rules

1. **Decisions gate tasks.** A task whose `deps` include an unchecked `D*` decision
   must not start. Ask the user; do not pick a decision silently.
2. **Test first.** No task lands without a test that fails before and passes after,
   or a recorded characterization artifact (render hash, pack transcript).
3. **One task per branch and per commit series.** Branch `task/<ID>-<slug>`,
   commit prefix `[<ID>]`.
4. **Nothing merged to `main` without review.** Push the branch, open a PR, report
   the link. Do not self-merge unless the user explicitly asks.
5. **Never commit generated or licensed content:** `src/`, `bin/`, `build/`,
   `dist/`, `treecache/`, `.local/`, assets (`.gr2`, `.spt`, packs).
6. **Structural tasks are move-only.** File moves, renames and reformatting must be
   separate commits from behaviour changes.
7. **Evidence.** Every closed task writes `evidence/<ID>.md` with the command,
   before/after output, and notes.

## Environment

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
- vendor markers: the image has `i686-w64-mingw32-gcc` only (no C++ cross compiler),
  Wine 8.0, Python 2.7, CMake 3.25, Ninja.

GitHub CLI: the keyring hangs on this machine, so **use the wrapper** (it injects
`GH_TOKEN` from `~/.config/openmt2/gh-token`):

```bash
.local/gh repo view open-mt2/devkit
.local/gh pr create ...
```

Plain `gh` will hang on any auth command — do not use it, and do not remove
`~/.config/gh/hosts.yml` unless asked.

Git: SSH works (`git@github.com` as `PoNo1101`). Remotes must use SSH, not HTTPS.

## Verification commands

```bash
# Linux build + full test suite (22 CTest cases today)
docker run ... openmt2/client -t --skip-pack          # see command above

# cross-compile probe (Windows target; C only until g++ is added)
docker run ... openmt2/client shell -c 'i686-w64-mingw32-gcc --version'

# repository state
git status --short && git log --oneline -3
```

## Repository topology (target)

16 `pkg_*` repositories are being consolidated into three: `neoeter` (engine),
`neoeter-python` (Python bridge), `client` (game). Until decided and merged (D14),
edit the `pkg_*` repositories, never create per-library repos.

## Reporting

When a task closes, return exactly:

```
<ID> done.
changed: <paths>
tests: <n> added, <n> updated — `ctest` <pass/total>
evidence: evidence/<ID>.md
follow-ups: <new tasks or "none">
```
