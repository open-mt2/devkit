## Parent

https://github.com/open-mt2/devkit/issues/33

## What to build

pragma block `UserInterface.cpp:41-58`, `StdAfx.h:23-40`, `miles/MSS.H`, `directxsdk`, `extern/` expectations, `_fltused`/`NvOptimus` exports.

## Acceptance criteria

- [ ] `grep -r "mss32\|SpeedTreeRT.lib\|directxsdk\|dinput"` empty.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.5, T2.1
