#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

loop="skills/mixio-pipeline/references/screenplay-reference-loop.md"
pipeline="skills/mixio-pipeline/SKILL.md"
episode="skills/mixio-episode/SKILL.md"
grammar="skills/mixio-episode/references/screenplay-grammar.md"
breakdown="skills/mixio-script-breakdown/SKILL.md"
schema="skills/mixio-script-breakdown/references/canonical-schema.md"
audit_proof="skills/mixio-script-breakdown/references/persistence-and-audit.md"
references="skills/mixio-references/SKILL.md"
audit="skills/mixio-reference-audit/SKILL.md"
ralph="skills/mixio-pipeline/references/pre-production-ralph-loop.md"
agents="AGENTS.md"
sheets="skills/mixio-sheets/SKILL.md"
shot_grammar="skills/mixio-pipeline/references/shot-grammar.md"

require() {
  local file="$1"
  local text="$2"
  if ! fixed_match "$file" "$text"; then
    echo "MISSING: $file does not contain: $text" >&2
    exit 1
  fi
}

forbid() {
  local file="$1"
  local text="$2"
  if fixed_match "$file" "$text"; then
    echo "FORBIDDEN: $file still contains: $text" >&2
    exit 1
  fi
}

fixed_match() {
  local file="$1"
  local text="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -Fq -- "$text" "$file"
  else
    grep -Fq -- "$text" "$file"
  fi
}

require "$loop" 'studio_update_reference({ projectId, referenceId,'
require "$loop" 'studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline:'
require "$loop" 'studio_register_reference_entities({ projectId, references:'
require "$loop" 'studio_upsert_screenplay({ projectId, episodeId, body })'
require "$loop" 'Zero authored `#` tokens are unmapped'
require "$loop" 'workflow.status: "approved"'
require "$loop" 'Props are part of the Step 01 inventory'
require "$loop" 'insert the copied token at the relevant slugline'
require "$loop" 'explicit user-approved `TEXT-ONLY`'
require "$loop" 'mentionableLooks[].views[].mention'
require "$loop" 'dispositions: ['
require "$loop" '`classification` (`LOCATION_TEXT_ONLY`'
require "$pipeline" 'Step 01'
require "$pipeline" 'zero authored `#` character, location, or prop tokens are unmapped'
require "$pipeline" 'required refs/looks approved'
require "$pipeline" 'props_pending: 0'
require "$pipeline" 'all named dispositions approved'
require "$episode" 'normalize it into `SCREENPLAY` before breakdown'
require "$grammar" 'character, location, or prop'
require "$breakdown" 'a non-empty SCREENPLAY is required for the `mixio-pipeline` production path'
require "$breakdown" 'Production-mode gate'
require "$breakdown" 'mode == "TEXT_ONLY"'
require "$schema" 'approved Step 01 disposition'
require "$audit_proof" 'approvedTextOnly'
require "$references" '`workflow.status`: `draft` | `in_review` | `approved`'
require "$references" 'Approval before closing a screenplay loop'
require "$audit" 'Read the episode'
require "$audit" 'SCREENPLAY'
require "$audit" 'metadata.pipeline.screenplay_loop.dispositions'
require "$audit" 'missing or empty `SCREENPLAY` is a blocking'
require "$ralph" 'story-critical props'
require "$ralph" 'approved a source rewrite/TEXT-ONLY disposition'
require "$agents" 'resolve every authored `#` token'
require "$sheets" 'workflow.status: "approved"'
require "$sheets" 'named approved `TEXT_ONLY` dispositions'
require "skills/mixio-continuity/SKILL.md" 'named approved `TEXT_ONLY` dispositions'
require "$shot_grammar" 'distinct from a Step 01 `mode: "TEXT_ONLY"` entity disposition'

forbid "$loop" 'Props are deliberately outside the exit condition.'
forbid "$loop" 'drop the mention'
forbid "$loop" 'leave it out'
forbid "$pipeline" 'until zero character and location tokens are unmapped'
forbid "$pipeline" 'register/render the misses'
forbid "$sheets" 'skip <location>'
forbid "$sheets" 'note skips as TEXT-ONLY'
forbid "$sheets" 'No reference image → header gets `(TEXT-ONLY)`'
forbid "$breakdown" 'fill missing/weak metadata from the raw script'
forbid "$breakdown" 'fullScript only when no screenplay body exists'

echo 'OK: screenplay/reference loop token, prop, approval, and scope contracts are consistent'
