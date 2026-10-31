# TB.4 — Archive old repositories

- agent: opencode
- date: 2026-10-31
- command: `gh api -X POST repos/open-mt2/<repo>/git/refs -f ref=refs/tags/final -f sha=<main>`; `gh repo archive open-mt2/<repo> --yes`; `git clone git@github.com:open-mt2/<repo>.git ../archive/<repo>`; `../archive/delete-remotes.sh`
- before: 16 writable `pkg_*` repositories, no `final` tags.
- after: all 16 tagged `final` at their last `main` commit, archived read-only, mirrored to `/home/straut/storage/dev/openMT2/archive` (full, non-shallow clones with the `final` tag) and then deleted from the organization. `gh repo list open-mt2` shows only `neoeter`, `neoeter-python`, `client` (plus devkit/docs/agent-docs/.github/speedtreebkr); the three consolidated repositories are the only source of truth.
- notes: every old repository was verified in sync (`git diff HEAD..origin/main` empty) before tagging. Tags: `pkg_eterbase a7920b5`, `pkg_eterlocale 0d8346f`, `pkg_eterpack 1b513d6`, `pkg_eterimagelib 730e68b`, `pkg_spherelib 2929700`, `pkg_cwebbrowser ffb53f8`, `pkg_eterlib 5344c1f`, `pkg_mileslib a901e0c`, `pkg_etergrnlib 042004d`, `pkg_speedtreelib 65665d0`, `pkg_prterrainlib 1738b59`, `pkg_effectlib 7a42cdb`, `pkg_scriptlib 183c2ab`, `pkg_eterpythonlib 006fbe2`, `pkg_gamelib a8df9d9`, `pkg_userinterface 55303c2`. The local archive keeps them browsable; the three consolidated repositories carry the same history and tags.
