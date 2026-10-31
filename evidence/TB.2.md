# TB.2 — Create `neoeter-python` and `client`

- agent: opencode
- date: 2026-10-31
- command: `scripts/import-repo.sh --target ../neoeter-python`, `… --target ../client`, then `scripts/golden-check.sh`
- before: `pkg_scriptlib`, `pkg_eterpythonlib`, `pkg_gamelib`, `pkg_userinterface`, `pkg_cwebbrowser` as separate packages.
- after:
  - `neoeter-python`: `include/Neoeter/Python/{Host,Bindings}`, `src/host`, `src/bindings`, targets `neoeter_python_host` / `neoeter_python_bindings` with `NeoeterPython::Host` / `NeoeterPython::Bindings`; one vendored `include/python2.7` set.
  - `client`: `include/Client/{Game,UI,WebBrowser}`, `src/{game,ui,webbrowser}`, targets `client_game` / `client_ui` / `client_webbrowser` with `Client::Game` / `Client::UI` / `Client::WebBrowser`; executable at `build/src/ui/metin2client`.
  - 239 bridge files and 292 client files imported, 49/49 CTest, 11/11 golden checks, Windows cross-build green.
- notes: commits `4c95f2e` (neoeter-python) and `cca695a` (client). CTest names were kept stable, so `golden/ctest-tests.txt` is unchanged; `golden/api.sha256` changed by path only. Removing the per-package `Platform` copies exposed a dead `ShowCursor()` stub; the engine shim now carries the reference counter (`cb2c8f7`).
