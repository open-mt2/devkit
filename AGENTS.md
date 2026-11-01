# AGENTS.md — devkit

Global agent rules — tracking, branch and PR policy, test-first, evidence,
GitHub authentication and reporting — live in
[`open-mt2/agent-docs/AGENTS.md`](https://github.com/open-mt2/agent-docs/blob/main/AGENTS.md).
Read both before working here.

## Base image

`dockerfile.base` is built and published **manually** — there is no CI workflow
for it and none should be added. Rebuild and push
`ghcr.io/open-mt2/devkit-base:bookworm` when `dockerfile.base`,
`scripts/build-windows-deps.sh` or `scripts/fetch-windows-python.sh` change:

```bash
docker build -f dockerfile.base -t ghcr.io/open-mt2/devkit-base:bookworm .
docker push ghcr.io/open-mt2/devkit-base:bookworm
```

The client image and the release workflow pull that tag, so publish the base
before tagging a release.
