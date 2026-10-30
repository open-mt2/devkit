## Parent

https://github.com/open-mt2/devkit/issues/10

## What to build

`git filter-repo --to-subdirectory-filter src/<role>` per repo; move-only commit; `src/{platform,io,image,render,audio,model,terrain,effect}`.

## Acceptance criteria

- [ ] same targets, same 22 CTest cases, same golden hashes.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

TA.8 (#49), D14

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:10 -->
