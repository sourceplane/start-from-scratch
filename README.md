# start-from-scratch

The smallest Orunbase baseline: a new repository with an Orunbase intent, a
README and the Orun CI workflow, linked to its workspace, with one placeholder
epic and its onboarding task on the plane. No components, no cloud provider,
nothing deployed. Build it when you want a repository Orunbase already knows
about and you will decide what goes in it later.

## What a new repository gets

| File | What it does |
|---|---|
| `intent.yaml` | The Orunbase intent, named for the repository: its workspace, the `stack-tectonic` composition stack, the pull-request and push-to-main triggers, and dev, stage and prod. No components. |
| `README.md` | A short README titled with the display name, saying how to add the first component and the first epic. |
| `.github/workflows/ci.yml` | The standard Orun pipeline every Orunbase baseline ships: `orun plan --changed`, then one job per lane. Empty, the plan has no jobs and the run is green. |
| `.gitignore` | Keeps orun's local working files out of git. |

And in the workspace, before anything is placed:

| Work | |
|---|---|
| Epic | **Onboarding — {display name}** (slug `onboarding`), a placeholder to close once real work starts |
| Milestone | `01-onboarding` |
| Task | **Onboard the repository** (a `BASE-n` key): the first pull request, which lands the four files above |

## Instantiating a repository

From the Orunbase console: Baselines → `start-from-scratch` → Build. The only thing it
asks for is the GitHub App on the owner the repository is created under.

By hand, from a checkout of a baseline tag:

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/start-from-scratch
cd start-from-scratch
orun new --blueprint repo-blueprint.yaml --out ~/src/acme --run-hooks --resume \
  --set reponame=acme --set productname="Acme" --set githuborg=acme-inc
```

One phase, `01-onboarding`: wait for the GitHub App on the owner, create the
repository, link it to the workspace, land the four files as one pull request
under the onboarding task, and watch the merge's CI run come back green.

## What makes it a baseline

| | Where |
|---|---|
| The console card (inputs, programme) | `blueprint.yaml` |
| The build document (modules, the phase, its hooks) | `repo-blueprint.yaml` |
| The product's templated files and the onboarding task's contract | `.baseline/` |
| The baseline's tests: the card against the build, the offline placement | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

This repository's own `intent.yaml` is `.baseline/product/intent.yaml`
rendered for itself with the placeholder workspace `ws_CHANGE_ME`, so its own
`ci.yml` plans nothing; `testing/placement.test.sh` fails if the two drift.

## CI

| Workflow | What it runs | Ships to a repository |
|---|---|---|
| `ci.yml` | The Orun pipeline. Plans nothing here (`ws_CHANGE_ME`). | yes |
| `baseline.yml` | `testing/manifest.test.sh`, the build document read by the pinned orun, and `testing/placement.test.sh` | no |
| `tag.yml` | Cuts a `baseline-vN` tag (manual) | no |

## Releasing

Cut `baseline-vN` from a green `main` (Actions → Baseline tag), then move the
`start-from-scratch` row's `tag` in orun-cloud's `infra/baselines-registry/baselines.yaml`,
in that order: the registry's preflight fetches `blueprint.yaml` at the tag.
