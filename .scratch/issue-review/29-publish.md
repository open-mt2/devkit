## Parent

https://github.com/open-mt2/devkit/issues/29

## What to build

remove unconditional `dl`/`pthread` (`userinterface:101-102`, `mileslib:101`, `scriptlib:99`, `eterpythonlib:100`); make `eterbase:35` `OpenGL::GL` platform-aware.

## Acceptance criteria

- [ ] no POSIX libs linked on Windows.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T0.2 (#55)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:29 -->
