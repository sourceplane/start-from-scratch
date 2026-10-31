# {{ .productname }}

{{ .productname }} starts empty: an Orunbase intent, this README and the Orun
CI workflow, in `{{ .githuborg }}/{{ .reponame }}`, linked to its workspace.
Nothing is deployed yet, because there is nothing to deploy.

| File | What it does |
|---|---|
| `intent.yaml` | The repository's Orunbase intent: its workspace, the composition stack it builds on, its triggers and its three environments (dev verifies, stage and prod deploy). |
| `.github/workflows/ci.yml` | The Orun pipeline. `orun plan --changed` on every pull request and every merge to `main`, then one job per lane. With no components the plan is empty and the run is green. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the components and environment it names. |
| `.gitignore` | Keeps orun's local working files out of git. |

## Your first component

A component is a directory with a `component.yaml`. Add one anywhere in the
tree, open a pull request, and the plan picks it up: the pull request verifies
it in dev, and the merge deploys it to stage and then prod. The composition
stack (`stack-tectonic`) supplies the component types; any Orunbase baseline's
`apps/` is a worked example.

Once the layout settles, declare where components live in `intent.yaml`:

```yaml
discovery:
  roots:
    - apps/
    - tests/
```

## Work

The bootstrap opened one epic in the workspace, **Onboarding**, with one task:
the pull request that put these files here. It is a placeholder. Write the
first real epic next, as a directory with an `epic.yaml`, and point
`intent.yaml` at it:

```yaml
work:
  epics: specs/epics
  tasks: tasks
  sync: on-merge
```

The merge that adds it creates it in Orunbase.
