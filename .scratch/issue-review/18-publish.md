## Parent

https://github.com/open-mt2/devkit/issues/18

## What to build

`MSWindow.cpp`, `MSApplication.cpp`, `GrpScreen.cpp`; delete `CreateWindow`/`WndProc` path.

## Acceptance criteria

- [ ] no `CreateWindowEx` in tree; window opens under Wine.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.1 (#57), D2

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:18 -->
