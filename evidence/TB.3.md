# TB.3 — Devkit rewire

- agent: opencode
- date: 2026-10-31
- command: `scripts/fetch-sources.sh /tmp/fetchtest && cmake -S /workspace -B /tmp/cfg4` (image), full Linux and Windows builds, `scripts/golden-check.sh`
- before: the image cloned 16 `pkg_*` repositories via `scripts/packages.map` + `scripts/fetch-packages.sh`; the root CMakeLists read `packages.map`; goldens and the feature matrix pointed at `src/<Package>`.
- after:
  - `scripts/sources.map` + `scripts/fetch-sources.sh` clone `neoeter`, `neoeter-python`, `client` into `src/`;
  - `dockerfile` and the `fetch` entrypoint use the new fetcher (CI cache-bust arg renamed `SRC_CACHE_BUST`);
  - `docker/root/CMakeLists.txt` adds the three repository roots and keeps `packages.map` only as a fallback for pre-consolidation images;
  - `scripts/golden-check.sh`, `golden/*.sha256`, the transcript headers, `scripts/build.sh`, `scripts/build-windows.sh` and `docs/planning/feature-matrix.md` follow the role-based paths.
- notes: no compatibility shims are kept — the include roots are `<Neoeter/…>` and `<Client/…>` outright. `fetch-sources.sh` was verified against the three published repositories and the root CMake configured from that `src/` tree. PR: https://github.com/open-mt2/devkit/pull/124
