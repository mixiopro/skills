---
name: mixio-reference-audit
description: "Audit script-required reference looks and views for visual readiness, plus Cast & World completeness, consistency, duplicates, and metadata quality before generation. Builds sheets: mixio-sheets; creates/edits entries: mixio-references. Unclear which step you need → mixio-pipeline."
version: 0.3.0
invoke: /mixio:reference-audit
---

# Mixio Reference Audit

Step 02.5 of `mixio-pipeline`. Runs after sheets (Step 02) and before the panel breakdown (Step 03), then runs again during Step 05 reconciliation if breakdown exposes camera zones missing from the confirmed matrix. The question it answers: **are the references this episode will generate against actually ready?**

A missing character image found here is one asset issue. The same gap found in Step 06 affects every shot that character appears in — re-generated blind, or blocked until someone notices.

## Prerequisites

- A project with references registered (`mixio-references`)
- A persisted native `SCREENPLAY` body or, if none is usable, episode fallback script (Step 01)
- Ideally, sheets already built (Step 02) — but the audit is valuable even without them

## What it checks

Seven categories, run in order. Each produces a finding list; the gate is at the end.

### 1. Completeness — script demand vs reference supply

Read the episode's native `SCREENPLAY` element and episode record. Extract every CAPS entity from the non-empty screenplay `body`, including drafts; use episode `script` / `metadata.fullScript` only when no usable screenplay body exists, following `screenplay-grammar.md`. Cross-reference against `studio_list_references({ projectId })`.

For a pipeline audit, require a present, confirmed `metadata.pipeline.reference_pack_inventory`; report `REFERENCE_PACK_INVENTORY_MISSING` and block if it is absent, unconfirmed, or empty before screenplay demand has been reconciled. Do not let a single image or `Default` look pass by itself. Compare screenplay-evidenced age/costume combinations, location configurations, and provisional camera zones with the inventory, then compare every required row with the actual approved reference element data. A default-only pack passes when the screenplay requires no other look/configuration. CAPS extraction alone cannot establish that a costume combination, location configuration, or angle pack exists. On a post-breakdown rerun, compare persisted shot camera zones and character appearance mappings with those same inventory rows.

**Judge `MISSING_IMAGE` by `hasImage` — never by `thumbnailUrl`/`previewUrl`.** `list_references` returns `thumbnailUrl`/`previewUrl` alongside it, and it's easy to grab the wrong pair: those two are a card-preview column that nothing populates when a Look is attached, so a reference with real turnaround images routinely still shows both as `null`. Reading those as the presence signal produces a false `MISSING_IMAGE` on every reference in the project — a wrong blocking finding on the roster's healthiest data, not its worst. `hasImage` (see `mixio-references`) is the real signal.

| Finding | Meaning |
|---------|---------|
| `MISSING_REF` | Entity mentioned in script has no matching reference element at all |
| `MISSING_IMAGE` | Reference exists but `hasImage` is false |
| `MISSING_IMAGE_HIGH_USAGE` | Same, but the entity appears in ≥3 shots or ≥2 scenes — generation will be inconsistent without a visual anchor |
| `NO_PRIMARY_LOOK` | Reference has variant images but none marked `isPrimary` or `isDefault` — prompt assembly picks arbitrarily |
| `MISSING_REQUIRED_VARIANT` | A screenplay-required character age/clothing look or location configuration has no approved variant |
| `MISSING_REQUIRED_VIEW` | A required location configuration lacks a camera-view image mapped to a planned shot zone |
| `SCRIPT_REQUIREMENT_UNMAPPED` | A screenplay-evidenced character look, location configuration, or camera zone has no confirmed inventory row |
| `REFERENCE_PACK_INVENTORY_MISSING` | The pipeline inventory is absent, empty before demand reconciliation, or unconfirmed, so variant/view completeness cannot be established |
| `REFERENCE_PACK_NOT_APPROVED` | A required reference or variant pack is still draft/in review, or lacks human approval |
| `REJECTED_MEDIA_ACTIVE` | A candidate rejected by evaluation or human review remains in an active reference image store or is still shown as its card preview |

```
Completeness — 12 references checked
  ✅ TONY         — 1 primary look, 3 images
  ✅ POPPY        — 1 primary look, 2 images
  ⚠️  CEREAL BOWL — MISSING_IMAGE (appears in 2 shots)
  ❌ HALLWAY DOORWAY — MISSING_REF (mentioned 4× in script)
```

### 2. Visual reference readiness — sheet integrity and coverage

Build the review set from every screenplay-required row in the confirmed
`metadata.pipeline.reference_pack_inventory`: exact reference, look/configuration,
view, and image. Include all candidate images attached to each required row;
do not audit or block unrelated, unused project looks. Compare a candidate with
its relevant approved baseline image when one exists (for a character, usually
the approved canonical identity sheet; for a location, the approved view or
configuration that shares its stable geometry). Also compare sibling views and
variants when their relationship is meaningful. Use the exact row's declared
reason for the look/configuration to distinguish intended changes from drift.
Do not treat drafts or in-review images as an approved baseline, and do not let
an image's approval status imply it passed this visual review.

Use only evidence that applies to the row: the screenplay and confirmed variant
reason; the locked project style in `settings.studio` (including
`visualStyle`, `toneAndMood`, `cinematographyDirection`, and
`defaultStylePrompt` when present); structured reference details; an approved
baseline; and an applicable scene anchor. Keep the following checks separate so
one strong similarity score cannot hide a specific contradiction:

- **Style and materials:** Match the requested medium and realism level,
  including photorealistic/hyperrealistic versus stylized treatment, detail,
  and surface/material rendering. Plastic or waxy skin is a defect when it
  conflicts with the requested realism or material treatment; preserve it when
  it is an intentional part of the locked style.
- **Lighting and palette:** Compare light direction, quality, temperature,
  contrast, exposure, and shadow behavior, plus palette and color relationships.
  Treat a change as intentional only when the screenplay or confirmed row says
  that the look changes time, weather, mood, or lighting. Check sibling views
  for continuity under the same declared conditions.
- **Identity and anatomy:** Across each required character look/view, check face,
  age, build, hair, skin, distinctive features, proportions, wardrobe, and
  accessories. Mark hidden or off-frame features unobservable. Flag deformation,
  extra or fused limbs/fingers, warped joints, hallucinated accessories, or
  unexplained silhouette changes; an aggregate score cannot waive these.
- **Scale:** Compare visible height or relative scale only with explicit source
  evidence such as screenplay facts, structured height details,
  `metadata.scalingLabel`, a `SCALING_SHEET`, or another confirmed measurement.
  Account for perspective and framing; never infer an exact height from an
  image alone or invent scale metadata to make a candidate pass.
- **Location continuity:** Compare each required configuration and view with its
  declared layout, depth axes, landmarks, entrances, and other persistent
  geometry. A reverse angle or declared day/night configuration may change
  framing, light, and palette; it must preserve the world geometry and every
  other invariant the row does not authorize changing.
- **Hallucinations and defects:** Check for unexplained people, props, text or
  logos, missing signature features, duplicate or merged features, impossible
  geometry, seams, severe blur, inconsistent materials, and other visible
  defects that would mislead downstream generation.

Record each finding against the exact reference/look/view/image and include the
visible evidence, governing source or invariant, confidence, severity, and safe
next action. A high-confidence contradiction of an explicit script fact,
locked style, approved baseline, declared cross-view invariant, or scale record
is **BLOCKING**. Subjective, weakly observable, or source-ambiguous impressions
are **ADVISORY** for human judgment. Never auto-edit a reference or change its
approval state from this audit.

For each required location variant/configuration, compare `depthAxes`, stable
landmarks, and every attached orientation record. Require the camera looks
needed by that configuration's shot zones, including a reverse/opposite-axis
view where the shot plan crosses the line. Validate world-left/right separately
from camera-left/right and screen-left/right. Every location pack sent to
`image-location` must meet that profile's minimum view count and have explicit
`reference-coverage` aliases mapped to its exact variant and image labels.
Missing coverage or a misbound view is **BLOCKING**; unneeded
top/bottom/overhead/underslung/detail views are not failures.

Compare variants against the location inventory's declared invariants (such as
building silhouette, fixed entrances, window/door placement, and world axes).
Treat changes as intentional only when the screenplay or user-confirmed
inventory names them. High-confidence geometry, landmark, palette, or
orientation drift that contradicts an explicit invariant is **BLOCKING**;
subjective or source-ambiguous drift is **ADVISORY**. A rejected candidate must
never remain in `referenceVariants`, legacy `characterDetails.looks`, or flat
`attachments`, and must not remain in top-level `thumbnailUrl`/`previewUrl` as
the card image. Retain its feedback and evaluation receipt outside the active
media stores. Read the reference back to verify removal before clearing the
finding; if a rejected preview cannot be cleared through a documented
operation, keep the reference non-approved and block generation.

If no vision-capable reviewer is available, use a compatible still-image
evaluation profile only after checking the live catalog and contract and
receiving confirmation for the billable submission. Do not assume a video or
storyboard profile accepts reference sheets. If neither visual path is
available, record `VISUAL_REVIEW_UNAVAILABLE` for each affected required row,
leave its visual status unresolved, and keep Step 02.5 open. A metadata-only
check is not a visual pass. Progress may continue only after visual evidence is
reviewed or the user explicitly overrides the unresolved row; record the
override and rationale in the existing inventory/audit metadata. Evaluator
results are evidence for human review, never approval.

| Finding | Meaning |
|---------|---------|
| `STYLE_MISMATCH` | Candidate conflicts with the locked style or script's treatment |
| `LIGHTING_MISMATCH` / `PALETTE_MISMATCH` | Lighting or color conflicts with the applicable confirmed evidence without an intended variant change |
| `SCALE_OR_PROPORTION_CONFLICT` | Visible scale or proportions contradict explicit source evidence |
| `IDENTITY_OR_VARIANT_DRIFT` | Identity or other stable character invariants drift, or the candidate fails its declared look purpose |
| `LOCATION_GEOMETRY_DRIFT` | Persistent layout, landmarks, depth, or world axes change across required views without explanation |
| `HALLUCINATION_OR_IMAGE_ARTIFACT` | Unwanted content or a visible generation defect undermines the reference |
| `VISUAL_REVIEW_UNAVAILABLE` | A required row has no completed vision or compatible image-evaluation review |

### 3. Consistency — name/description vs image alignment

For each reference that has both structured details and at least one image, check for contradictions:

| Finding | Meaning |
|---------|---------|
| `GENDER_MISMATCH` | `characterDetails` implies one gender but attached image presents as another |
| `AGE_MISMATCH` | Description says "child" / "elderly" but image shows a different age bracket |
| `BUILD_MISMATCH` | `build` field contradicts what the image shows |
| `DESCRIPTION_CONFLICT` | `description` or `visualAnchor` text contradicts visible features in a required attached image |

This check is **advisory, not blocking** — it requires visual interpretation which may be wrong. Flag for human review rather than auto-fixing.

Implementation: inspect every required image with vision or a compatible,
confirmed evaluation. Compare against `characterDetails.build`, `.age`, `.hair`,
`.skin`, `.distinctiveFeatures`, the exact look purpose, and the approved
baseline. If no visual reviewer is available, record
`VISUAL_REVIEW_UNAVAILABLE`; do not report a metadata-only pass.

### 4. Duplicates — fuzzy matching across the roster

| Finding | Meaning |
|---------|---------|
| `LIKELY_DUPLICATE` | Two references of the same type with names within edit distance 2, or one name is a substring of another |
| `ALIAS_CANDIDATE` | Script uses a name that matches an existing reference's description/bio but not its canonical name — likely an alias |
| `VARIANT_CONFUSED_AS_REF` | A reference whose name looks like `CHARACTER (state)` — e.g. `TONY (gala)` — or a location alias for a configuration already modeled under one canonical place, when the screenplay does not require an independent LOCATION identity |

```
Duplicates — 12 references checked
  ⚠️  LIKELY_DUPLICATE: "TONY" (CHARACTER) ↔ "TONY RUSSO" (CHARACTER) — same entity?
  ⚠️  ALIAS_CANDIDATE: script mentions "Antonia" — matches TONY's bio but no alias recorded
  ⚠️  VARIANT_CONFUSED_AS_REF: "TONY (GALA)" is a separate CHARACTER — should be a variant of TONY
```

Resolution plan:
- Merge duplicates: identify the canonical name and the alias to preserve; hand the plan to `/mixio:pipeline` Phase 2 or `mixio-references`, which reads `settings.references` before any update.
- Convert variant-as-ref: identify the parent reference and its candidate look; hand the plan to `mixio-references` for a policy-safe migration. Do not delete a reference from this audit.

### 5. Metadata quality — structured detail completeness

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

### 6. Policy compliance

Read `projects.settings.references` from `studio_get_project` and verify:

| Finding | Meaning |
|---------|---------|
| `POLICY_VIOLATION_CREATE` | Reference was created under `createPolicy: link_only` — should have been linked, not created |
| `VARIANT_VOCAB_VIOLATION` | A variant name exists outside the `variantVocabulary` set |
| `ALIAS_MATCHING_DISABLED` | Aliases are recorded but `aliasMatching` is false — they won't participate in breakdown matching |

This category is informational when the project has no policy set (the defaults are permissive).

### 7. Look-binding integrity — required looks are selected and bindings resolve

A shot or scene can bind a CHARACTER reference's age/clothing variant via `lookRef` on its `appears_in`/`presence` relation (`mixio-script-breakdown`). Compare post-breakdown relations with the confirmed character appearance mappings in `reference_pack_inventory`: when a row maps a shot's age/clothing state to a non-default approved variant, the relation must carry that variant's exact id/name. A missing binding silently renders the default, so report it before generation. The approved default needs no explicit `lookRef`. Location configuration and camera-view readiness are checked against the Step 02 inventory separately.

Pull bindings from `studio_get_production_context`'s `lookBindings` (or `studio_query_relations`
per relation). Pass relation `metadata` as a native object, never a JSON-stringified string, and
cross-reference each character `lookRef` against the target reference's `referenceVariants[].id` / `.name`.

| Finding | Meaning |
|---------|---------|
| `REQUIRED_LOOK_UNBOUND` | A confirmed inventory mapping requires a non-default character variant for this shot, but its appearance relation has no matching `lookRef` |
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
Variant/view packs:    1 MISSING_REQUIRED_VIEW, 1 REJECTED_MEDIA_ACTIVE
Visual readiness:      1 PALETTE_MISMATCH (advisory), 1 VISUAL_REVIEW_UNAVAILABLE
Visual coverage:       7 required rows, 6 reviewed, 1 unresolved
Consistency:           1 GENDER_MISMATCH (advisory)
Duplicates:            1 LIKELY_DUPLICATE, 1 ALIAS_CANDIDATE
Metadata quality:      2 HIGH-severity gaps
Policy:                0 violations
Look bindings:         1 STALE_LOOK_REF

BLOCKING findings (must resolve before Step 03):
  ❌ HALLWAY DOORWAY — MISSING_REF — appears in 4 script lines, 0 references
  ❌ THE HOUSE / interior-living-room — MISSING_REQUIRED_VIEW — sofa-to-dining view has no approved image
  ❌ TONY — REJECTED_MEDIA_ACTIVE — rejected teen-formal candidate remains in legacy attachments
  ❌ CEREAL BOWL — MISSING_IMAGE_HIGH_USAGE — 2 shots depend on this prop
  ❌ HALLWAY:night.reverse — VISUAL_REVIEW_UNAVAILABLE — required view has not been visually reviewed
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
| BLOCKING | Must be resolved before proceeding to Step 03, or explicitly overridden by the user with rationale recorded. The Pre-Production Token Ralph Loop applies only policy-safe, non-generative remediation and re-checks until 0 unacknowledged blocking errors remain |
| ADVISORY | Surfaced for human decision. Recorded in metadata; does not block convergence |

**Blocking criteria:**
- Any `MISSING_REF` for an entity appearing in ≥2 shots
- Any `MISSING_IMAGE_HIGH_USAGE`
- Any HIGH-severity metadata gap on a character appearing in ≥1 scene — a missing `visualAnchor` means every prompt mentioning that character lacks its identity anchor, no matter how few scenes it appears in
- Any HIGH-severity metadata gap on a location appearing in ≥1 scene — `setting` and `lighting` are required to render the scene's anchor frame without guessing
- Any `GENDER_MISMATCH` confirmed by both text and vision (not advisory-only)
- Any `STALE_LOOK_REF` — it renders the wrong look silently, with nothing in the UI to catch it before delivery
- Any `MISSING_REQUIRED_VARIANT`, `MISSING_REQUIRED_VIEW`, or `REJECTED_MEDIA_ACTIVE` for a script-required reference pack
- Any `REFERENCE_PACK_NOT_APPROVED` for media a planned shot will use
- Any unexplained cross-view or cross-variant location geometry/landmark drift
- Any high-confidence contradiction of the locked visual style, lighting/palette invariants, or explicit scale evidence
- Any confirmed character-sheet deformation, hallucinated anatomy, identity drift, or unexplained wardrobe/accessory/color break
- Any missing or misbound location view required by a declared shot camera zone
- Any required visual row without reviewed evidence or a recorded user override

Everything else is advisory. The user may say "proceed anyway" — record that decision in metadata so a later session knows it was acknowledged, not missed.

### Enrichment completion gate (before Step 03)

Before the audit passes, confirm that the **reference enrichment** phase from Step 02 (`mixio-sheets`) actually populated the load-bearing fields, not just the reference metadata. The breakdown in Step 03 emits references as **shallow stubs** (`name`, `description`, `attributes` only) and never writes `characterDetails`/`locationDetails`; if enrichment didn't happen here, these fields will be empty for the whole episode. HIGH-severity fields must be present on every character/location that appears in any scene:

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

These are the fields prompt materializers in Steps 05/06 rely on for visual continuity. If any are missing, treat the finding as BLOCKING and direct the fix back to Step 02 (`mixio-sheets`) to enrich rather than proceeding with a stub.

## Fixing findings & The Ralph Loop

This skill audits; it does not create or mutate references. When called directly, emit the specific remediation plan below and stop. When called from `/mixio:pipeline`, its Phase 2 runner owns policy-safe writes and immediate re-checks; follow the canonical [policy, asset, and loop-state boundary](../mixio-pipeline/references/pre-production-ralph-loop.md#boundaries-policy-and-asset-permission).

Before any reference write, the runner reads `studio_get_project({ projectId })` and enforces `settings.references.createPolicy`, `variantPolicy`, and the type-specific `variantVocabulary`. If policy prevents the write, it persists `pre_production_loop.status: "blocked"` with the finding and exact next user action; it never overrides policy.

`MISSING_IMAGE_HIGH_USAGE` has no free synthetic fix. Attach a permitted existing user-supplied asset when available; otherwise persist `blocked` and request an upload or explicit image-generation permission. Do not call `/mixio:sheets` or submit a generation job from this audit.

The remediation plan identifies the required action:

```
Fix: HALLWAY DOORWAY — MISSING_REF
→ studio_register_reference_entities({ projectId, references: [
    { type: "LOCATION", name: "HALLWAY DOORWAY", metadata: { description: "..." } }
  ]})
  Then: upload or generate a reference image via /mixio:sheets

Fix: TONY — missing visualAnchor
→ studio_update_reference({ projectId, referenceId: "<tony-id>",
    characterDetails: { visualAnchor: "Athletic Italian-American woman, late 20s, loose dark curls, warm olive skin" }
  })

Fix: TONY ↔ TONY RUSSO — LIKELY_DUPLICATE
→ studio_update_element({ projectId, elementId: "<tony-id>", updates: { metadata: {
    aliases: ["Tony Russo", "Antonia"]
  }}})
  Then: archive or delete the duplicate reference

Fix: STALE_LOOK_REF — TONY'S APARTMENT:night
→ studio_update_reference({ projectId, referenceId: "<apartment-id>", referenceVariants: [
    ...existingVariants,
    { name: "night", kind: "look", images: [{ url: nightUrl, isPrimary: true }] }
  ]})
```

After the pipeline runner applies a permitted fix, **re-run the audit immediately** to confirm unacknowledged blocking findings drop to `0` and each required visual row has reviewed evidence or a recorded user override.

## Persisting the result

```
studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  step_02_5: "complete",
  reference_audit: {
    checked: 12,
    blocking: 0,
    advisory: 1,
    clean: 11,
    visual_coverage: { required: 7, reviewed: 7, unresolved: 0 },
    visual_findings: [
      { code: "PALETTE_MISMATCH", reference: "HALLWAY", look: "night", view: "reverse",
        image: "hallway-night-reverse", evidence: "possible warm cast on a dark wall; practical lighting may explain it",
        source: "sibling night view; no explicit palette constraint", confidence: "low", severity: "advisory",
        next_action: "human review: confirm whether the reflection is intentional" }
    ],
    acknowledged_advisories: ["GENDER_MISMATCH:TONY"],
    user_overrides: [],
    timestamp: "2026-..."
  },
  // For `running`, `blocked`, and `converged` loop-state fields, copy the
  // canonical object from mixio-pipeline/references/pre-production-ralph-loop.md.
  pre_production_loop: { status: "converged" }
}}}}})
```

## Workflow

```
1. studio_get_episode({ episodeId })                  → get persisted script
2. extract CAPS entities from script text             → demand list
3. studio_list_references({ projectId })              → supply list
4. studio_get_project({ projectId })                  → read reference policy
5. run all 7 check categories and inspect every required look/view image → findings + visual coverage
6. emit REFERENCE AUDIT report
7. ↺ Ralph Loop: apply only policy-safe, non-generative remediation and re-check until 0 unacknowledged blocking errors remain and each required visual row is reviewed or overridden
8. if ADVISORY only: present, record in metadata
9. persist audit result (0 unacknowledged blocking; visual rows reviewed or overridden) → GATE → Step 03 Panel Breakdown
```

## Notes

- Run this **after** sheets (Step 02) because sheets create the bulk of the reference images. Running before sheets would flag every reference as `MISSING_IMAGE`.
- Step 02.5 participates in the Pre-Production Token Ralph Loop (`mixio-pipeline/references/pre-production-ralph-loop.md`): the pipeline runner may remediate safe text/graph findings and must re-check before Step 03. This audit never bypasses reference policy or starts image generation itself.
- Re-run after any reference change in a later step. It's free (reads only) and a stale audit means a stale contract.
- The duplicate check uses normalized names (lowercased, stripped of punctuation, collapsed whitespace). `aliasMatching` in project settings controls whether recorded aliases participate in *breakdown* matching — the audit checks aliases regardless, because it's looking for data quality, not runtime behavior.
- On a project with 50+ references, emit the clean list as a count rather than naming each one. The blocking and advisory lists are what the user needs to act on.
