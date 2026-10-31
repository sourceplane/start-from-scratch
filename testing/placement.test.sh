#!/usr/bin/env bash
# The offline bootstrap: the phase placed by the orun on PATH, with no hooks,
# and what a new repository would receive held to exactly four files.
#
#   - the tracked set is intent.yaml, README.md, .gitignore and ci.yml —
#     nothing of the factory (the cards, .baseline/, testing/, the factory
#     lanes) and none of orun's local state;
#   - every template rendered: no `{{` left in what was placed;
#   - the intent is valid and plans, as the repository's own CI will plan it
#     on the merge: zero components, zero jobs;
#   - this repository's own intent.yaml is the template rendered for itself,
#     so the two cannot drift.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "✕ $*" >&2; exit 1; }

place() { # out reponame productname githuborg workspace
  orun new --blueprint repo-blueprint.yaml --out "$1" --resume \
    --set "reponame=$2" --set "productname=$3" --set "githuborg=$4" \
    --set "orunWorkspace=$5" >/dev/null
}

# ── A product ─────────────────────────────────────────────────────────────
OUT="$WORK/acme"
place "$OUT" acme "Acme & Co's" Acme-Inc ws_test123
(
  cd "$OUT"
  git init -q
  git add -A
  got="$(git ls-files | sort | tr '\n' ' ')"
  want=".github/workflows/ci.yml .gitignore README.md intent.yaml "
  [ "$got" = "$want" ] || fail "a new repository would carry: $got (want: $want)"

  if grep -rn '{{' intent.yaml README.md; then fail "an unrendered template action was placed"; fi
  grep -q '^  name: acme$' intent.yaml || fail "intent metadata.name is not the repo name"
  grep -q '^  namespace: acme-inc$' intent.yaml || fail "intent namespace is not the kebab-cased owner"
  grep -q '^    workspace: ws_test123$' intent.yaml || fail "intent workspace is not the build's workspace"
  grep -q "^# Acme & Co's$" README.md || fail "README is not titled for the product"
  cmp -s .github/workflows/ci.yml "$ROOT/.github/workflows/ci.yml" || fail "ci.yml was not copied verbatim"

  orun validate --intent intent.yaml >/dev/null || fail "the placed intent is not valid"
  orun plan --trigger github-push-main --env stage --intent intent.yaml \
    --output "$WORK/plan.json" --no-catalog-refresh >/dev/null || fail "the placed intent does not plan"
  [ "$(jq '.jobs | length' "$WORK/plan.json")" = 0 ] || fail "an empty repository planned jobs"
)

# ── No workspace anywhere: the loud placeholder, never ws_CHANGE_ME ────────
OUT="$WORK/nows"
place "$OUT" acme Acme acme ""
grep -q '^    workspace: ws_SET_ME$' "$OUT/intent.yaml" || fail "a build with no workspace must write ws_SET_ME"

# ── This repository's own intent is the template, rendered for itself ──────
OUT="$WORK/self"
place "$OUT" empty Empty sourceplane ws_CHANGE_ME
diff -u "$OUT/intent.yaml" intent.yaml || fail "intent.yaml is not .baseline/product/intent.yaml rendered for this repository"

echo "placement.test.sh: ok"
