## Parent

https://github.com/open-mt2/devkit/issues/30

## What to build

`dist/` with `.exe`, `SDL2.dll`, `python27.dll`, assets, `treecache/`, pack archives — mirroring `build.sh`.

## Acceptance criteria

- [ ] trees differ only by binary + runtime DLLs.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T2.3 (#67), T2.4 (#68)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:30 -->
