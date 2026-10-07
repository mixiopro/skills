# Execution Audit Reference

Lookup material for `mixio-shot-planning`. Live Studio schemas always override these examples.

## Project-level defaults

Read these from `projects.settings` with `studio_get_project`:

| Setting path | Effect on planning |
|---|---|
| `settings.generation.defaultModelByUseCase` | Pinned model per normal video use case, such as `cinematic-video` or `multi-shot-video`, plus image use cases used for keyframes. |
| `settings.studio.preferredVideoModel` | General Studio preference; do not use it as a substitute for a model pinned to the selected video use case. |
| `settings.studio.defaultVideoShotMode` | UI preference: `single-shot` biases to `SINGLE`/`DUAL_FRAME`, `multi-keyframe` to `SEQUENCE`, and `grid` to `GRID`. Only these three biases are known — the multi-cut mode lives in episode metadata (next row), not here. |
| `settings.studio.videoDurationSeconds` | Open string (no enum): the locked shot-length band, e.g. `"10-15"` (multi-cut default) or `"2.5-4.5"` (panel). Set in Step 00; read it to confirm the band still matches `shot_contract`. |
| episode `metadata.pipeline.shot_contract` | `{ mode: "multi_cut"\|"panel", band }` — a `multi_cut` shot in the locked duration band needs non-empty authored `cuts[]` before it can be classified as `MULTI_CUT`. |
| `settings.generation.defaultAspectRatioByOutputType` | Step 00's locked output ratios. |
| `settings.generation.defaultParametersByUseCase` | Pinned per-use-case parameters, such as video `resolution`. |

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
  ❌ DURATION_OUT_OF_RANGE:     Shot 9 (18s) > veo_3_1 max (8s) → split into 3 segments
  ❌ PROMPT_MENTIONS_MISSING:   Shot 7 (Gary Player ref attached but 0 @ tags) → embed @asset1
  ❌ MENTION_MAP_UNPAIRED:      Shot 7 (slotTags has @asset1 but mentionMap missing) → pair mentionMap
  ⚠️  ACTION_DENSITY_HIGH:      Shot 5 (5 actions in 3s = 1.67 a/s) → extend or simplify
  ⚠️  DIALOGUE_TOO_FAST:        Shot 11 (22 words in 4s = 5.5 wps) → extend to 6.5s

Blocking: 3 (must resolve)
Advisory: 2 (Studio's universal pacing heuristics; not per-model limits)
```

Episodes with `shot_contract.mode: "multi_cut"` add a `MULTI_CUT` line to the archetype
distribution and report the routed model per multi-cut shot (H3 Ref2Vid first — see
`model-matching.md#multi-cut-routing`). Any `CUTS_SUM_MISMATCH` or `CUT_COUNT_EXCEEDED`
finding is blocking, exactly like a duration finding.

## Batch profiles

These are historical family profiles only. Confirm the selected model's duration and batch
contract with `studio_get_use_case_input_schema` before assigning work.

| Model family | Typical max duration/batch | Typical max shots/batch | Notes |
|---|---:|---:|---|
| Seedance v2 | 10s | 5 | Default profile |
| Seedance Pro | 15s | 5 | Higher quality, same limits |
| Veo 3.1 | 8s | 3 | Shorter ceiling, high fidelity |
| Sora 2 | 20s | 4 | Longer single-pass output |
| Kling 2.6 Pro | 10s | 5 | Similar to Seedance |
| multi-shot-video (H3 Ref2Vid) | 15s (enum `auto,5–15`) | 5 (`maxBatchShots` default) | A `MULTI_CUT` shot in the 10–15s band fills the default `maxBatchDuration` alone |

## Production summary

```
PRODUCTION SUMMARY
══════════════════

Total shots:                    13
Total batches:                   7
Rendered runtime:            53.0s
Planning batches:                7  (contiguous orchestration groups)
Generation submissions:         28  (15 keyframe submissions + 13 shot-scoped video submissions)

Per-model breakdown:
  veo_3_1 (fast, 4s):          5 shots / 20.0s
  seedance_image_to_video_v2 (720p, 4s):
                                6 shots / 24.0s
  sora_2 (4s):                 1 shot  /  4.0s
  seedance_text_to_video_pro (5s):
                                1 shot  /  5.0s

Archetype breakdown:
  SINGLE (1 keyframe → video):         6 shots
  DUAL_FRAME (start+end → video):      3 shots  (3 extra keyframe jobs)
  MASTER_ANCHOR_MULTI_SHOT:            2 shots  (scene-anchor reference → derived keyframe)
  SEQUENCE (4 keyframes → video):      1 shot   (1 keyframe-sequence parent job)
  T2V (prompt only):                   1 shot

Keyframe submissions:                 15 (6 single + 3×2 dual + 2 master-derived + 1 sequence parent)
Keyframe outputs:                     18 (the sequence parent orchestrates 4 child frame jobs)
Video generation jobs:                13 (one scoped video submission per shot; batches do not replace them)

Relative cost note: Video generation costs the most, image generation comes next,
and other operations cost little.

High-risk boundaries:
  Batch 3→4: cross-model (Seedance→Veo) — continuity frame critical
  Batch 6→7: scene transition — less critical

Rapid pacing sections:
  Batches 2, 3 — 3+ consecutive RAPID/PUNCHY shots
```

## Plan persistence

Write per-shot planning metadata alongside the batch assignment. Keep `chunk_index` as an alias
for `batch_index` for backwards compatibility. `MULTI_CUT` shots persist
`generation_method: "MULTI_CUT"`, `generation_use_case: "multi-shot-video"`, and
`generation_input_contract: "multi-cut"`; the `cuts[]` array itself is authored at Step 03/04
and stays untouched by planning. A fallback to `SEQUENCE` is planned as separate jobs whose
whole-job durations come from the selected model schema and sum to the intended shot length; it
does not snap or rewrite authored cut durations. Keep a bound CHARACTER look on the existing
relation's `lookRef`; Step 06 either supplies that reference through `selectedElements` so Studio
resolves the cascade, or passes `variantId` / `variantName` on its media reference. For a
LOCATION, persist the selected configuration variant and exact approved camera-view URL from the
confirmed inventory; do not encode the angle as a character `lookRef`. Do not invent
`look_variant_id` / `look_variant_name` plan metadata: generation does not read it.

```
studio_revise_shot_specs({ projectId, shots: [
  { shotId: s1, metadata: {
    generation_method: "SINGLE",
    generation_model: "hailuo-v3-image-to-video",
    generation_use_case: "cinematic-video",
    generation_input_contract: "single-start-frame",
    batch_index: 1,
    batch_position: 1,
    batch_duration: 10.0,
    keyframe_count: 1,
    continuity_input: null
  }},
  { shotId: s4, metadata: {
    generation_method: "MASTER_ANCHOR_MULTI_SHOT",
    generation_model: "veo_3_1",
    generation_use_case: "cinematic-video",
    generation_input_contract: "scene-anchor-reference-to-derived-keyframe-then-cinematic-video",
    keyframe_generation_use_case: "production-generate-shot-keyframes",
    batch_index: 2,
    batch_position: 1,
    batch_duration: 8.0,
    keyframe_count: 1,
    continuity_input: "scene.anchorRef resolved by the skill and passed as explicit media/context"
  }}
]})

// Read-modify-write protects the rest of the pipeline state.
const episode = await studio_get_episode({ episodeId })
const pipeline = episode.metadata?.pipeline ?? {}
const presentedPlanDigest = calculate_plan_digest(plannedShots) // stable hash of the planned shot contracts

// Mark the plan for user review before continuing to Step 06.
await studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  ...pipeline,
  step_05: "awaiting_approval",
  shot_plan: {
    ...pipeline.shot_plan,
    total_batches: 7,
    total_runtime: 53.0,
    models_used: ["gpt_image_2", "veo_3_1", "seedance_image_to_video_v2", "sora_2", "seedance_text_to_video_pro"],
    archetypes: { SINGLE: 6, DUAL_FRAME: 3, MASTER_ANCHOR_MULTI_SHOT: 2, SEQUENCE: 1, T2V: 1 },
    keyframe_submissions: 15,
    keyframe_outputs: 18,
    video_jobs: 13,
    plan_digest: presentedPlanDigest
  }
}}}})

// After the user approves the production plan, re-read in case another pipeline step wrote state.
const approvedEpisode = await studio_get_episode({ episodeId })
const approvedPipeline = approvedEpisode.metadata?.pipeline ?? {}
const approvedPlan = approvedPipeline.shot_plan ?? {}
if (approvedPipeline.step_05 !== "awaiting_approval" ||
    approvedPlan.plan_digest !== presentedPlanDigest) {
  throw new Error("plan changed while approval was pending; re-present the current plan and await new approval")
}
await studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  ...approvedPipeline,
  step_05: "complete",
  shot_plan: approvedPipeline.shot_plan
}}}})
```

The relative cost order is the operational guidance: video generation costs the most, image
generation comes next, and other operations cost little. Use this relative order in planning.
