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
  ❌ ACTION_DENSITY_HIGH:       Shot 5 (5 actions in 3s = 1.67 a/s) → extend or simplify
  ❌ DIALOGUE_TOO_FAST:         Shot 11 (22 words in 4s = 5.5 wps) → extend to 6.5s

Blocking: 5 (must resolve)
Advisory: 0
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
Total runtime:               52.5s
Estimated generation jobs:      17  (10 keyframe jobs + 7 video jobs)

Per-model breakdown:
  veo_3_1:                    5 shots / 3 batches / 22.0s / 2,160 credits
  seedance_image_to_video_v2: 6 shots / 3 batches / 24.5s / 540 credits
  sora_2:                     1 shot  / 1 batch  /  6.0s / 120 credits

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

## Plan persistence

Write per-shot planning metadata alongside the batch assignment. Keep `chunk_index` as an alias
for `batch_index` for backwards compatibility. Persist `look_variant_id` / `look_variant_name`
when non-default looks are resolved so Step 06 inherits them without re-evaluating the cascade.

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
