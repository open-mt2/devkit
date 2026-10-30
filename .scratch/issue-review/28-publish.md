## Parent

https://github.com/open-mt2/devkit/issues/28

## What to build

vendor PSF `python27.dll` + `dlltool` import lib (or cross-build); wire into CMake; ship in `dist/`.

## Acceptance criteria

- [ ] `metin2client.exe` boots the interpreter and loads the `.pyc` set.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

D3, TA.6 (#47) (recommended)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:28 -->
