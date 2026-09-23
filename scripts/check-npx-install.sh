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

audit_home="$(mktemp -d)"
cleanup() {
  rm -rf -- "$audit_home"
}
trap cleanup EXIT

screenplay_root="$root/skills/how-to-make-script"

skill_manifest() {
  local directory="$1"
  local skill_dir

  for skill_dir in "$directory"/*; do
    if [ -f "$skill_dir/SKILL.md" ]; then
      basename "$skill_dir"
    fi
  done | sort
}

package_file_manifest() {
  local directory="$1"

  (
    cd "$directory"
    find . -type f \
      ! -path './.git/*' \
      ! -path './.pytest_cache/*' \
      ! -path '*/__pycache__/*' \
      | sort
  )
}

list_has_skill() {
  local listing="$1"
  local expected="$2"

  awk -v expected="$expected" '
    {
      line = $0
      sub(/\r$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "│    " expected) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$listing"
}

root_listing="$audit_home/root-listing.txt"
full_listing="$audit_home/full-listing.txt"
source_root_manifest="$audit_home/source-root-skills.txt"
source_route_manifest="$audit_home/source-screenplay-routes.txt"

npx --yes "skills@$skills_cli_version" add "$root" --list >"$root_listing" 2>&1
npx --yes "skills@$skills_cli_version" add "$root" --full-depth --list >"$full_listing" 2>&1

skill_manifest "$root/skills" >"$source_root_manifest"
skill_manifest "$screenplay_root/skills" >"$source_route_manifest"

while IFS= read -r skill; do
  if ! list_has_skill "$root_listing" "$skill"; then
    echo "ERROR: root npx discovery is missing exact skill entry $skill" >&2
    exit 1
  fi
done <"$source_root_manifest"

while IFS= read -r route; do
  if ! list_has_skill "$full_listing" "$route"; then
    echo "ERROR: full-depth npx discovery is missing exact route entry $route" >&2
    exit 1
  fi
done <"$source_route_manifest"

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
test -f "$HOME/.agents/skills/mixio-screenwriting/SKILL.md"

installed_root_manifest="$audit_home/installed-root-skills.txt"
skill_manifest "$HOME/.agents/skills" >"$installed_root_manifest"
if ! diff -u "$source_root_manifest" "$installed_root_manifest"; then
  echo "ERROR: npx installed root skill set differs from the source package" >&2
  exit 1
fi

source_package_manifest="$audit_home/source-screenplay-files.txt"
installed_package_manifest="$audit_home/installed-screenplay-files.txt"
package_file_manifest "$screenplay_root" >"$source_package_manifest"
package_file_manifest "$installed_root" >"$installed_package_manifest"
if ! diff -u "$source_package_manifest" "$installed_package_manifest"; then
  echo "ERROR: npx installed screenplay file set differs from the source package" >&2
  exit 1
fi

while IFS= read -r relative_path; do
  if ! cmp -s "$screenplay_root/$relative_path" "$installed_root/$relative_path"; then
    echo "ERROR: npx installed screenplay file differs from source: $relative_path" >&2
    exit 1
  fi
done <"$source_package_manifest"

echo "OK: skills@$skills_cli_version discovered root/full-depth routes and copied the owned screenplay system"
