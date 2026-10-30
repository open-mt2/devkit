# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues on **`open-mt2/devkit`** —
the `upstream` remote, not the `origin` fork. Use the `gh` CLI for all operations.

## Use the wrapper, not plain `gh`

On this machine the keyring hangs, so plain `gh` will block on any auth command.
Use the wrapper at `.local/gh`, which injects `GH_TOKEN` from
`~/.config/openmt2/gh-token`:

```bash
.local/gh issue view 42 --comments
```

Every `gh` command below is shorthand for `.local/gh` with the same arguments.
Target the tracker explicitly, since `gh` infers the repo from the clone and
would otherwise hit the fork:

```bash
.local/gh issue list --repo open-mt2/devkit
```

## Conventions

- **Create an issue**: `.local/gh issue create --repo open-mt2/devkit --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `.local/gh issue view <number> --repo open-mt2/devkit --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `.local/gh issue list --repo open-mt2/devkit --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Make an issue a sub-issue of a parent**: `.local/gh issue create --parent <parent> ...`, or `issue edit <parent> --add-sub-issue <child>` afterwards (`gh` 2.94+). Older `gh`: `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>` (database id, as in **Blocking** below). Without sub-issues, put `Part of #<parent>` at the top of the child body.
- **Comment on an issue**: `.local/gh issue comment <number> --body "..."`
- **Apply / remove labels**: `.local/gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `.local/gh issue close <number> --comment "..."`

## Repo-specific issue shape

`AGENTS.md` is the source of truth for tracking here. Mirror it:

- **Title**: `[<ID>] <title>`, matching the task ID in
  `docs/planning/windows-parity-tasks.md`.
- **Milestone**: one per wave.
- **Labels**: always include `parity`; add `deferred` for deferred work.
- **PRs**: reference the issue with `Closes #<n>`; do not self-merge.
- **State**: the task sheet is the source of truth for scope and state — the
  issue is the progress view. Update both together.
- Blocked or undecided work is tracked in issue #1 (D1–D16).

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `.local/gh pr view <number> --comments` and `pr diff <number>` for the diff.
- **List external PRs for triage**: `.local/gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Comment / label / close**: `.local/gh pr comment`, `pr edit --add-label`/`--remove-label`, `pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `.local/gh pr view 42` and fall back to `issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue on `open-mt2/devkit`.

## When a skill says "fetch the relevant ticket"

Run `.local/gh issue view <number> --repo open-mt2/devkit --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `.local/gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (see **Make an issue a sub-issue of a parent**). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `.local/gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`.local/gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`.local/gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `.local/gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `.local/gh issue comment <n> --body "<answer>"`, then `issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
