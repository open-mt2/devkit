## Parent

https://github.com/open-mt2/devkit/issues/18

## What to build

`MSWindow.cpp`, `MSApplication.cpp`, `GrpScreen.cpp`; delete `CreateWindow`/`WndProc` path.

## Acceptance criteria

- [ ] no `CreateWindowEx` in tree; window opens under Wine.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.1, D2
