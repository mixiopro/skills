---
name: mixio-shot-planning
description: "Classify each shot into 5 structural archetypes, match to model capabilities, execute action density and dialogue feasibility audit, and group into generation batches with a credit-costed production summary — the model-aware layer between continuity and video generation. Classification and batching only — submitting the actual generation job is mixio-generate. Unclear which step you need → mixio-pipeline."
version: 0.3.0
invoke: /mixio:shot-planning
---

# Mixio Shot Planning

Step 05 of `mixio-pipeline`. Sits between the continuity audit (Step 04) and video generation (Step 06). Answers: **how should each shot be generated, by which model, using what structural archetype, and is the shot's content actually feasible for that method and budget?**

Fixed-ceiling batching assumed one model and one method. Shot planning acknowledges the live catalog, classifies each shot into a deterministic archetype, audits execution feasibility (action density, speaking rate, duration), and requires explicit credit budget approval before any video jobs run.

## Prerequisites

- An audited breakdown (Step 04) — plan the **corrected** shots
- Every shot has `duration`, `camera_movement`, `action`, `audio` fields populated
- `studio_list_use_cases({ outputType: "all" })` + `studio_get_use_case_input_schema({ useCaseId, modelId })` reachable (live catalog)
- Project settings locked in Step 00 (`settings.generation`, `settings.studio`)

## The three decisions per shot

For every shot, determine:

1. **Method / Archetype** — how it will be generated (the structural input shape)
2. **Model** — which engine produces it (the execution engine matched to shot characteristics)
3. **Feasibility** — whether the shot's duration, action density, dialogue, and reference bindings fit model constraints

Then group into deterministic batches, calculate estimated credit costs, and request user approval.

---

## 1. Structural Shot Typology (The 5 Archetype Families)

Every shot falls into exactly one generation archetype family: `GRID`, `SEQUENCE`,
`MASTER_ANCHOR_MULTI_SHOT`, `SINGLE`/`DUAL_FRAME`, or `T2V`. `SINGLE` and `DUAL_FRAME` are
the two input shapes in one standard i2v family; persist the concrete code on the shot.
Classify by inspecting `camera_movement`, `action`, `duration`, markers, scene anchors, and
project settings.

| Archetype | Code | Target Studio Use Case / Shape | When to use |
|-----------|------|--------------------------------|-------------|
| **Grid / Montage** | `GRID` | `production-generate-shot-keyframe-grid` (multi-panel) | Turnaround sheets, montages, multi-angle grids, comic/storyboard panels |
| **Sequence** | `SEQUENCE` | `production-generate-shot-keyframe-sequence` (3–12 keyframe sequence) | Long or complex shots: multiple distinct beats, multi-marker choreographies, extended camera moves |
| **Master Anchor Multi-Shot** | `MASTER_ANCHOR_MULTI_SHOT` | Scene anchor crop → `production-generate-shot-keyframes` | Coverage (CU, MCU, OTS) derived directly from the wide scene anchor frame |
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

Read from `projects.settings` via `studio_get_project`:

| Setting Path | Type / Values | Effect |
|--------------|---------------|--------|
| `settings.generation.defaultModelByUseCase` | `Record<useCaseId, modelId>` | Pinned model per use case (e.g. `production-generate-video`, `production-generate-shot-keyframes`) |
| `settings.studio.preferredVideoModel` | model ID | Default fallback video generation engine |
| `settings.studio.defaultVideoShotMode` | `'single-shot'` · `'multi-keyframe'` · `'grid'` | Studio UI mode preference (`'single-shot'` biases to `SINGLE`/`DUAL_FRAME`, `'multi-keyframe'` to `SEQUENCE`, `'grid'` to `GRID`) |
| `settings.generation.defaultAspectRatioByOutputType` | `{ IMAGE: string, VIDEO: string }` | Locked aspect ratios from Step 00 |
| `settings.generation.defaultParametersByUseCase` | `Record<useCaseId, Record<string, unknown>>` | Default model parameters (e.g. `{ resolution: "720p" }`) |

---

## 2. Model matching

Match each shot to the best available model based on what it needs. This is a recommendation, not a hard constraint — the user may override. Read the real per-model contract with `studio_get_use_case_input_schema({ useCaseId, modelId })` — that is the only authoritative source. Do **not** call `studio_list_generation_models` for this: it returns `{ id, label }` and nothing else (see `mixio-generate`).

Full capability profiles, strength-area matching guidance, and the conflicting-needs pattern: `references/model-matching.md`.

---

## 3. Execution audit & feasibility validation

For each shot × method × model, run the execution audit against model capabilities:

### Duration feasibility

```
duration_schema = schema?.properties?.parameters?.properties?.duration
duration_values = flatten_numeric_enums(duration_schema?.enum, duration_schema?.anyOf)
if duration_values.length == 0:
    FINDING: DURATION_SCHEMA_UNAVAILABLE — selected model exposes no readable duration enum
    → BLOCKING: stop planning until the live schema is resolved or the user selects another model
max_duration = Math.max(...duration_values)  # schema from studio_get_use_case_input_schema

if shot.duration > max_duration:
    FINDING: DURATION_EXCEEDS_MODEL — Shot 9 (18s) > model max (8s)
    → BLOCKING: Split into segments or reassign to model with higher duration ceiling

if shot.duration < 2.0 and method in (SINGLE, DUAL_FRAME):
    FINDING: DURATION_TOO_SHORT — most video models produce minimum 3-4s
    → ADVISORY: Merge with adjacent shot or extend duration
```

### Action density audit

Count distinct action clauses in the `action` field:

```
action_count = count_distinct_action_beats(shot.action)
action_density = action_count / shot.duration  # actions per second

if action_density > 1.5:
    FINDING: ACTION_DENSITY_HIGH — 5 actions in 3s exceeds physical motion pacing
    → BLOCKING: Extend duration, reduce action complexity, or upgrade to SEQUENCE

if action_density > 0.8 and method == SINGLE:
    FINDING: ACTION_TOO_COMPLEX_FOR_SINGLE — multiple movements in a single keyframe pass
    → ADVISORY: Upgrade method to DUAL_FRAME or SEQUENCE
```

### Dialogue speaking rate audit

For shots with `audio.dialogue`:

```
word_count = len(shot.audio.dialogue.split())
speaking_rate = word_count / shot.duration  # words per second

if speaking_rate > 3.5:
    FINDING: DIALOGUE_TOO_FAST — 22 words in 4s (5.5 wps) is rushed and unintelligible
    → BLOCKING: Extend shot duration or trim dialogue lines

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
```

### Look-binding readiness

```
for each character_link / location_link / prop_link with a bound lookRef:
    resolve against reference's referenceVariants
    if unresolved:
        FINDING: LOOK_REF_UNRESOLVED — binding stale, will silently render default look
        → BLOCKING: Re-bind variant or fix in Step 02.5 (STALE_LOOK_REF)
```

### Prompt mention & mention map validation

```
for each shot with media references (primary, endFrame, references, character_ref,
location_ref, enhancer_context, and every other schema-declared media slot):
    assets = flatten_media_slots(input.media)  # stable key: slot or slot[index]
    if assets.length == 0:
        continue
    if slotTags is missing OR mentionMap is missing:
        FINDING: MENTION_MAP_UNPAIRED — media requires both maps
        → BLOCKING: create one slotTags + mentionMap pair for every asset
    for each assetKey, asset in assets:
        tag = slotTags[assetKey]
        if tag is missing OR prompt contains tag zero or more than once:
            FINDING: PROMPT_MENTION_MISSING — asset has no unique prompt @tag
            → BLOCKING: embed exactly one @tag where that asset acts
        if mentionMap[tag] is missing:
            FINDING: MENTION_MAP_UNPAIRED — slot tag has no label binding
            → BLOCKING: add mentionMap[tag] with the asset's human-readable label
    if any slotTags key has no asset OR any mentionMap key is not used by slotTags:
        FINDING: MENTION_MAP_ORPHANED — maps do not match active media
        → BLOCKING: remove orphan entries or bind them to a real asset
```

### Continuity handoff feasibility

```
if shot is first in a new batch AND previous batch exists:
    if method not in (SINGLE, DUAL_FRAME, MASTER_ANCHOR_MULTI_SHOT):
        FINDING: CONTINUITY_BREAK_RISK — T2V/GRID cannot take previous frame as input
        → ADVISORY: Upgrade to SINGLE/DUAL_FRAME or accept cut discontinuity
```

---

## Feasibility report

```
SHOT PLANNING — 13 shots across 2 scenes
═══════════════════════════════════════════

Archetype distribution:
  SINGLE:                    6 shots (46%)
  DUAL_FRAME:                3 shots (23%)
  MASTER_ANCHOR_MULTI_SHOT:  2 shots (15%)
  SEQUENCE:                  1 shot  (8%)
  T2V:                       1 shot  (8%)

Model assignments:
  veo_3_1:                    5 shots (cinematic, multi-person)
  seedance_image_to_video_v2: 6 shots (action, simple holds)
  sora_2:                     1 shot  (establishing)
  seedance_text_to_video_pro: 1 shot  (t2v abstract)

Execution audit findings:
  ❌ DURATION_EXCEEDS_MODEL:    Shot 9 (18s) > veo_3_1 max (8s) → split into 3 segments
  ❌ PROMPT_MENTIONS_MISSING:   Shot 7 (Gary Player ref attached but 0 @ tags) → embed @asset1
  ❌ MENTION_MAP_UNPAIRED:       Shot 7 (slotTags has @asset1 but mentionMap missing) → pair mentionMap
  ⚠️  ACTION_DENSITY_HIGH:      Shot 5 (4 actions in 3s = 1.33 a/s) → extend to 5s or simplify
  ❌ DIALOGUE_TOO_FAST:          Shot 11 (22 words in 4s = 5.5 wps) → extend to 6.5s

Blocking: 4 (must resolve)
Advisory: 1 (recommend resolving)
```

---

## Grouping into generation batches

After archetype/model assignment and feasibility resolution, group shots into **batches** per model-specific constraints:

### Batch rules (per model)

| Model family | Max duration/batch | Max shots/batch | Notes |
|--------------|--------------------|-----------------|-------|
| Seedance v2 | 10s | 5 | Default profile |
| Seedance Pro | 15s | 5 | Higher quality, same limits |
| Veo 3.1 | 8s | 3 | Shorter ceiling, high fidelity |
| Sora 2 | 20s | 4 | Longer single-pass output |
| Kling 2.6 Pro | 10s | 5 | Similar to Seedance |

**Confirm per-shot limits from `studio_get_use_case_input_schema({ useCaseId, modelId })`** rather than relying on static tables — the `duration` enum is the model's true ceiling.

### Batch formation algorithm

1. Group consecutive shots with the **same model assignment**.
2. Within each model-group, start a batch with the first shot and keep adding consecutive shots as long as the running duration and count remain under the model's ceilings.
3. The moment either limit is exceeded, close the batch and open a new one beginning with that shot.
4. A shot whose duration exceeds model max becomes a multi-segment batch (`SEQUENCE` forced).
5. Prefer closing batches at scripted cuts over arbitrary duration boundaries.
6. Never reorder shots. Batches are strictly contiguous ranges.

---

## Production summary & credit cost estimation

Emit this before asking for generation budget approval. Take credit costs directly from `mixio-generate/references/model-comparison.md` (`models.json` → `pricing`):

```
PRODUCTION SUMMARY
══════════════════

Total shots:                    13
Total batches:                   7
Total runtime:               52.5s
Estimated generation jobs:      17  (10 keyframe jobs + 7 video jobs)

Per-model breakdown:
  veo_3_1:                    5 shots / 3 batches / 22.0s / 2,160 credits
  seedance_image_to_video_v2: 6 shots / 3 batches / 24.5s / 540 credits
  sora_2:                     1 shot  / 1 batch  /  6.0s  / 120 credits

Archetype breakdown:
  SINGLE (1 keyframe → video):         6 shots
  DUAL_FRAME (start+end → video):      3 shots  (3 extra keyframe jobs)
  MASTER_ANCHOR_MULTI_SHOT:            2 shots  (anchored to Scene 1 wide)
  SEQUENCE (3+ keyframes → video):     1 shot   (1 keyframe-sequence job)
  T2V (prompt only):                   1 shot

Keyframe generation needed:           10 images (6 single + 3×2 dual - 2 anchor crops)
Video generation jobs:                 7 (one per resolved batch)

Credit cost estimate:
  Keyframes (image gen):    10 × 10 credits (gpt_image_2) =  100 credits
  Video gen:                3 × veo_3_1 (720) + 3 × seedance (180) + 1 × sora (120) = 2,820 credits
  Total estimate:                                          2,920 credits

High-risk boundaries:
  Batch 3→4: cross-model (Seedance→Veo) — continuity frame critical
  Batch 6→7: scene transition — less critical

Rapid pacing sections:
  Batches 2, 3 — 3+ consecutive RAPID/PUNCHY shots
```

---

## Persisting the plan

Write per-shot planning metadata alongside the batch assignment:

```
studio_revise_shot_specs({ shots: [
  { shotId: s1, metadata: {
    generation_method: "SINGLE",
    generation_model: "seedance_image_to_video_v2",
    batch_index: 1,
    batch_position: 1,
    batch_duration: 9.5,
    keyframe_count: 1,
    continuity_input: null
  }},
  { shotId: s4, metadata: {
    generation_method: "MASTER_ANCHOR_MULTI_SHOT",
    generation_model: "veo_3_1",
    batch_index: 2,
    batch_position: 1,
    batch_duration: 8.0,
    keyframe_count: 1,
    continuity_input: "scene_1_anchor"
  }}
]})
```

Keep `chunk_index` as an alias for `batch_index` for backwards compatibility.

Persist `look_variant_id` / `look_variant_name` when non-default looks are resolved so Step 06 inherits them without re-evaluating the cascade.

Then close Step 05:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  step_05: "complete",
  shot_plan: {
    total_batches: 7,
    total_runtime: 52.5,
    estimated_credits: 2920,
    models_used: ["veo_3_1", "seedance_image_to_video_v2", "sora_2"],
    archetypes: { SINGLE: 6, DUAL_FRAME: 3, MASTER_ANCHOR_MULTI_SHOT: 2, SEQUENCE: 1, T2V: 1 },
    keyframe_jobs: 10,
    video_jobs: 7
  }
}}}})
```

---

## Gate: Budget & Execution Approval

**Step 06 cannot proceed without explicit user approval of the Production Summary and credit budget.**

Announce the close with the credit estimate:
`Step 05 — Shot Planning complete. 13 shots / 7 batches / 52.5s runtime. Estimated cost: 2,920 credits across veo_3_1, seedance_image_to_video_v2, and sora_2. Please confirm budget approval to proceed to Step 06 Video Generation.`

---

## Workflow

```
1. read corrected breakdown (Step 04) + project settings + live model catalog
2. match each shot to the best model based on characteristics; read its live input schema and duration ceiling
3. classify each shot into one of 5 archetype families (GRID / SEQUENCE / MASTER_ANCHOR_MULTI_SHOT / SINGLE or DUAL_FRAME / T2V), using the selected model ceiling
4. run execution audit (duration limits, action density, speaking rate, references, prompt @ mentions + mentionMap)
5. resolve blocking feasibility findings (split shots, adjust durations, embed @ mentions & pair mentionMap)
6. group into contiguous batches per model-specific ceilings
7. emit PRODUCTION SUMMARY with archetype distribution, model assignments, and credit cost estimate
8. studio_revise_shot_specs → persist plan in shot metadata and episode metadata.pipeline
9. GATE — user approves production plan & credit spend → Step 06 Video Generation
```

## Notes

- **Always query the live catalog.** Model capabilities change. Use `studio_get_use_case_input_schema` for authoritative duration enums and parameter support.
- Archetype classification is a recommendation. The user may override any assignment — record overrides in shot metadata.
- Cross-model batch boundaries are where `mixio-eval` should focus its post-generation checks.
- Duration adjustments during execution audit cascade batch boundaries. Re-batch after any duration change.
- Multi-keyframe sequence planning: for pre-locked shots from Step 04, prefer `production-generate-shot-keyframes` with `keyframe_count: 1` per beat rather than sequence planner regeneration.
