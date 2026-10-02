---
name: mixio-reference-audit
description: "Use when checking whether a Mixio project’s existing references, images, metadata, or look bindings are ready for a shot plan’s production."
version: 0.3.0
invoke: /mixio:reference-audit
---

# Mixio Reference Audit

Step 04 of `mixio-pipeline`. It audits the accepted shot plan against the project’s existing Cast & World and images. The question it answers: **are the references this episode will generate against actually ready?** Missing items are reported as production-readiness gaps; they do not block local planning.

A missing character image found here costs one upload. The same gap found in Step 06 costs every shot that character appears in — re-generated blind, or blocked until someone notices.

Use the shared [director’s lens](../mixio-pipeline/references/directors-lens.md): readiness and consistency are judged against the accepted shot intent, not abstract completeness alone. Report a conflict between a canonical reference and approved direction for review; do not resolve it by silently rewriting either one.

## Prerequisites

- The accepted local shot plan or a persisted episode to audit
- A project with references registered (`mixio-references`); available images and sheets may be incomplete

## What it checks

Six categories, run in order. Each produces a finding list; the gate is at the end.

### 1. Completeness — planned shot demand vs reference supply

Use the accepted shot table as the demand list, and consult the selected screenplay source for exact names and aliases. Read a non-empty native `SCREENPLAY` body first; use episode `script` / `metadata.fullScript` only as fallback. Cross-reference entities against `studio_list_references({ projectId })`.

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

Resolution plan:
- Merge duplicates: identify the canonical name and the alias to preserve; present the proposal for review, then route an approved update to `mixio-references`, which reads `settings.references` before writing.
- Convert variant-as-ref: identify the parent reference and its candidate look; hand the plan to `mixio-references` for a policy-safe migration. Do not delete a reference from this audit.

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

Pull bindings from `studio_get_production_context`'s `lookBindings` (or `studio_query_relations`
per relation). Pass relation `metadata` as a native object, never a JSON-stringified string, and
cross-reference each `lookRef` against the target reference's `referenceVariants[].id` / `.name`.

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
Planned entities:      15

Completeness:          2 MISSING_REF, 1 MISSING_IMAGE_HIGH_USAGE
Consistency:           1 GENDER_MISMATCH (advisory)
Duplicates:            1 LIKELY_DUPLICATE, 1 ALIAS_CANDIDATE
Metadata quality:      2 HIGH-severity gaps
Policy:                0 violations
Look bindings:         1 STALE_LOOK_REF

BLOCKING findings (must resolve before generation):
  ❌ HALLWAY DOORWAY — MISSING_REF — appears in 4 planned shots, 0 references
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
| BLOCKING | Generation-readiness issue. Resolve or explicitly accept before shot planning/generation; it does not block local planning or the reviewed breakdown sync |
| ADVISORY | Surface for human decision; it does not block local planning |

**Blocking criteria:**
- Any `MISSING_REF` for an entity appearing in ≥2 shots
- Any `MISSING_IMAGE_HIGH_USAGE`
- Any HIGH-severity metadata gap on a character appearing in ≥1 scene — a missing `visualAnchor` means every prompt mentioning that character lacks its identity anchor, no matter how few scenes it appears in
- Any HIGH-severity metadata gap on a location appearing in ≥1 scene — `setting` and `lighting` are required to render the scene's anchor frame without guessing
- Any `GENDER_MISMATCH` confirmed by both text and vision (not advisory-only)
- Any `STALE_LOOK_REF` — it renders the wrong look silently, with nothing in the UI to catch it before delivery

Everything else is advisory. Record any user decision in the review notes for this run; do not write audit metadata as a side effect of the read-only audit.

### Enrichment completion gate (before generation)

Before generation, confirm that `mixio-sheets` populated the load-bearing fields, not just reference metadata. The local breakdown does not create or enrich references. HIGH-severity fields must be present on every character/location the accepted plan uses:

**Characters — `characterDetails` (via `studio_update_reference`):**
| Field | Required |
|-------|----------|
| `build` | yes |
| `hair` | yes |
| `skin` | yes |
| `visualAnchor` | **yes** — the identity anchor, non-negotiable |

**Locations — `locationDetails` (via `studio_update_reference`):**
| Field | Required |
|-------|----------|
| `setting` | **yes** |
| `lighting` | **yes** |
| `spatialLayout` | yes |
| `depthAxes` | yes |

These are the fields prompt materializers rely on for visual continuity. If any are missing, report a generation blocker and direct the fix to `/mixio:sheets`; do not block the local plan or silently write a stub.

## Findings and remediation

This is a read-only audit. Emit the exact remediation proposal and stop before changing references, relations, media, or episode metadata. The pipeline does not run an automatic reference-repair loop.

For any approved remediation, route to `/mixio:references` or `/mixio:sheets`, read current `settings.references`, and show the exact proposed changes before writing. Follow `createPolicy`, `variantPolicy`, and `variantVocabulary`.

`MISSING_IMAGE_HIGH_USAGE` has no zero-credit synthetic fix. Report whether a supplied image can be attached; otherwise request an upload or explicit image-generation permission. This audit never uploads media or submits a generation job.

The remediation plan identifies the required action:

```
Fix: HALLWAY DOORWAY — MISSING_REF
→ propose `{ type: "LOCATION", name: "HALLWAY DOORWAY", metadata: { description: "..." } }`
  Then: approve the reference change; use /mixio:sheets for any required image work

Fix: TONY — missing visualAnchor
→ propose `characterDetails.visualAnchor = "Athletic Italian-American woman, late 20s, loose dark curls, warm olive skin"`

Fix: TONY ↔ TONY RUSSO — LIKELY_DUPLICATE
→ propose canonical name `TONY` with aliases `Tony Russo`, `Antonia`; confirm before merging or archiving

Fix: STALE_LOOK_REF — TONY'S APARTMENT:night
→ propose rebinding to the existing `evening` variant or restoring the `night` variant after confirmation
```

After an approved change, re-run this read-only audit. Keep its report in the local review unless the user separately approves an exact Studio metadata update.

## Workflow

```
1. read the accepted plan/source, current project policy, references, and attached images
2. compare planned cast, locations, props, and look bindings against existing data
3. run the six check categories and separate story-plan issues from generation-readiness gaps
4. emit the audit report and exact remediation proposals; make no writes
5. after separately approved remediation, re-read and re-run the audit before generation
```

## Notes

- Run after the local plan is accepted; it can also be used earlier to snapshot current readiness. Incomplete references never block local planning.
- Run again after sheets or reference changes. It is read-only and does not start image generation.
- The duplicate check uses normalized names (lowercased, stripped of punctuation, collapsed whitespace). `aliasMatching` in project settings controls whether recorded aliases participate in runtime matching; the audit checks aliases as data quality.
- On a project with 50+ references, emit the clean list as a count rather than naming each one. The blocking and advisory lists are what the user needs to act on.
