# Model matching

Read this when assigning a model to a classified shot. For the classification step itself and feasibility checks, see the main `SKILL.md`.

Match each shot to the best available model based on what it needs. This is a recommendation, not a hard constraint — the user may override.

## Model capability profiles

Read the real per-model contract with `studio_get_use_case_input_schema({ useCaseId, modelId })` — that is the only authoritative source, and it gives the model's actual `duration` and `aspect_ratio` options. Do **not** call `studio_list_generation_models` for this: it returns `{ id, label }` and nothing else (see `mixio-generate`). Capability facts that live only in the catalog JSON — input roles, credits, `autoSelection` ranking — are tabulated in `mixio-generate/references/model-comparison.md`. Characteristics to match against:

| What you need to know | Where it actually comes from |
|------------|---------------|
| Max single-pass duration | the `duration` enum in `get_use_case_input_schema` for that (useCase, model). There is no `maxDuration` field in the catalog |
| What input shapes the model accepts | the `media` slots in the same schema, and `supportedInputRoles` / `unsupportedInputRoles` in `video-direction.json` (`mixio-generate/references/model-comparison.md`) |
| Supported aspect ratios | the `aspect_ratio` enum in the same schema — per model, not global (`veo_3_1` is `16:9`/`9:16` only) |
| Whether references are used at all | presence of `character_ref` / `location_ref` / `references` slots in the schema; `promptMode: none` models ignore prompt text entirely |
| Cost | `pricing` in `models.json`, credits — not exposed over MCP |
| Ranking | `autoSelection.rules` in `models.json` — ordered preference per use case, video-only |

## Strength-area matching

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

## When to recommend splitting a shot across models

If a shot has characteristics that pull in conflicting directions (fast action + cinematic camera + dialogue), **surface the conflict** rather than picking one:

```
⚠️  Shot 12 — conflicting needs:
    Fast action (favors Seedance) + dialogue with lip movement (favors Veo)
    Options:
    A) Generate as DUAL_FRAME with Veo (prioritize lip sync, accept action may be less sharp)
    B) Split into two sub-shots: action segment (Seedance) + dialogue reaction (Veo)
    C) Generate as MULTI_KF with Seedance (multiple keyframes compensate for action complexity)
```
