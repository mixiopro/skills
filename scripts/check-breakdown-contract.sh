#!/bin/bash
# Guards the documented composed-breakdown safety contract.
set -euo pipefail
cd "$(dirname "$0")/.."

breakdown=skills/mixio-script-breakdown/SKILL.md
audit=skills/mixio-script-breakdown/references/persistence-and-audit.md
preflight=skills/mixio-pipeline/references/preflight-settings.md
reference_audit=skills/mixio-reference-audit/SKILL.md

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
require "$reference_audit" 'non-empty screenplay `body`, including drafts'
require "$reference_audit" 'only when no usable screenplay body exists'
require "$breakdown" 'confirmed CHARACTER row maps the screenplay'
require "$breakdown" 'Never choose a variant by fuzzy text similarity'
require "$breakdown" 'use the composed path so it can write the explicit `lookRef`'
require "$breakdown" 'REQUIRED_LOOK_UNBOUND'
require "$reference_audit" 'REQUIRED_LOOK_UNBOUND'
require "$reference_audit" 'SCRIPT_REQUIREMENT_UNMAPPED'
require "$reference_audit" 'REFERENCE_PACK_INVENTORY_MISSING'
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
