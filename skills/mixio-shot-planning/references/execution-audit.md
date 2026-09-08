# Execution Audit Reference

Lookup material for `mixio-shot-planning`. Live Studio schemas and live pricing always override
these examples.

## Project-level defaults

Read these from `projects.settings` with `studio_get_project`:

| Setting path | Effect on planning |
|---|---|
| `settings.generation.defaultModelByUseCase` | Pinned model per use case, such as `production-generate-video` or `production-generate-shot-keyframes`. |
| `settings.studio.preferredVideoModel` | Default fallback video generation engine. |
| `settings.studio.defaultVideoShotMode` | UI preference: `single-shot` biases to `SINGLE`/`DUAL_FRAME`, `multi-keyframe` to `SEQUENCE`, and `grid` to `GRID`. |
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
  veo_3_1 (fast, 4s):          5 shots / 20.0s /   900 credits
  seedance_image_to_video_v2 (720p, 4s):
                                6 shots / 24.0s /   792 credits
  sora_2 (4s):                 1 shot  /  4.0s /    40 credits
  seedance_text_to_video_pro (5s):
                                1 shot  /  5.0s /    67 credits

Archetype breakdown:
  SINGLE (1 keyframe → video):         6 shots
  DUAL_FRAME (start+end → video):      3 shots  (3 extra keyframe jobs)
  MASTER_ANCHOR_MULTI_SHOT:            2 shots  (scene-anchor reference → derived keyframe)
  SEQUENCE (4 keyframes → video):      1 shot   (1 keyframe-sequence parent job)
  T2V (prompt only):                   1 shot

Keyframe submissions:                 15 (6 single + 3×2 dual + 2 master-derived + 1 sequence parent)
Keyframe outputs:                     18 (the sequence parent orchestrates 4 child frame jobs)
Video generation jobs:                13 (one scoped video submission per shot; batches do not replace them)

Credit cost estimate:
  Keyframes (gpt_image_2, medium): 18 outputs × 20 credits = 360 credits
  Video (declared model/duration/resolution above):                       1,799 credits
  Total estimate:                                                         2,159 credits

High-risk boundaries:
  Batch 3→4: cross-model (Seedance→Veo) — continuity frame critical
  Batch 6→7: scene transition — less critical

Rapid pacing sections:
  Batches 2, 3 — 3+ consecutive RAPID/PUNCHY shots
```

## Plan persistence

Write per-shot planning metadata alongside the batch assignment. Keep `chunk_index` as an alias
for `batch_index` for backwards compatibility. Keep a bound look on the existing relation's
`lookRef`; Step 06 either supplies that reference through `selectedElements` so Studio resolves
the cascade, or passes `variantId` / `variantName` on its media reference. Do not invent
`look_variant_id` / `look_variant_name` plan metadata: generation does not read it.

```
studio_revise_shot_specs({ shots: [
  { shotId: s1, metadata: {
    generation_method: "SINGLE",
    generation_model: "seedance_image_to_video_v2",
    generation_use_case: "production-generate-video",
    generation_input_contract: "single-start-frame",
    batch_index: 1,
    batch_position: 1,
    batch_duration: 9.5,
    keyframe_count: 1,
    continuity_input: null
  }},
  { shotId: s4, metadata: {
    generation_method: "MASTER_ANCHOR_MULTI_SHOT",
    generation_model: "veo_3_1",
    generation_use_case: "production-generate-video",
    generation_input_contract: "scene-anchor-reference-to-derived-keyframe",
    keyframe_generation_use_case: "production-generate-shot-keyframes",
    batch_index: 2,
    batch_position: 1,
    batch_duration: 8.0,
    keyframe_count: 1,
    continuity_input: "scene.anchorRef resolved by the Studio production path"
  }}
]})

// Read-modify-write protects the rest of the pipeline state.
const episode = await studio_get_episode({ episodeId })
const pipeline = episode.metadata?.pipeline ?? {}
const presentedPlanDigest = calculate_plan_digest(plannedShots) // stable hash of the planned shot contracts

// Before asking for approval: this state must block Step 06, including on resume.
await studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  ...pipeline,
  step_05: "awaiting_approval",
  shot_plan: {
    ...pipeline.shot_plan,
    total_batches: 7,
    total_runtime: 53.0,
    estimated_credits: 2159,
    models_used: ["gpt_image_2", "veo_3_1", "seedance_image_to_video_v2", "sora_2", "seedance_text_to_video_pro"],
    archetypes: { SINGLE: 6, DUAL_FRAME: 3, MASTER_ANCHOR_MULTI_SHOT: 2, SEQUENCE: 1, T2V: 1 },
    keyframe_submissions: 15,
    keyframe_outputs: 18,
    video_jobs: 13,
    plan_digest: presentedPlanDigest,
    budget_approval: {
      status: "awaiting_approval",
      presented_credits: 2159,
      presented_at: new Date().toISOString()
    }
  }
}}}})

// Only after the user explicitly approves the presented budget, read again in case another
// pipeline step wrote state while the approval was pending.
const approvedEpisode = await studio_get_episode({ episodeId })
const approvedPipeline = approvedEpisode.metadata?.pipeline ?? {}
const approvedPlan = approvedPipeline.shot_plan ?? {}
if (approvedPipeline.step_05 !== "awaiting_approval" ||
    approvedPlan.budget_approval?.status !== "awaiting_approval" ||
    approvedPlan.budget_approval?.presented_credits !== 2159 ||
    approvedPlan.plan_digest !== presentedPlanDigest) {
  throw new Error("plan changed while approval was pending; re-present the current plan and await new approval")
}
await studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  ...approvedPipeline,
  step_05: "complete",
  shot_plan: {
    ...approvedPipeline.shot_plan,
    budget_approval: {
      ...approvedPlan.budget_approval,
      status: "approved",
      approved_credits: 2159,
      approved_at: new Date().toISOString()
    }
  }
}}}})
```

The example uses the documented pricing snapshot: `gpt_image_2` at medium quality (20 credits
per output), Veo fast at 4 seconds (180), Seedance I2V at 720p for 4 seconds (132), Sora at 4
seconds (40), and Seedance T2V Pro at 5 seconds (67). Pricing and schemas change, so recompute
the exact itemization from the current catalog and selected parameters before presenting a real
approval request.
