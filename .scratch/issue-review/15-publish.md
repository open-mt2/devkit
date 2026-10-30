## Parent

https://github.com/open-mt2/devkit/issues/15

## What to build

`cmake/toolchain-i686-windows-gnu.cmake`, `CMakePresets.json`, `windows` subcommand in `docker/entrypoint.sh`, `scripts/build-windows.sh`, `dist/` assembly.

## Acceptance criteria

- [ ] `docker run … windows` configures and fails only on missing deps.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

D7, D8, TB.3 (#52) (soft)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:15 -->
