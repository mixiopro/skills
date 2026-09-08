#!/usr/bin/env bash
set -euo pipefail

workspace='skills/mixio-workspace/SKILL.md'
require() { rg -Fq -- "$2" "$1" || { echo "missing: $2 in $1" >&2; exit 1; }; }
forbid() { ! rg -Fq -- "$2" "$1" || { echo "forbidden: $2 in $1" >&2; exit 1; }; }

require "$workspace" "public_https_resolve()"
require "$workspace" "--proto '=https'"
require "$workspace" "--proto-redir '=https'"
require "$workspace" '--max-filesize "$max_bytes"'
require "$workspace" 'ulimit -f 204800'
require "$workspace" 'curl --fail --silent --show-error --location --max-redirs 0'
require 'skills/mixio-references/SKILL.md' 'safe external-media recipe'
require 'skills/mixio-generate/SKILL.md' 'safe external-media recipe'
require 'skills/mixio-sheets/SKILL.md' 'safe external-media recipe'
forbid 'skills/mixio-references/SKILL.md' 'curl --fail'
forbid 'skills/mixio-generate/SKILL.md' 'curl --fail'
forbid 'skills/mixio-sheets/SKILL.md' 'curl --fail'

echo 'OK: external-media fallback is centralized and hardened'
