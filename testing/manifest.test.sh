#!/usr/bin/env bash
# The card (blueprint.yaml) against the build document (repo-blueprint.yaml).
#
# The console renders the card and the runner runs the build; nothing at run
# time compares them, so a list that drifts between the two is a preview that
# lies. Every list the card previews is checked here against the document that
# actually does the thing. Needs python3 with PyYAML; no network, no orun.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import os
import sys

import yaml

card = yaml.safe_load(open("blueprint.yaml"))
build = yaml.safe_load(open("repo-blueprint.yaml"))
problems = []


def check(ok, msg):
    if not ok:
        problems.append(msg)


spec = card["spec"]

# Identity and source.
check(card.get("apiVersion") == "orun.io/v1", "card apiVersion must be orun.io/v1")
check(card.get("kind") == "Blueprint", "card kind must be Blueprint")
check(card["metadata"]["name"] == build["metadata"]["name"],
      "card and build disagree on metadata.name")
check(spec["source"].get("repo") == "sourceplane/start-from-scratch", "spec.source.repo must be sourceplane/start-from-scratch")
check("tag" not in spec["source"], "spec.source must not declare a tag: the registry pins it")

# The build document the card names exists and is this one.
check(spec["bootstrap"]["blueprint"] == "repo-blueprint.yaml",
      "spec.bootstrap.blueprint must name repo-blueprint.yaml")
check("briefPath" not in spec["bootstrap"] and "umbrella" not in spec["bootstrap"],
      "a blueprint-driven card names no brief and no umbrella")

# Inputs: every card input is a build input, and every required build input
# with no default is either asked by the card or derived by it.
build_inputs = build.get("inputs", {})
card_keys = [i["key"] for i in spec["inputs"]]
for key in card_keys:
    check(key in build_inputs, f'card input "{key}" is not a build input')
    check(key == key.lower(), f'card input "{key}" must be lowercase')
for i in spec["inputs"]:
    check("pattern" in i, f'card input "{i["key"]}" carries no pattern')
for key, decl in build_inputs.items():
    if decl.get("required") and "default" not in decl:
        check(key in card_keys, f'build input "{key}" is required and the card does not supply it')

# Programme: the epic, its milestones in order, against the run-level hooks
# and the phases.
pre = build.get("hooks", {}).get("preInstantiate", [])
epics = [h for h in pre if h.get("with", {}).get("kind") == "epic"]
milestones = [h["with"]["name"] for h in pre if h.get("with", {}).get("kind") == "milestone"]
tasks = [h for h in pre if h.get("with", {}).get("kind") == "task"]
phases = [p["name"] for p in build["phases"]]
programme = spec["programme"]
check(len(epics) == 1, "the build must open exactly one epic")
check(programme["epicSlug"] == build_inputs["epicSlug"]["default"],
      "programme.epicSlug must be the build's epicSlug default")
check([m["name"] for m in programme["milestones"]] == milestones,
      f"programme.milestones {programme['milestones']} != the build's milestones {milestones}")
check(milestones == phases, f"milestones {milestones} != phases {phases}")
check(len(tasks) == len(phases), "one task per phase")

# Every task the build opens, up front or in a phase, names a contract that
# exists, and the phase's task is the one opened up front (same title).
up_front = {(t["with"]["milestone"], t["with"]["name"]) for t in tasks}
for t in tasks:
    check(os.path.isfile(t["with"]["contract"]), f'contract {t["with"]["contract"]} is missing')
for p in build["phases"]:
    for h in p.get("hooks", {}).get("post", []):
        w = h.get("with", {})
        if h.get("uses") == "orun.task/ensure@v1":
            check(os.path.isfile(w["contract"]), f'contract {w["contract"]} is missing')
            check((p["name"], w["name"]) in up_front,
                  f'phase {p["name"]} lands task "{w["name"]}", which the run-level list does not open')

# Minutes: the card's estimate is the sum of the phases'.
total = sum(p["expectedMinutes"] for p in build["phases"])
check(spec["bootstrap"]["expectedMinutes"] == total,
      f"bootstrap.expectedMinutes {spec['bootstrap']['expectedMinutes']} != the phases' sum {total}")

# Providers: what the phases wait for is what the card requires.
probed = set()
for p in build["phases"]:
    for probe in p.get("requires", {}).get("probe", []):
        if probe.get("uses") == "orun.doctor/check@v1":
            probed.update(probe["with"]["providers"])
check(set(spec["requires"]["integrations"]) == probed,
      f"requires.integrations {spec['requires']['integrations']} != the probed providers {sorted(probed)}")

# Secrets: none minted, none previewed.
minted = [h for p in build["phases"] for h in p.get("hooks", {}).get("post", [])
          if h.get("uses") == "orun.integrations/reconcile@v1"]
check(not minted and not spec.get("secrets"), "this baseline mints no secrets and previews none")

# Every phase's modules exist and every module is placed by exactly one phase.
modules = {m["name"] for m in build["modules"]}
placed = [m for p in build["phases"] for m in p["modules"]]
check(sorted(placed) == sorted(modules), f"modules {sorted(modules)} vs placed {sorted(placed)}")

# The factory lanes never ship.
for lane in ("baseline.yml", "tag.yml"):
    check(f"**/.github/workflows/{lane}" in build.get("ignore", []), f"{lane} must be in ignore")

if problems:
    for p in problems:
        print(f"✕ {p}", file=sys.stderr)
    sys.exit(1)
print("manifest.test.sh: ok")
PY
