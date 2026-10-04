#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

planning='skills/mixio-shot-planning/SKILL.md'
audit='skills/mixio-shot-planning/references/execution-audit.md'

require() { rg -Fq "$2" "$1" || { echo "missing: $2 in $1" >&2; exit 1; }; }
forbid() { ! rg -Fq "$2" "$1" || { echo "forbidden: $2 in $1" >&2; exit 1; }; }

require "$planning" 'one of `4`/`6`/`8`/`10`/`12` frames'
require "$planning" 'step_05: "awaiting_approval"'
require "$planning" 'Video generation costs the most, image generation comes next'
require "$planning" 'prompt contains tag zero times'
require "$planning" 'Resolved project and episode scope'
require "$planning" 'REFERENCE_VARIANT_VIEW_NOT_READY'
require "$planning" 'REQUIRED_LOOK_UNBOUND'
require "$planning" 'confirmed non-default variant mapping'
require 'skills/mixio-pipeline/SKILL.md' 'stop before writing an awaiting-generation-approval summary'
require 'skills/mixio-pipeline/SKILL.md' 'Ask before video generation unless the user has said otherwise.'
require 'skills/mixio-pipeline/SKILL.md' 'restart Steps 03–05 because their outputs are stale'
require "$audit" 'scene-anchor reference → derived keyframe'
require "$audit" 'Keyframe submissions:                 15'
require "$audit" 'Video generation jobs:                13'
require "$audit" 'plan changed while approval was pending'
require 'skills/mixio-pipeline/SKILL.md' 'model, generation use case, and input contract all match'
forbid "$planning" 'zero times or more than once'
forbid "$planning" 'presented_credits'
forbid "$audit" 'presented_credits'
forbid "$audit" 'estimated_credits'
forbid "$planning" 'Scene anchor crop'

echo 'OK: shot-planning contract is internally consistent'
