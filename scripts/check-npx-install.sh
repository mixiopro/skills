#!/usr/bin/env bash
set -euo pipefail

# Verify the public npx skills contract without touching the caller's agent
# directories. This is the repository's equivalent of an npx skills audit:
# discover the package, discover nested routes, then install into a clean home.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_cli_version="${SKILLS_CLI_VERSION:-1.7.0}"

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx is required for the skills install check" >&2
  exit 1
fi

required_root_skills=(
  how-to-make-script
  mixio-screenwriting
)

required_screenplay_routes=(
  idea-discovery
  logline-premise
  character-world
  structure-beat
  scene-writing
  dialogue-subtext
  rewrite-doctor
  quality-gating
)

audit_home="$(mktemp -d)"
cleanup() {
  rm -rf -- "$audit_home"
}
trap cleanup EXIT

root_listing="$audit_home/root-listing.txt"
full_listing="$audit_home/full-listing.txt"

npx --yes "skills@$skills_cli_version" add "$root" --list >"$root_listing" 2>&1
npx --yes "skills@$skills_cli_version" add "$root" --full-depth --list >"$full_listing" 2>&1

for skill in "${required_root_skills[@]}"; do
  if ! grep -q -- "$skill" "$root_listing"; then
    echo "ERROR: root npx discovery is missing $skill" >&2
    exit 1
  fi
done

for route in "${required_screenplay_routes[@]}"; do
  if ! grep -q -- "$route" "$full_listing"; then
    echo "ERROR: full-depth npx discovery is missing $route" >&2
    exit 1
  fi
done

export HOME="$audit_home"
export CODEX_HOME="$audit_home/.codex"
export XDG_CONFIG_HOME="$audit_home/.config"
export NPM_CONFIG_CACHE="$audit_home/.npm"

npx --yes "skills@$skills_cli_version" add "$root" --global --yes --agent codex --copy \
  >"$audit_home/install.log" 2>&1

installed_root="$HOME/.agents/skills/how-to-make-script"
test -f "$installed_root/SKILL.md"
test -f "$installed_root/UPSTREAM.md"
test -f "$installed_root/LICENSE"

for route in "${required_screenplay_routes[@]}"; do
  test -f "$installed_root/skills/$route/SKILL.md"
done

for directory in \
  knowledge/20-workflows \
  knowledge/60-rubrics \
  references \
  schemas \
  examples \
  tests; do
  test -d "$installed_root/$directory"
done

echo "OK: skills@$skills_cli_version discovered root/full-depth routes and copied the owned screenplay system"
