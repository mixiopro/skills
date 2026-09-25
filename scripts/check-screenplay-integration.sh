#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bridge="$root/skills/mixio-screenwriting/SKILL.md"
handoff="$root/skills/mixio-screenwriting/references/screenplay-handoff.md"
screenplay_root="$root/skills/how-to-make-script"

required_routes=(
  idea-discovery
  logline-premise
  character-world
  structure-beat
  scene-writing
  dialogue-subtext
  rewrite-doctor
  quality-gating
)

required_handoff_keys=(
  medium
  logline
  premise
  character_world
  structure
  screenplay
  quality_gate
  constraints
)

test -f "$bridge"
test -f "$handoff"
test -f "$screenplay_root/SKILL.md"
test -f "$screenplay_root/LICENSE"
test -f "$screenplay_root/UPSTREAM.md"
grep -q "how-to-make-script" "$bridge"
grep -q "screenplay-handoff" "$bridge"
grep -q "68d179210687172d6c77b84e7c7d8d29ca865139" "$screenplay_root/UPSTREAM.md"
for route in "${required_routes[@]}"; do
  grep -q "\`$route\`" "$bridge"
  test -f "$screenplay_root/skills/$route/SKILL.md"
done
test -d "$screenplay_root/knowledge/20-workflows"
test -d "$screenplay_root/knowledge/60-rubrics"
test -d "$screenplay_root/references"
test -d "$screenplay_root/schemas"
test -d "$screenplay_root/examples"
test -d "$screenplay_root/tests"
for route in "${required_routes[@]}"; do
  test -f "$screenplay_root/skills/$route/manifest.json"
done
for handoff_key in "${required_handoff_keys[@]}"; do
  grep -q "^$handoff_key:" "$handoff"
done
grep -q "screenplay-grammar.md" "$handoff"
grep -q "studio_upsert_screenplay" "$handoff"
grep -q "how-to-make-script" "$root/README.md"
grep -q "how-to-make-script" "$root/AGENTS.md"
grep -q "how-to-make-script" "$root/install.sh"
grep -q "how-to-make-script" "$root/install.ps1"
grep -q "SCREENPLAY_SKILL_NAME" "$root/install.sh"
grep -q "ScreenplaySkillName" "$root/install.ps1"

echo "OK: screenplay development integration is owned and documented"
