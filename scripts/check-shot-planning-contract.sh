#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

planning='skills/mixio-shot-planning/SKILL.md'
audit='skills/mixio-shot-planning/references/execution-audit.md'

require() { rg -Fq "$2" "$1" || { echo "missing: $2 in $1" >&2; exit 1; }; }
forbid() { ! rg -Fq "$2" "$1" || { echo "forbidden: $2 in $1" >&2; exit 1; }; }

require "$planning" 'one of `4`/`6`/`8`/`10`/`12` frames'
require "$planning" 'step_05: "awaiting_approval"'
require "$planning" 'budget_approval.status: "approved"'
require "$planning" 'prompt contains tag zero times'
require "$planning" 'Resolved project and episode scope'
require "$audit" 'scene-anchor reference → derived keyframe'
require "$audit" 'Keyframe submissions:                 15'
require "$audit" 'Video generation jobs:                13'
require "$audit" 'plan changed while approval was pending'
require 'skills/mixio-pipeline/SKILL.md' 'model, generation use case, and input contract all match'
forbid "$planning" 'zero times or more than once'
forbid "$planning" 'Scene anchor crop'

echo 'OK: shot-planning contract is internally consistent'
