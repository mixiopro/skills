#!/bin/bash
# Fails if the skill count drifts between skills/, README.md, and AGENTS.md.
# Catches the class of bug fixed by hand in "docs: fix stale skill count" (#8) —
# run this instead of trusting a human remembered to update every count.
set -euo pipefail
cd "$(dirname "$0")/.."

actual=$(find skills -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
badge=$(grep -oE 'skills-[0-9]+-blueviolet' README.md | grep -oE '[0-9]+')
readme_rows=$(grep -c '^| \[`mixio-' README.md)
agents_rows=$(grep -c '^| `mixio-' AGENTS.md)

fail=0
check() {
  if [ "$2" != "$actual" ]; then
    echo "MISMATCH: $1 = $2, but skills/ has $actual skill directories"
    fail=1
  fi
}

check "README badge"          "$badge"
check "README table rows"     "$readme_rows"
check "AGENTS.md table rows"  "$agents_rows"

if [ "$fail" = 0 ]; then
  echo "OK: $actual skills, consistent across skills/, README.md, AGENTS.md"
else
  exit 1
fi
