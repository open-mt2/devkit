# TB.1 — Merge engine layers L0–L3 into `neoeter`

- agent: opencode
- date: 2026-10-31
- command: `scripts/import-repo.sh --target ../neoeter` then `docker run … openmt2/client -t --skip-pack` and `scripts/golden-check.sh`
- before: 11 engine repositories under `devkit/src` (`pkg_eterbase`, `pkg_eterlocale`, `pkg_spherelib`, `pkg_eterpack`, `pkg_eterimagelib`, `pkg_eterlib`, `pkg_mileslib`, `pkg_etergrnlib`, `pkg_speedtreelib`, `pkg_prterrainlib`, `pkg_effectlib`), built as `src/<Package>` with `Eter*` targets and include roots.
- after: one repository with the flat layout
  - `include/Neoeter/{Platform/{Base,Locale,Math},IO,Image,Render,Audio,Model/{Grn,SpeedTree},Terrain,Effect}` plus the shared `include/Platform/` D3D9 shim;
  - `src/{platform/{base,locale,math},io,image,render,audio,model/{grn,speedtree},terrain,effect}`, code directly in the role directory, tests next to it;
  - targets `neoeter_*` with `Neoeter::…` aliases (e.g. `Neoeter::Platform::Base`, `Neoeter::Render`);
  - 520 imported files, 49/49 CTest, 11/11 golden checks, Windows cross-build green.
- notes: history preserved per repository with `git filter-repo --to-subdirectory-filter`; the flatten is commit `a7a3faa` plus the shim fix `cb2c8f7`. Golden digests did not change — only the path columns moved. Engine test names (`EterLib_SmokeTests`, `test_eterpack`, …) were intentionally left stable so the frozen 49-test inventory stays valid.
