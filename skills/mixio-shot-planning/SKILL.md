---
name: mixio-shot-planning
description: "Classify each shot into 6 structural archetypes (incl. MULTI_CUT for 10–15s multi-cut shots), match to model capabilities, validate duration and action density, verify prompt @ mentions and paired mention maps, and group shots into generation batches — the model-aware layer between continuity and video generation. Video generation costs the most, image generation comes next, and other operations cost little. Submitting the actual generation job is mixio-generate. Unclear which step you need → mixio-pipeline."
version: 0.4.0
invoke: /mixio:shot-planning
---

# Mixio Shot Planning

Step 05 of `mixio-pipeline`. Sits between the continuity audit (Step 04) and video generation (Step 06). Answers: **how should each shot be generated, by which model, using what structural archetype, and is the shot's content feasible for that method?**

Fixed-ceiling batching assumed one model and one method. Shot planning acknowledges the live catalog, classifies each shot into a deterministic archetype, audits execution feasibility (action density, speaking rate, duration), and prepares the production plan. Video generation costs the most, image generation comes next, and other operations cost little. Ask before video generation unless the user has already authorized it.

## Prerequisites

- An audited breakdown (Step 04) — plan the **corrected** shots
- Resolved project and episode scope (from numbered Studio lists); use persisted scene/shot IDs only — never infer a label
- Every shot has `duration`, `camera_movement`, `action`, `audio` fields populated
- `studio_list_use_cases({ outputType: "all" })` + `studio_get_use_case_input_schema({ useCaseId, modelId })` reachable (live catalog)
- Project settings locked in Step 00 (`settings.generation`, `settings.studio`)

## The three decisions per shot

For every shot, determine:

1. **Method / Archetype** — how it will be generated (the structural input shape)
2. **Model** — which engine produces it (the execution engine matched to shot characteristics)
3. **Feasibility** — whether the shot's duration, action density, dialogue, and reference bindings fit model constraints

Then group into deterministic batches and prepare the production plan for user review.

---

## 1. Structural Shot Typology (The 6 Archetype Families)

Every shot falls into exactly one generation archetype family: `GRID`, `MULTI_CUT`, `SEQUENCE`,
`MASTER_ANCHOR_MULTI_SHOT`, `SINGLE`/`DUAL_FRAME`, or `T2V`. `SINGLE` and `DUAL_FRAME` are
the two input shapes in one standard i2v family; persist the concrete code on the shot.
Classify by inspecting `camera_movement`, `action`, `duration`, markers, scene anchors,
`cuts[]`, and project settings.

| Archetype | Code | Target Studio Use Case / Shape | When to use |
|-----------|------|--------------------------------|-------------|
| **Grid / Montage** | `GRID` | `production-generate-shot-keyframe-grid` (multi-panel) | Turnaround sheets, montages, multi-angle grids, comic/storyboard panels |
| **Multi-Cut** | `MULTI_CUT` | one native `multi-shot-video` job (H3 Ref2Vid first) from persisted `cuts[]` | 10–15s shots in a `multi_cut` band with authored per-cut specs (see `references/model-matching.md#multi-cut-routing`) |
| **Sequence** | `SEQUENCE` | `production-generate-shot-keyframe-sequence` (one of `4`/`6`/`8`/`10`/`12` frames) | Long or complex shots: multiple distinct beats, multi-marker choreographies, extended camera moves |
| **Master Anchor Multi-Shot** | `MASTER_ANCHOR_MULTI_SHOT` | Scene anchor as a reference → one derived `production-generate-shot-keyframes` job → video | Coverage (CU, MCU, OTS) spatially grounded by the wide scene anchor |
| **Single-frame i2v** | `SINGLE` | 1 keyframe image → video (`production-generate-shot-keyframes` / `-video`) | Static/simple shots: holds, reactions, gentle camera moves (static, pan, tilt), single continuous action |
| **Start+End i2v** | `DUAL_FRAME` | Start + end frame → video (`production-generate-shot-keyframes` / `-video`) | Complex transitions: significant blocking change, subject enters/exits, major camera framing change |
| **Text-to-video** | `T2V` | Prompt only, no start frame (`production-generate-video`) | Abstract, establishing shots with no prior frame, mood pieces |

### Classification rules

Select the model and read its live duration schema before applying these rules. The resulting
`model_max_per_pass` is an input to classification, not a value that can be read before model
matching.

```
if shot is a multi-panel layout, montage sequence, or storyboard grid:
    → GRID

if episode metadata.pipeline.shot_contract.mode == "multi_cut"
   AND (shot has authored cuts[] OR shot.duration is in the locked band, default 10–15s):
    → MULTI_CUT (one native multi-shot-video job; validate the route in
      references/model-matching.md#multi-cut-routing and the cuts[] sum rule in
      pipeline shot-grammar.md)

if shot has no preceding shot/anchor in the scene and is an abstract or atmospheric establishing shot:
    → T2V

if shot is coverage (CU, MCU, OTS) framed within an established wide scene anchor:
    → MASTER_ANCHOR_MULTI_SHOT (uses scene anchor as spatial reference)

if shot has ≥3 markers [M1] [M2] [M3] OR distinct multi-beat action choreographies:
    → SEQUENCE

if shot.duration > model_max_per_pass:
    → SEQUENCE (split into multi-segment passes)

if camera_movement in (dolly_in, dolly_out, tracking, crane, arc, handheld):
    if duration ≤ 5s and action has ≤1 beat:
        → SINGLE (model handles short continuous move)
    elif duration ≤ 10s:
        → DUAL_FRAME
    else:
        → SEQUENCE

if camera_movement in (static, pan_left, pan_right, tilt_up, tilt_down, rack_focus):
    if action contains ≤1 marker and ≤1 distinct subject movement:
        → SINGLE
    else:
        → DUAL_FRAME

if camera_movement is not in the listed vocabularies OR no prior rule matched:
    → DUAL_FRAME (conservative total-classification fallback; record CLASSIFICATION_FALLBACK)
```

### Project-level defaults

Read `projects.settings` through `studio_get_project` before selecting a fallback model or generation shape; see [`references/execution-audit.md#project-level-defaults`](references/execution-audit.md#project-level-defaults) for setting paths and effects.

---

## 2. Model matching

Match each shot to the best available model based on what it needs. This is a recommendation, not a hard constraint — the user may override. Read the real per-model contract with `studio_get_use_case_input_schema({ useCaseId, modelId })` — that is the only authoritative source. Do **not** call `studio_list_generation_models` for this: it returns `{ id, label }` and nothing else (see `mixio-generate`).
Full capability profiles, strength-area matching guidance, and the conflicting-needs pattern: `references/model-matching.md`. `MULTI_CUT` shots follow their own fixed route table — [`references/model-matching.md#multi-cut-routing`](references/model-matching.md#multi-cut-routing) — starting with H3 Ref2Vid on `multi-shot-video`.

---

## 3. Execution audit & feasibility validation

For each shot × method × model, use the live schema for model-specific duration and input
constraints. Studio's action and dialogue pacing checks are universal heuristics, not per-model
ceilings, so they are advisory.

### Duration feasibility

A numeric duration contract is exact values (`enum`/`const`, including `anyOf`) or numeric bounds.

For `MULTI_CUT` shots, derive the contract from the **`multi-shot-video` use case** on the routed
model (H3 Ref2Vid `auto,5–15`), not from `production-generate-video` — the latter's H3 enum
`{5,6,8,10,12}` cannot express 13–15s. Also verify the `cuts[]` invariant: ≤5 cuts, contiguous
from 0.0, each ≥1.5s (or snapped to the fallback model's per-cut floor), sum within ±0.05s of
`shot.duration`; report `CUTS_SUM_MISMATCH` / `CUT_COUNT_EXCEEDED` as BLOCKING.

```
duration_schema = schema?.properties?.parameters?.properties?.duration
duration_contract = derive_numeric_duration_contract(duration_schema)
if duration_contract is unreadable:
    FINDING: DURATION_SCHEMA_UNAVAILABLE — selected model exposes no readable duration contract
    → BLOCKING: stop planning until the live schema is resolved or the user selects another model

if duration_contract.allowed_values exists AND shot.duration not in allowed_values:
    FINDING: DURATION_NOT_SUPPORTED — Shot 9 (6s) is not one of [4s, 8s]
    → BLOCKING: Use an allowed duration, split the shot, or select another model

if duration_contract.bounds exist AND shot.duration is outside [minimum, maximum]:
    FINDING: DURATION_OUT_OF_RANGE — Shot 9 (18s) > model max (8s)
    → BLOCKING: Split into segments or reassign to model with a compatible range

if shot.duration < 2.0 and method in (SINGLE, DUAL_FRAME):
    FINDING: DURATION_TOO_SHORT — most video models produce minimum 3-4s
    → ADVISORY: Merge with adjacent shot or extend duration
```

### Action density audit

Count distinct action clauses in the `action` field:

```
action_count = count_distinct_action_beats(shot.action)
action_density = action_count / shot.duration  # actions per second

if action_density > 1.5:  # Studio planner's universal pacing heuristic, not a model limit
    FINDING: ACTION_DENSITY_HIGH — 5 actions in 3s exceeds physical motion pacing
    → ADVISORY: Extend duration, reduce action complexity, or upgrade to SEQUENCE

if action_density > 0.8 and method == SINGLE:
    FINDING: ACTION_TOO_COMPLEX_FOR_SINGLE — multiple movements in a single keyframe pass
    → ADVISORY: Upgrade method to DUAL_FRAME or SEQUENCE
```

### Dialogue speaking rate audit

For shots with `audio.dialogue`:

```
word_count = len(shot.audio.dialogue.split())
speaking_rate = word_count / shot.duration  # words per second

if speaking_rate > 4.0:  # Studio planner's universal pacing heuristic, not a model limit
    FINDING: DIALOGUE_TOO_FAST — 22 words in 4s (5.5 wps) is rushed and unintelligible
    → ADVISORY: Extend shot duration or trim dialogue lines

if speaking_rate > 0 and shot.duration < 2.5:
    FINDING: DIALOGUE_IN_SHORT_SHOT — spoken dialogue requires minimum 2.5s screen time
    → ADVISORY: Extend duration to allow natural speech cadence and lip sync
```

### Reference readiness (cross-check with Step 02.5)

```
for each character_link / location_link / prop_link:
    if reference has no attached image AND model requires image reference:
        FINDING: REF_IMAGE_MISSING — model needs reference image for consistency
        → BLOCKING: Resolve in Step 02.5 / mixio-references before Step 06

for each shot's selected character variant and location configuration/view:
    resolve each selection to an approved referenceVariants image
    if no confirmed inventory row or no approved image matches:
        FINDING: REFERENCE_VARIANT_VIEW_NOT_READY — selection is absent, ambiguous, or unapproved
        → BLOCKING: resolve the exact variant and labeled image in Step 02.5
    for each location image:
        verify its label maps to the confirmed orientation record and shot camera zone
        if missing or inconsistent:
            FINDING: LOCATION_VIEW_UNMAPPED — image does not prove the planned camera view
            → BLOCKING: map or generate the required view and recheck the pack

for each character appearance with a confirmed non-default variant mapping:
    require appearanceState.lookRef to match that approved variant id/name
    if missing or stale:
        FINDING: REQUIRED_LOOK_UNBOUND — wardrobe/age state maps to an approved look but the shot will fall back to the default
        → BLOCKING: bind the mapped variant or return to the confirmed inventory if the mapping is wrong
```

The inventory is entity-specific: a CHARACTER's approved sheet is its default,
with only screenplay-required age/clothing variants; a LOCATION variant names
the required spatial/environmental configuration and its labeled images are
camera views. Do not resolve a location camera angle through a character-style
`lookRef`. Record the chosen location `variantId`/`variantName` and exact view
label/URL in the persisted plan so Step 06 passes the correct approved image.

This is the final post-breakdown reconciliation: compare each shot's mapped
character appearance and actual camera zone/linked location with
`metadata.pipeline.reference_pack_inventory`.
If the shot needs a new or unapproved view, report a blocking
`REFERENCE_VARIANT_VIEW_NOT_READY`, add a `proposed` row to the inventory, and
stop before Step 05 planning. Return to Step 02 only after the user
confirms the additional render round; then evaluate and approve the pack, rerun
`mixio-reference-audit`, and restart Steps 03–05 because their outputs are stale.

When these checks pass, emit the resolved rows as the episode's Reference Pull List
([references/reference-pull-list.md](references/reference-pull-list.md)) — it is the
handoff artifact Step 06 reads to attach the exact approved images.

### Look-binding readiness

```
for each character_link with a bound lookRef:
    resolve against reference's referenceVariants
    if unresolved:
        FINDING: LOOK_REF_UNRESOLVED — binding stale, will silently render default look
        → BLOCKING: Re-bind variant or fix in Step 02.5 (STALE_LOOK_REF)
```

Pull character bindings once via `studio_get_production_context`'s `lookBindings` rather than per-shot queries. Carry each approved character `variantId`/`variantName` into the persisted plan. For locations, record the confirmed configuration `variantId`/`variantName` and exact labeled view URL; a generic `lookRef` check does not prove camera-view readiness (see `mixio-generate` §7).

### Prompt mention & mention map validation (Universal Invariant across all models & methods)

Regardless of the model family (Hailuo, Kling, Seedance, Veo, Sora, Gemini, Wan, LTX) or generation method (SINGLE, DUAL_FRAME, MULTI_KF, GRID, MULTI_CUT, T2V), the prompt materializer and provider compilers require prompt text to contain explicit `@` mention tokens to map media references to model-specific tokens (`Image 1`, `@Image1`, `@tag`) or perform subject grounding. Failure to include `@` tokens or omitting `mentionMap` causes models to guess identity and waste generation work (e.g. incident `b463831e-ac6f-4a40-a2b2-0ebde2527c92`). Run this check before batching and carry zero blocking findings into the Step 05 gate:

```
for each shot with media references (primary, endFrame, references, character_ref,
location_ref, style_ref, asset_ref, clothing_ref, image_urls, motionRef, audioRef,
enhancer_context, and every other schema-declared media slot):
    assets = flatten_media_slots(input.media)  # stable key: elementId/mediaId/url;
                                               # retain slot/index for diagnostics
    effective_prompt = prompt if prompt is present else materialized_prompt(sequence_notes, shot_spec)
    if assets.length == 0:
        continue
    if slotTags is missing OR mentionMap is missing:
        FINDING: MENTION_MAP_UNPAIRED — media requires both maps
        → BLOCKING: create one slotTags + mentionMap pair for every asset
    for each assetKey, asset in assets:
        tag = slotTags[assetKey]
        if tag is missing OR tag does not start with '@' OR effective_prompt contains tag zero times:
            FINDING: PROMPT_MENTION_MISSING — asset has no prompt @tag
            → BLOCKING: embed @tag where that asset acts
        if mentionMap[tag] is missing or blank:
            FINDING: MENTION_MAP_UNPAIRED — slot tag has no label binding
            → BLOCKING: add mentionMap[tag] with the asset's human-readable label
    if any tag value is assigned to more than one asset:
        FINDING: MENTION_TAG_COLLISION — one @tag points at multiple assets
        → BLOCKING: assign a unique tag and label to each asset
    if any slotTags key has no asset OR any mentionMap key is not used by slotTags:
        FINDING: MENTION_MAP_ORPHANED — maps do not match active media
        → BLOCKING: remove orphan entries or bind them to a real asset
```

For a sequence use case that intentionally leaves the caller `prompt` unset, validate the effective materialized prompt (`sequence_notes` plus the shot-spec prompt); an omitted caller field is not a grounding bypass. Descriptive prose may supplement a tag, never replace it. Record every validated pairing in the [Prompt & Mention Sheet](../mixio-generate/references/prompt-mention-sheet.md), which also carries the per-route token vocabulary (`<Picture n>`, `@Image{n}`, `<IMAGE_REF_{n}>`, …) that Step 06's compilers expect. Any `PROMPT_MENTION_MISSING`, `MENTION_MAP_UNPAIRED`, `MENTION_TAG_COLLISION`, or `MENTION_MAP_ORPHANED` finding blocks the production summary and Step 06 approval until corrected.

### Continuity handoff feasibility

```
if shot is first in a new batch AND previous batch exists:
    if method not in (SINGLE, DUAL_FRAME, MASTER_ANCHOR_MULTI_SHOT):
        FINDING: CONTINUITY_BREAK_RISK — T2V/GRID cannot take previous frame as input
        → ADVISORY: Upgrade to SINGLE/DUAL_FRAME or accept cut discontinuity
```

---

## Feasibility report

Report archetype/model distribution and every finding with remediation, separating blocking from
advisory work. Use the [worked format](references/execution-audit.md#feasibility-report); the report
must include any `PROMPT_MENTION_MISSING`, `MENTION_MAP_UNPAIRED`, `MENTION_TAG_COLLISION`, or
`MENTION_MAP_ORPHANED` finding with its asset, tag, and remediation. Resolve every blocker before
advancing.

---

## Grouping into generation batches

After archetype/model assignment and feasibility resolution, group shots into **batches** per model-specific constraints:

### Batch rules (per model)

**Confirm per-shot limits from `studio_get_use_case_input_schema({ useCaseId, modelId })`**;
historical [batch profiles](references/execution-audit.md#batch-profiles) are lookup material, not a live contract.
`studio_plan_shot_batch` exposes `maxBatchDuration` (1–60, default **15**), `maxBatchShots`
(1–50, default **5**), and `targetModel`; a `MULTI_CUT` shot in the 10–15s band consumes the
default 15s ceiling by itself, so expect one multi-cut shot per batch.

### Batch formation algorithm

1. Group consecutive shots only when they share the **same model, generation use case, and input contract**. `GRID`, `MULTI_CUT`, `SEQUENCE`, `SINGLE`, `DUAL_FRAME`, and `T2V` are separate input contracts unless the live schema explicitly supports batching them together.
2. Within each compatible group, start a batch with the first shot and keep adding consecutive shots as long as the running duration and count remain under the model's ceilings.
3. The moment either limit is exceeded, close the batch and open a new one beginning with that shot.
4. A shot whose duration exceeds model max becomes a multi-segment batch (`SEQUENCE` forced).
5. Prefer closing batches at scripted cuts over arbitrary duration boundaries.
6. Never reorder shots. Batches are strictly contiguous ranges.

---

## Production summary

Report model assignments, archetype distribution, job counts, execution risks, and high-risk
cross-model boundaries. State the relative cost order once: video generation costs the most,
image generation comes next, and other operations cost little. Omit per-job price itemization.
Generation authorization follows `mixio-generate` and the user's stated permission level.

---

## Persisting the plan

Persist each shot's model, `generation_use_case`, and input contract with `studio_revise_shot_specs`,
then write an **awaiting-approval** Step 05 summary to `episode.metadata.pipeline`. Explicit approval
alone may change it to `step_05: "complete"`; see the [field shape and writes](references/execution-audit.md#plan-persistence).

---

## Gate: Production Plan Approval

**Step 06 cannot proceed until the user has reviewed and approved the production plan.**

Before asking, persist `step_05: "awaiting_approval"`, the production plan, and a stable plan
digest. On approval, re-read the plan, verify the digest has not changed, and set
`step_05: "complete"`. Step 06 handles video authorization under `mixio-generate`.

Announce the close with the production plan, for example:
`Step 05 — Shot Planning complete. 13 shots / 7 planning batches / 53.0s rendered runtime. Video generation is the highest-cost operation, image generation comes next, and other operations cost little. Please review the plan to proceed to Step 06.`

---

## Workflow

```
1. read corrected breakdown (Step 04) + project settings + live model catalog
2. match each shot to the best model based on characteristics; read its live input schema and duration ceiling
3. classify each shot into one of 6 archetype families (GRID / MULTI_CUT / SEQUENCE / MASTER_ANCHOR_MULTI_SHOT / SINGLE or DUAL_FRAME / T2V), using the selected model ceiling
4. run execution audit (duration limits, action density, speaking rate, references, prompt @ mentions + mentionMap)
5. resolve blocking feasibility findings (split shots, adjust durations, embed @ mentions, pair slotTags + mentionMap, remove orphans)
6. group into contiguous batches per model-specific ceilings
7. emit PRODUCTION SUMMARY with archetype distribution, model assignments, job counts, and execution risks
8. studio_revise_shot_specs → persist plan in shot metadata; persist `step_05: "awaiting_approval"` and a plan digest in episode metadata.pipeline
9. GATE — user reviews the production plan → verify plan digest and persist `step_05: "complete"` → Step 06 Video Generation
```

## Notes
- **Always query the live catalog.** Model capabilities change. Use `studio_get_use_case_input_schema` for the authoritative duration contract and parameter support.
- Archetype classification is a recommendation. The user may override any assignment — record overrides in shot metadata.
- Cross-model batch boundaries are where `mixio-eval` should focus its post-generation checks.
- Duration adjustments during execution audit cascade batch boundaries. Re-batch after any duration change.
- Multi-keyframe sequence planning: for pre-locked shots from Step 04, prefer `production-generate-shot-keyframes` with `keyframe_count: 1` per beat rather than sequence planner regeneration.
