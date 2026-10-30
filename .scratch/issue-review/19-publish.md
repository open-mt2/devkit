## Parent

https://github.com/open-mt2/devkit/issues/19

## What to build

`Input.cpp` on SDL2; delete `DirectInput8Create`; audit DIK↔SDL coverage (wheel, buttons, focus loss).

## Acceptance criteria

- [ ] no `dinput.h` outside legacy headers.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.1 (#57), D2

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:19 -->
