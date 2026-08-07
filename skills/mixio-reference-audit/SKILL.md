---
name: mixio-reference-audit
description: "Audit a project's Cast & World roster for completeness, consistency, duplicates, and metadata quality before generation — catch reference problems that cost re-renders when found late. Audits what already exists — building the sheets is mixio-sheets, creating/editing entries is mixio-references. Unclear which step you need → mixio-pipeline."
version: 0.2.0
invoke: /mixio:reference-audit
---

# Mixio Reference Audit

Step 02.5 of `mixio-pipeline`. Runs after sheets (Step 02) and before the panel breakdown (Step 03). The question it answers: **are the references this episode will generate against actually ready?**

A missing character image found here costs one upload. The same gap found in Step 06 costs every shot that character appears in — re-generated blind, or blocked until someone notices.

## Prerequisites

- A project with references registered (`mixio-references`)
- A script persisted on the episode (Step 01)
- Ideally, sheets already built (Step 02) — but the audit is valuable even without them

## What it checks

Six categories, run in order. Each produces a finding list; the gate is at the end.

### 1. Completeness — script demand vs reference supply

Extract every CAPS entity from the persisted script (`studio_get_episode` → `script`). Cross-reference against `studio_list_references({ projectId })`.

**Judge `MISSING_IMAGE` by `hasImage` — never by `thumbnailUrl`/`previewUrl`.** `list_references` returns `thumbnailUrl`/`previewUrl` alongside it, and it's easy to grab the wrong pair: those two are a card-preview column that nothing populates when a Look is attached, so a reference with real turnaround images routinely still shows both as `null`. Reading those as the presence signal produces a false `MISSING_IMAGE` on every reference in the project — a wrong blocking finding on the roster's healthiest data, not its worst. `hasImage` (see `mixio-references`) is the real signal.

| Finding | Meaning |
|---------|---------|
| `MISSING_REF` | Entity mentioned in script has no matching reference element at all |
| `MISSING_IMAGE` | Reference exists but `hasImage` is false |
| `MISSING_IMAGE_HIGH_USAGE` | Same, but the entity appears in ≥3 shots or ≥2 scenes — generation will be inconsistent without a visual anchor |
| `NO_PRIMARY_LOOK` | Reference has variant images but none marked `isPrimary` or `isDefault` — prompt assembly picks arbitrarily |

```
Completeness — 12 references checked
  ✅ TONY         — 1 primary look, 3 images
  ✅ POPPY        — 1 primary look, 2 images
  ⚠️  CEREAL BOWL — MISSING_IMAGE (appears in 2 shots)
  ❌ HALLWAY DOORWAY — MISSING_REF (mentioned 4× in script)
```

### 2. Consistency — name/description vs image alignment

For each reference that has both structured details and at least one image, check for contradictions:

| Finding | Meaning |
|---------|---------|
| `GENDER_MISMATCH` | `characterDetails` implies one gender but attached image presents as another |
| `AGE_MISMATCH` | Description says "child" / "elderly" but image shows a different age bracket |
| `BUILD_MISMATCH` | `build` field contradicts what the image shows |
| `DESCRIPTION_CONFLICT` | `description` or `visualAnchor` text contradicts visible features in the primary image |

This check is **advisory, not blocking** — it requires visual interpretation which may be wrong. Flag for human review rather than auto-fixing.

Implementation: if the agent has vision capabilities, describe the primary image and compare against `characterDetails.build`, `.age`, `.hair`, `.skin`, `.distinctiveFeatures`. If no vision, skip this category and note `Consistency checks skipped — no vision capability available`.

### 3. Duplicates — fuzzy matching across the roster

| Finding | Meaning |
|---------|---------|
| `LIKELY_DUPLICATE` | Two references of the same type with names within edit distance 2, or one name is a substring of another |
| `ALIAS_CANDIDATE` | Script uses a name that matches an existing reference's description/bio but not its canonical name — likely an alias |
| `VARIANT_CONFUSED_AS_REF` | A reference whose name looks like `CHARACTER (state)` — e.g. `TONY (gala)` — which should be a variant, not a separate element |

```
Duplicates — 12 references checked
  ⚠️  LIKELY_DUPLICATE: "TONY" (CHARACTER) ↔ "TONY RUSSO" (CHARACTER) — same entity?
  ⚠️  ALIAS_CANDIDATE: script mentions "Antonia" — matches TONY's bio but no alias recorded
  ⚠️  VARIANT_CONFUSED_AS_REF: "TONY (GALA)" is a separate CHARACTER — should be a variant of TONY
```

Resolution actions:
- Merge duplicates: pick the canonical name, add the other as an alias via `studio_update_element({ metadata: { aliases: [...] } })`
- Convert variant-as-ref: delete the spurious reference, add as a `referenceVariant` on the parent with `studio_update_reference({ referenceVariants })`

### 4. Metadata quality — structured detail completeness

For each reference type, check the fields that downstream steps depend on:

**Characters** — generation needs these for consistent prompts:
| Field | Severity |
|-------|----------|
| `visualAnchor` | HIGH — the one-line visual identity used in every prompt |
| `build` | MEDIUM |
| `hair` | MEDIUM |
| `skin` | MEDIUM |
| `distinctiveFeatures` | LOW |
| `wardrobeNotes` | LOW |

**Locations** — sheets and anchors need these:
| Field | Severity |
|-------|----------|
| `setting` | HIGH |
| `lighting` | HIGH — anchor generation without this guesses |
| `palette` | MEDIUM |
| `mood` | LOW |

**Props** — less critical but helps consistency:
| Field | Severity |
|-------|----------|
| `category` | LOW |
| `material` | LOW |
| `significance` | LOW |

```
Metadata quality — 12 references
  ❌ TONY (CHARACTER): missing visualAnchor, hair
  ⚠️  APARTMENT (LOCATION): missing lighting, palette
  ✅ POPPY (CHARACTER): all HIGH/MEDIUM fields present
```

### 5. Policy compliance

Read `projects.settings.references` from `studio_get_project` and verify:

| Finding | Meaning |
|---------|---------|
| `POLICY_VIOLATION_CREATE` | Reference was created under `createPolicy: link_only` — should have been linked, not created |
| `VARIANT_VOCAB_VIOLATION` | A variant name exists outside the `variantVocabulary` set |
| `ALIAS_MATCHING_DISABLED` | Aliases are recorded but `aliasMatching` is false — they won't participate in breakdown matching |

This category is informational when the project has no policy set (the defaults are permissive).

### 6. Look-binding integrity — bound looks resolve to a real variant

A shot or scene can bind a reference's look via `lookRef` on its `appears_in`/`presence` relation (`mixio-script-breakdown`). That binding degrades silently to the reference's default variant when it doesn't resolve — no error, no visible sign in the UI — so this is the one check that catches a wrong render before it happens rather than after.

Pull bindings from `studio_get_production_context`'s `lookBindings` (or `query_relations` per relation), and cross-reference each `lookRef` against the target reference's `referenceVariants[].id` / `.name`.

| Finding | Meaning |
|---------|---------|
| `STALE_LOOK_REF` | `lookRef` names a variant id/name that no longer exists on the reference — renamed or deleted since the binding was made |

```
Look-binding integrity — 4 bindings checked
  ✅ Shot 7  → TONY:formal
  ❌ Scene 2 → TONY'S APARTMENT:night — STALE_LOOK_REF, no variant named "night" (renamed to "evening")
```

Resolution: rebind to the current variant name/id, or restore the variant under its old name.

## Report format

```
REFERENCE AUDIT — Project "Brooklyn Stories" — Episode 3
═══════════════════════════════════════════════════════════

References checked:    12 (6 CHARACTER, 4 LOCATION, 2 PROP)
Script entities:       15

Completeness:          2 MISSING_REF, 1 MISSING_IMAGE_HIGH_USAGE
Consistency:           1 GENDER_MISMATCH (advisory)
Duplicates:            1 LIKELY_DUPLICATE, 1 ALIAS_CANDIDATE
Metadata quality:      2 HIGH-severity gaps
Policy:                0 violations
Look bindings:         1 STALE_LOOK_REF

BLOCKING findings (must resolve before Step 03):
  ❌ HALLWAY DOORWAY — MISSING_REF — appears in 4 script lines, 0 references
  ❌ CEREAL BOWL — MISSING_IMAGE_HIGH_USAGE — 2 shots depend on this prop
  ❌ TONY — missing visualAnchor — every prompt mentioning TONY will lack identity anchor

ADVISORY findings (review recommended):
  ⚠️  TONY — GENDER_MISMATCH — characterDetails.build="athletic female" but primary image presents male
  ⚠️  "TONY" ↔ "TONY RUSSO" — LIKELY_DUPLICATE
  ⚠️  script mentions "Antonia" — ALIAS_CANDIDATE for TONY

CLEAN references: POPPY, BED, BEDSIDE TABLE, NAPOLI POSTER, TABLET, PHONE, PERSIAN RUG
```

## Severity and gating

| Severity | Gate behavior |
|----------|--------------|
| BLOCKING | Must be resolved before proceeding to Step 03. Generation without these will fail or produce inconsistent results |
| ADVISORY | Surfaced for human decision. May proceed, but the user should explicitly acknowledge |

**Blocking criteria:**
- Any `MISSING_REF` for an entity appearing in ≥2 shots
- Any `MISSING_IMAGE_HIGH_USAGE`
- Any HIGH-severity metadata gap on a character appearing in ≥3 shots
- Any `GENDER_MISMATCH` confirmed by both text and vision (not advisory-only)
- Any `STALE_LOOK_REF` — it renders the wrong look silently, with nothing in the UI to catch it before delivery

Everything else is advisory. The user may say "proceed anyway" — record that decision in metadata so a later session knows it was acknowledged, not missed.

## Fixing findings

For each blocking finding, suggest the specific action:

```
Fix: HALLWAY DOORWAY — MISSING_REF
→ studio_register_reference_entities({ projectId, references: [
    { type: "LOCATION", name: "HALLWAY DOORWAY", metadata: { description: "..." } }
  ]})
  Then: upload or generate a reference image via /mixio:sheets

Fix: TONY — missing visualAnchor
→ studio_update_reference({ referenceId: "<tony-id>",
    characterDetails: { visualAnchor: "Athletic Italian-American woman, late 20s, loose dark curls, warm olive skin" }
  })

Fix: TONY ↔ TONY RUSSO — LIKELY_DUPLICATE
→ studio_update_element({ elementId: "<tony-id>", updates: { metadata: {
    aliases: ["Tony Russo", "Antonia"]
  }}})
  Then: archive or delete the duplicate reference
```

## Persisting the result

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  step_02_5: "complete",
  reference_audit: {
    checked: 12,
    blocking: 3,
    advisory: 3,
    clean: 7,
    acknowledged_advisories: ["GENDER_MISMATCH:TONY"],
    timestamp: "2025-..."
  }
}}}})
```

## Workflow

```
1. studio_get_episode({ episodeId })                  → get persisted script
2. extract CAPS entities from script text             → demand list
3. studio_list_references({ projectId })              → supply list
4. studio_get_project({ projectId })                  → read reference policy
5. run 6 check categories                            → findings
6. emit REFERENCE AUDIT report
7. if BLOCKING findings: present fixes, wait for resolution, re-check
8. if ADVISORY only: present, get acknowledgment
9. persist audit result → GATE → Step 03 Panel Breakdown
```

## Notes

- Run this **after** sheets (Step 02) because sheets create the bulk of the reference images. Running before sheets would flag every reference as `MISSING_IMAGE`.
- Re-run after any reference change in a later step. It's free (reads only) and a stale audit means a stale contract.
- The duplicate check uses normalized names (lowercased, stripped of punctuation, collapsed whitespace). `aliasMatching` in project settings controls whether recorded aliases participate in *breakdown* matching — the audit checks aliases regardless, because it's looking for data quality, not runtime behavior.
- On a project with 50+ references, emit the clean list as a count rather than naming each one. The blocking and advisory lists are what the user needs to act on.
