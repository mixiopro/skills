---
name: mixio-shot-planning
description: "Classify each shot's generation method, match to the best model, validate duration and action density against model capabilities, and group into generation batches — the model-aware layer between continuity and video generation."
version: 0.1.0
invoke: /mixio:shot-planning
---

# Mixio Shot Planning

Step 05 of `mixio-pipeline`. Sits between the continuity audit (Step 04) and video generation (Step 06). The old Step 05 was purely arithmetic batching — split shots into groups under a fixed 15s/5-shot ceiling. That arithmetic is still here, as one profile within a broader planning step that answers: **how should each shot be generated, by which model, using what method, and is the shot's content actually feasible for that method?**

The shift: fixed-ceiling batching assumed one model and one method. Shot planning acknowledges the catalog.

## Prerequisites

- An audited breakdown (Step 04) — plan the **corrected** shots
- Every shot has `duration`, `camera_movement`, `action`, `audio` fields populated
- `studio_list_use_cases({ outputType: "all" })` + `studio_get_use_case_input_schema({ useCaseId, modelId })` reachable (live catalog)

## The three decisions per shot

For every shot, determine:

1. **Method** — how it will be generated (the input shape)
2. **Model** — which engine produces it (the execution)
3. **Feasibility** — whether the shot's content fits the method+model constraints

Then group into batches. The grouping is method- and model-dependent, not universal.

---

## 1. Method classification

Every shot falls into exactly one generation method. Classify by inspecting `camera_movement`, `action`, `duration`, markers, and project settings.

| Method | Code | Input shape | When to use |
|--------|------|-------------|-------------|
| **Single-frame i2v** | `SINGLE` | 1 keyframe image → video | Static/simple shots: holds, reactions, gentle camera moves (static, pan, tilt), single continuous action |
| **Start+End i2v** | `DUAL_FRAME` | Start frame + end frame → video | Complex transitions: significant blocking change, subject enters/exits, camera moves that change framing substantially |
| **Multi-keyframe** | `MULTI_KF` | 3–12 keyframe images → video | Long or complex shots: multiple distinct beats, multi-marker actions, extended camera choreography |
| **Grid/sequence** | `GRID` | One generation → multiple panels | Turnaround sheets, montages, storyboard panels, style exploration |
| **Text-to-video** | `T2V` | Prompt only, no start frame | Abstract, establishing shots with no prior frame, mood pieces |

### Classification rules

```
if shot is part of a montage sequence:
    → GRID (if project settings allow) or T2V

if shot has no preceding shot in the scene (first shot, scene opener):
    if no anchor frame available:
        → T2V
    else:
        → SINGLE (anchor frame is the start frame)

if camera_movement in (static, pan_left, pan_right, tilt_up, tilt_down, rack_focus):
    if action contains ≤1 marker and ≤1 distinct subject movement:
        → SINGLE
    else:
        → DUAL_FRAME

if camera_movement in (dolly_in, dolly_out, tracking, crane, arc):
    if duration ≤ 5s and action has ≤1 beat:
        → SINGLE (model can usually handle short dolly/track)
    elif duration ≤ 10s:
        → DUAL_FRAME
    else:
        → MULTI_KF

if shot has ≥3 markers [M1] [M2] [M3]:
    → MULTI_KF

if shot.duration > model_max_per_pass:
    → MULTI_KF (split into segments)
```

### Project-level defaults

`projects.settings.generation` (read from `studio_get_project`):

| Setting | Values | Effect |
|---------|--------|--------|
| `defaultMethod` | `SINGLE` · `DUAL_FRAME` · `auto` | Override for when classification is ambiguous |
| `preferMultiKeyframe` | boolean | Bias toward MULTI_KF for complex shots instead of DUAL_FRAME |
| `gridEnabled` | boolean | Whether GRID method is available (some projects are purely sequential) |
| `defaultModel` | model ID | Fallback model when no per-shot recommendation is made |
| `modelPreferences` | `{ action?: model, dialogue?: model, establishing?: model, static?: model }` | Per-shot-type model overrides |

If settings are absent, default to `auto` classification and the project's `defaultModel` (or ask the user which model to target).

---

## 2. Model matching

Match each shot to the best available model based on what it needs. This is a recommendation, not a hard constraint — the user may override.

### Model capability profiles

Read the real per-model contract with `studio_get_use_case_input_schema({ useCaseId, modelId })` — that is the only authoritative source, and it gives the model's actual `duration` and `aspect_ratio` options. Do **not** call `studio_list_generation_models` for this: it returns `{ id, label }` and nothing else (see `mixio-generate`). Capability facts that live only in the catalog JSON — input roles, credits, `autoSelection` ranking — are tabulated in `mixio-generate/references/model-comparison.md`. Characteristics to match against:

| What you need to know | Where it actually comes from |
|------------|---------------|
| Max single-pass duration | the `duration` enum in `get_use_case_input_schema` for that (useCase, model). There is no `maxDuration` field in the catalog |
| What input shapes the model accepts | the `media` slots in the same schema, and `supportedInputRoles` / `unsupportedInputRoles` in `video-direction.json` (`mixio-generate/references/model-comparison.md`) |
| Supported aspect ratios | the `aspect_ratio` enum in the same schema — per model, not global (`veo_3_1` is `16:9`/`9:16` only) |
| Whether references are used at all | presence of `character_ref` / `location_ref` / `references` slots in the schema; `promptMode: none` models ignore prompt text entirely |
| Cost | `pricing` in `models.json`, credits — not exposed over MCP |
| Ranking | `autoSelection.rules` in `models.json` — ordered preference per use case, video-only |

### Strength-area matching

This is the craft layer — which model tends to produce better results for which kind of shot. **None of it is a catalog fact**: the catalog ranks nothing and has no quality, fps or resolution-ceiling field. Present it as judgment, and prefer the catalog's own ordered preference (`autoSelection.rules`, in `mixio-generate/references/model-comparison.md`) when the user wants a defensible default.

| Shot characteristic | Better model candidates | Why |
|--------------------|------------------------|-----|
| **Dialogue/lip sync** | Models with audio input support (future); currently Veo for natural motion | Lip sync quality varies wildly |
| **Fast action / fights** | Seedance, Kling | Better temporal coherence under rapid motion |
| **Slow/cinematic camera** | Veo, Sora | Better at smooth, intentional camera choreography |
| **Static holds / reactions** | Any — cheapest option wins | Low complexity, all models handle it |
| **Character consistency** | Models with strong `character_ref` support | Maintaining identity across frames |
| **Establishing / landscape** | Sora, Veo | Better at scale and atmosphere |
| **Abstract / stylized** | GPT Image → any i2v | Style adherence in the keyframe matters more |
| **Multi-person blocking** | Veo, Sora | Better spatial reasoning with multiple subjects |

```
Model recommendation — Shot 7
  Method:      DUAL_FRAME
  Duration:    4.5s
  Character:   TONY, POPPY (two-person blocking)
  Camera:      dolly_in (cinematic)
  Action:      object handoff (prop continuity critical)
  → Recommended: veo_3_1 (cinematic camera + multi-person)
  → Fallback:   seedance_image_to_video_v2 (if Veo unavailable)
```

### When to recommend splitting a shot across models

If a shot has characteristics that pull in conflicting directions (fast action + cinematic camera + dialogue), **surface the conflict** rather than picking one:

```
⚠️  Shot 12 — conflicting needs:
    Fast action (favors Seedance) + dialogue with lip movement (favors Veo)
    Options:
    A) Generate as DUAL_FRAME with Veo (prioritize lip sync, accept action may be less sharp)
    B) Split into two sub-shots: action segment (Seedance) + dialogue reaction (Veo)
    C) Generate as MULTI_KF with Seedance (multiple keyframes compensate for action complexity)
```

---

## 3. Feasibility validation

For each shot × method × model, check whether the content is actually producible:

### Duration feasibility

```
if shot.duration > model.maxDuration:
    FINDING: DURATION_EXCEEDS_MODEL — Shot 9 is 18s, model max is 10s
    → Split into segments, or assign to a model with higher max

if shot.duration < 2s and method == SINGLE:
    FINDING: DURATION_TOO_SHORT — most models produce minimum 3-4s
    → Merge with adjacent shot, or extend duration
```

### Action density

Count distinct actions in the `action` field (sentences describing separate movements):

```
density = action_count / duration

if density > 1.5 actions per second:
    FINDING: ACTION_DENSITY_HIGH — 5 actions in 3s is physically impossible
    → Extend duration, reduce actions, or split shot

if density > 0.8 and method == SINGLE:
    FINDING: ACTION_TOO_COMPLEX_FOR_METHOD — upgrade to DUAL_FRAME or MULTI_KF
```

### Dialogue timing

For shots with `audio.dialogue`:

```
word_count = len(dialogue.split())
speaking_rate = word_count / duration  # words per second

if speaking_rate > 4.0:
    FINDING: DIALOGUE_TOO_FAST — 20 words in 4s is rushed/unintelligible
    → Extend duration or trim dialogue

if speaking_rate > 0 and duration < 2.5:
    FINDING: DIALOGUE_IN_SHORT_SHOT — spoken words need minimum screen time
```

### Reference readiness (cross-check with Step 02.5)

```
for each character_link / location_link / prop_link:
    if reference has no image AND model requires character_ref:
        FINDING: REF_IMAGE_MISSING — model needs reference image for consistency
        → Block until /mixio:reference-audit fixes are applied
```

### Continuity handoff feasibility

```
if shot is first in a new batch AND previous batch exists:
    if method != SINGLE and method != DUAL_FRAME:
        FINDING: CONTINUITY_BREAK_RISK — T2V/GRID can't take previous frame as input
        → Override to SINGLE/DUAL_FRAME or accept visual discontinuity at this boundary
```

---

## Feasibility report

```
SHOT PLANNING — 13 shots across 2 scenes
═══════════════════════════════════════════

Method distribution:
  SINGLE:      8 shots (61%)
  DUAL_FRAME:  3 shots (23%)
  MULTI_KF:    1 shot  (8%)
  T2V:         1 shot  (8%)

Model assignments:
  veo_3_1:                    5 shots (cinematic, multi-person)
  seedance_image_to_video_v2: 6 shots (action, simple holds)
  sora_2:                     1 shot  (establishing)
  seedance_text_to_video_pro: 1 shot  (t2v abstract)

Feasibility findings:
  ❌ DURATION_EXCEEDS_MODEL: Shot 9 (18s) > veo_3_1 max (8s) → split into 3 segments
  ⚠️  ACTION_DENSITY_HIGH:   Shot 5 (4 actions in 3s) → extend to 5s or reduce actions
  ⚠️  DIALOGUE_TOO_FAST:     Shot 11 (22 words in 4s) → extend to 6s

Blocking: 1 (must resolve)
Advisory: 2 (recommend resolving)
```

---

## Grouping into generation batches

After method/model assignment and feasibility resolution, group shots into **batches**. This replaces the universal 15s/5-shot rule with model-specific constraints:

### Batch rules (per model)

| Model family | Max duration/batch | Max shots/batch | Notes |
|-------------|-------------------|-----------------|-------|
| Seedance v2 | 10s | 5 | Default profile |
| Seedance Pro | 15s | 5 | Higher quality, same limits |
| Veo 3.1 | 8s | 3 | Shorter but higher fidelity |
| Sora 2 | 20s | 4 | Longer output, fewer per batch |
| Kling 2.6 Pro | 10s | 5 | Similar to Seedance |

**Confirm per-shot limits from `studio_get_use_case_input_schema({ useCaseId, modelId })`** rather than relying on this table — the `duration` enum it returns is the model's real ceiling (e.g. `veo_3_1` on `production-generate-video` allows only `4/6/8`). There is no `maxDuration` field anywhere in the catalog, and `studio_list_generation_models` exposes nothing beyond `{ id, label }`.

### Batch formation algorithm

Deterministic — do not improvise it. A "reasonable-looking" grouping that isn't reproducible means a re-run produces different batches and the shot→batch mapping in metadata goes stale.

1. Group consecutive shots with the **same model assignment**.
2. Within each model-group, start a batch with the first shot and keep adding the next **consecutive** shot as long as, after adding it, the running total stays at or under that model's duration ceiling **and** the batch holds fewer shots than its count ceiling.
3. The moment either limit would be exceeded, close the batch and open a new one **beginning with that shot** — do not skip it.
4. A shot whose own duration exceeds the model's max becomes its own multi-segment batch (MULTI_KF forced) **and must be flagged** — it cannot be generated in one pass.
5. Prefer closing a batch at a scripted cut over filling it to the ceiling. The caps are ceilings, not targets; a batch that ends mid-gesture is harder to join than one that ends on a cut.
6. Never reorder. Batches are contiguous ranges of the shot sequence.

Worked example, one model with a 15s / 5-shot ceiling, durations `4.5, 3.0, 9.0, 3.5, 3.0`: shot 3 would take batch 1 to 16.5s, so batch 1 closes at shots 1–2 (7.5s) and shot 3 opens batch 2; shot 5 would take batch 2 to 15.5s, so batch 2 closes at shots 3–4 (12.5s) and shot 5 opens batch 3.

When adjacent shots have **different** model assignments, they're always in different batches (you can't submit a Seedance shot and a Veo shot in the same job).

### Continuity at batch boundaries

Every batch boundary is a potential visual discontinuity. For each boundary:

```
Batch 1 (Seedance): shots 1–3, last frame of shot 3 → feed as input.media.primary to batch 2
Batch 2 (Veo): shots 4–5, end frame carries into batch 3
```

Mark where cross-model boundaries exist — these are the highest-risk continuity points because different models interpret the same prompt differently.

---

## Production summary

Emit this before asking for generation approval:

```
PRODUCTION SUMMARY
══════════════════

Total shots:                    13
Total batches:                   5
Total runtime:               52.5s
Estimated generation jobs:      7  (some batches need keyframe + video)

Per-model breakdown:
  veo_3_1:                    5 shots / 2 batches / 22.0s / ~$X.XX
  seedance_image_to_video_v2: 6 shots / 2 batches / 24.5s / ~$X.XX
  sora_2:                     1 shot  / 1 batch  /  6.0s  / ~$X.XX

Method breakdown:
  SINGLE (1 keyframe → video):         8 shots
  DUAL_FRAME (start+end → video):      3 shots  (3 extra keyframe jobs)
  MULTI_KF (3+ keyframes → video):     1 shot   (1 keyframe-sequence job)
  T2V (prompt only):                   1 shot

Keyframe generation needed:           12 images (8 single + 3×2 dual)
Video generation jobs:                 7 (5 batches + 2 multi-segment)

Cost estimate:
  Keyframes (image gen):    12 × $0.XX = $X.XX
  Video gen:                 7 × $0.XX = $X.XX
  Total estimate:                        $X.XX

High-risk boundaries:
  Batch 2→3: cross-model (Seedance→Veo) — continuity frame critical
  Batch 4→5: scene transition — less critical

Shots flagged for resolution:
  Shot 9: 18s exceeds model max → must split before generation

Rapid pacing sections:
  Batches 2, 3 — 3+ consecutive RAPID/PUNCHY shots
```

Costs are in **credits**, and no MCP tool returns them — take them from `mixio-generate/references/model-comparison.md` (`models.json` → `pricing`), where the spread runs from 5 credits to `veo_3_1`'s base 360. Quote credits, not currency, and say which model each line assumes.

Rapid pacing is a note, not an error (see the `Pacing` field in `mixio-pipeline/references/shot-grammar.md`). Three rapid cuts in a row read as intentional urgency; a whole episode of them reads as noise. Surface it so the user can decide.

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
    batch_duration: 12.5,
    keyframe_count: 1,
    continuity_input: null
  }},
  { shotId: s4, metadata: {
    generation_method: "DUAL_FRAME",
    generation_model: "veo_3_1",
    batch_index: 2,
    batch_position: 1,
    batch_duration: 9.0,
    keyframe_count: 2,
    continuity_input: "batch_1_last_frame"
  }}
]})
```

Keep `chunk_index` as an alias for `batch_index` so existing Step 06 code that reads `chunk_index` still works.

Then close the step:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  step_05: "complete",
  shot_plan: {
    total_batches: 5,
    total_runtime: 52.5,
    models_used: ["veo_3_1", "seedance_image_to_video_v2", "sora_2"],
    methods: { SINGLE: 8, DUAL_FRAME: 3, MULTI_KF: 1, T2V: 1 },
    keyframe_jobs: 12,
    video_jobs: 7
  }
}}}})
```

---

## Workflow

```
1. read corrected breakdown (Step 04) + project settings + live model catalog
2. classify each shot's generation method (SINGLE / DUAL_FRAME / MULTI_KF / GRID / T2V)
3. match each shot to best model based on characteristics
4. run feasibility checks (duration, action density, dialogue, references, continuity)
5. resolve blocking feasibility findings (split shots, adjust durations)
6. group into batches per model-specific constraints
7. emit PRODUCTION SUMMARY with method/model/cost breakdown
8. studio_revise_shot_specs → persist plan
9. GATE — user approves plan and spend → Step 06 Video Generation
```

## Notes

- **Always query the live catalog.** Model capabilities change. A hardcoded "Veo max is 8s" may be wrong next month. Use the catalog values as the source of truth, falling back to the known table only when the catalog doesn't expose a field.
- Method classification is a recommendation. The user may override any assignment — record the override in shot metadata so it persists.
- Cross-model batch boundaries are where `mixio-eval` should focus its post-generation checks. Note them in the plan so Step 06 knows to run eval at those points.
- Duration changes during feasibility resolution cascade batching — one shot getting 0.5s longer can shift every batch after it. Re-batch after any duration fix, and batch the durations that were actually **persisted**, not the authored ones (Studio stores a continuous float 1–60; a pre-#502 Studio snapped to `5/8/10/12/15`).
- **MULTI_KF has two routes, and the default one re-plans your shot.** `production-generate-shot-keyframe-sequence` (never bare `keyframe-sequence` — that lands in Image Hub, not under the shot) runs an LLM planner that *regenerates* every frame description from the prompt into its own 11-field schema: `shot_type`, `camera_angle`, `description`, `focus_elements`, `composition_notes`, `background_id`, `action_beat`, `pose_change`, `blocking_notes`, `camera_change`. No lens, no per-entity FG/MG/BG, no axis, no per-character blocking, no off-screen state. Nothing is "stitched" — the job plans and renders the frames itself. Budget 1 job per shot (or 1 per frame when `orchestrate_frames` dispatches children), plus 1 video job per shot.

  For a shot whose specs Step 04 has already locked, prefer **`production-generate-shot-keyframes` with `keyframe_count: 1`, one job per beat**: our prompt is used verbatim, nothing re-plans it, and the plan-diversity gate can't reject it. That gate fails a job when ≥4 fields repeat between adjacent frames — which is exactly what a deliberate sustained hold looks like. Pass the previous beat's keyframe as a reference to chain continuity forward; the sequence use case only ever anchors later frames to frame 1. Cost: N jobs instead of 1, and no shared background plate.

  Reserve the sequence use case for shots where you *want* the beats invented.
