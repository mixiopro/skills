#!/bin/bash
# Guards the documented composed-breakdown safety contract.
set -euo pipefail
cd "$(dirname "$0")/.."

breakdown=skills/mixio-script-breakdown/SKILL.md
audit=skills/mixio-script-breakdown/references/persistence-and-audit.md
preflight=skills/mixio-pipeline/references/preflight-settings.md

require() {
  if ! rg -Fq "$2" "$1"; then
    echo "MISSING: $2 in $1" >&2
    exit 1
  fi
}

forbidden() {
  if rg -q "$2" "$1"; then
    echo "FORBIDDEN: $2 in $1" >&2
    exit 1
  fi
}

require "$breakdown" 'createPolicy: propose'
require "$breakdown" 'createPolicy: link_only'
require "$audit" 'no reference, package, or relation write'
require "$audit" 'const aliasMatching = settings.references?.aliasMatching === true'
require "$audit" 'studio_query_relations'
require "$audit" 'canonicalFieldFailures'
require "$audit" 'expectedShotCount'
require "$preflight" 'IMAGE: confirmed.deliveryAspectRatio'
forbidden "$breakdown" 'planned_runtime'
forbidden "$audit" 'planned_runtime'

node <<'NODE'
const asArray = value => Array.isArray(value) ? value : value ? [value] : []
const namesFor = (item, aliasMatching) => [
  item.name,
  ...(aliasMatching ? [...asArray(item.aka), ...asArray(item.aliases)] : [])
]
const reference = { name: 'TONY', aka: ['ANTONIA'], aliases: ['T'] }
if (namesFor(reference, false).join(',') !== 'TONY') process.exit(1)
if (namesFor(reference, true).join(',') !== 'TONY,ANTONIA,T') process.exit(1)
NODE

echo 'OK: breakdown policy, alias matching, persisted audit, and delivery-ratio contracts present'
