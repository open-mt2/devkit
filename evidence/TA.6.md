# TA.6 — Python binding smoke tests

- agent: agent-04
- date: 2026-10-30
- command: `ctest -R "python|scriptlib"` (plus full `ctest` and a golden-file negative control)
- before: `ctest -R "python|scriptlib"` matched **zero** tests: the existing suites were `ScriptLib_SmokeTests` and `EterPythonLib_SmokeTests` (case-sensitive `-R`), and `UserInterface` had no Python test at all. Nothing booted the full client interpreter, imported the registered modules, or pinned the exposed API, so a removed/renamed binding could ship unnoticed. Baseline on this branch: `ctest` 37/37 (the `test_packet` case from TA.3 lives on a separate open PR, not on `main`).
- after: `ctest -R "python|scriptlib"` runs 3/3 (`test_python_scriptlib_api`, `test_python_eterpythonlib_api`, `test_python_client_api`). Full suite 40/40. The interpreter boots headless (`Py_NoSiteFlag=1`, no display and no game assets) and every registered module imports. Committed snapshots: ScriptLib 3 modules / 32 attributes, EterPythonLib 5 / 269, full client 35 / 2155. A deliberately corrupted golden fails with the first differing line and writes the actual surface.
- notes: files and follow-ups below. No production behaviour changed; tests and CI dependency setup only.

## Slices

| Repository | PR | Result |
|---|---|---|
| `pkg_scriptlib` | [#2](https://github.com/open-mt2/pkg_scriptlib/pull/2) | `PythonApiSnapshot.h`, `test_python_scriptlib_api`, golden `tests/data/python_api_scriptlib.txt` |
| `pkg_eterpythonlib` | [#2](https://github.com/open-mt2/pkg_eterpythonlib/pull/2) | `test_python_eterpythonlib_api`, golden `tests/data/python_api_eterpythonlib.txt` |
| `pkg_userinterface` | [#3](https://github.com/open-mt2/pkg_userinterface/pull/3) | `test_python_client_api`, golden `tests/data/python_api_client.txt` |
| `devkit` | [#84](https://github.com/open-mt2/devkit/pull/84) | task sheet, evidence |

Each package PR also updates `.github/workflows/ci.yml` with the sibling
dependency setup the standalone builds now need: OpenGL/SDL2/freetype headers,
and miniaudio 0.11.25 built from source with the same pkg-config file as the
Docker image.

## Commands and output

Before:

```
$ ctest --test-dir build -R "python|scriptlib" --output-on-failure
Test project /workspace/build
No tests were found!!!

$ ctest --test-dir build -N | tail -1
Total Tests: 37
```

After:

```
$ ctest --test-dir build -R "python|scriptlib" --output-on-failure
    Start 35: test_python_scriptlib_api
1/3 Test #35: test_python_scriptlib_api ........   Passed    0.01 sec
    Start 37: test_python_eterpythonlib_api
2/3 Test #37: test_python_eterpythonlib_api ....   Passed    0.01 sec
    Start 40: test_python_client_api
3/3 Test #40: test_python_client_api ...........   Passed    0.02 sec

100% tests passed, 0 tests failed out of 3
```

```
$ ctest --test-dir build --output-on-failure
100% tests passed, 0 tests failed out of 40
```

Snapshot sizes:

```
$ wc -l src/*/tests/data/python_api_*.txt
  276 src/EterPythonLib/tests/data/python_api_eterpythonlib.txt
   37 src/ScriptLib/tests/data/python_api_scriptlib.txt
 2192 src/UserInterface/tests/data/python_api_client.txt
```

Negative control — a golden with one binding removed is rejected:

```
$ cp tests/data/python_api_scriptlib.txt /tmp/golden.txt
$ sed -i "/  TraceError/d" /tmp/golden.txt
$ ./build/src/ScriptLib/tests/test_python_scriptlib_api /tmp/golden.txt
[info] ScriptLib: 3 modules, 32 attributes
[FAIL] API snapshot differs at line 7; actual surface written to /tmp/golden.txt.actual
Aborted (core dumped)   # exit 134
```

## What is pinned

Each test creates `CPythonLauncher`, which calls `Py_Initialize` with
`Py_NoSiteFlag = 1` and registers the embedded `time` and `math` modules. The
tests register the modules they own and then use `PyImport_ImportModule` for
each one, so a module is only recorded if the real import path works.

`tests/support/PythonApiSnapshot.h` walks each module dict, skips `__*`
interpreter bookkeeping, sorts the remaining public attributes and records
either `callable` or the type/repr of a constant. The committed text file is
compared byte-for-byte. Regeneration is deliberate:

```bash
OPENMT2_UPDATE_PYTHON_API=1 ctest --test-dir build -R python --output-on-failure
```

- **ScriptLib** — `dbg`, `math`, `time`. `math`/`time` include the embedded
  implementations registered by `CPythonLauncher::Create`, not the host
  interpreter's modules.
- **EterPythonLib** — `grp`, `grpImage`, `grpText`, `grpThing`, `wndMgr`.
- **UserInterface** — all 35 modules registered by `RunMainScript()`:
  `ServerStateChecker`, `app`, `background`, `chat`, `chr`, `chrmgr`, `dbg`,
  `effect`, `event`, `eventMgr`, `exchange`, `fly`, `grp`, `grpImage`,
  `grpText`, `guild`, `ime`, `item`, `math`, `messenger`, `miniMap`, `net`,
  `nonplayer`, `pack`, `player`, `profiler`, `quest`, `safebox`, `shop`,
  `skill`, `snd`, `systemSetting`, `textTail`, `time`, `wndMgr`.

`grpThing` is registered by `EterPythonLib`'s own test but not by
`RunMainScript()`, so it is deliberately absent from the client snapshot. If
the client starts registering it, add it to `kClientModules`.

`UserInterface.cpp` (the executable, not the library) defines
`__IS_TEST_SERVER_MODE__`; the library-only test defines it as `false` to match
the shipping default so `PythonNetworkStreamModule` links.

## Notes / follow-ups

- The snapshot is names + types + constant values. It does not call any binding,
  so it is safe without a GPU, audio device or game data; behaviour is covered by
  the existing ScriptLib/EterPythonLib/UserInterface suites and TA.5.
- `TA.8` should treat these three files as the Python API golden and diff them
  after Wave B's repository split rather than re-freezing them.
- If a module is added to `RunMainScript()`, add it to `kClientModules` and
  regenerate `python_api_client.txt`; otherwise the import set silently lags
  production.
- Standalone CI already runs `ctest` in all three packages, so the boot is now a
  gate on every push/PR (both GCC and Clang, Debug and Release) **once the
  pre-existing EterBase standalone build is restored** (issue #79, recorded in
  `evidence/TA.4.md`). The package CI runs added the missing OpenGL/SDL/freetype
  and miniaudio setup steps uncovered while validating the PRs; they currently
  stop at the same `pkg_eterbase` blocker (`Platform/stb_image.h` missing,
  `GLuint` unknown in `DirectXMathCompat.h`), which is outside TA.6's scope.
  The in-image build above is green.
