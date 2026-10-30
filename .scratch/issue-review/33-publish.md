## Parent

https://github.com/open-mt2/devkit/issues/33

## What to build

pragma block `UserInterface.cpp:41-58`, `StdAfx.h:23-40`, `miles/MSS.H`, `directxsdk`, `extern/` expectations, `_fltused`/`NvOptimus` exports.

## Acceptance criteria

- [ ] `grep -r "mss32\|SpeedTreeRT.lib\|directxsdk\|dinput"` empty.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.5 (#62), T2.1 (#65)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:33 -->
