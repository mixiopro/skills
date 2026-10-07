# Model matching

Read this before classification when a model-dependent duration ceiling could decide the
archetype, then use it again to refine the assignment after classification. For the full order
and feasibility checks, see the main `SKILL.md`.

Match each shot to the best available model based on what it needs. This is a recommendation, not a hard constraint — the user may override.

## Model capability profiles

Read the real per-model contract with `studio_get_use_case_input_schema({ useCaseId, modelId })` — that is the only authoritative source, and it gives the model's actual `duration` and `aspect_ratio` options. Do **not** call `studio_list_generation_models` for this: it returns `{ id, label }` and nothing else (see `mixio-generate`). Capability facts that live only in the catalog JSON — input roles, relative cost, and `autoSelection` ranking — are tabulated in `mixio-generate/references/model-comparison.md`. Characteristics to match against:

| What you need to know | Where it actually comes from |
|------------|---------------|
| Max single-pass duration | the `duration` enum in `get_use_case_input_schema` for that (useCase, model). There is no `maxDuration` field in the catalog |
| What input shapes the model accepts | the `media` slots in the same schema, and `supportedInputRoles` / `unsupportedInputRoles` in `video-direction.json` (`mixio-generate/references/model-comparison.md`) |
| Supported aspect ratios | the `aspect_ratio` enum in the same schema — per model, not global (`veo_3_1` is `16:9`/`9:16` only) |
| Whether references are used at all | presence of `character_ref` / `location_ref` / `references` slots in the schema; `promptMode: none` models ignore prompt text entirely |
| Relative cost | Video generation costs the most, image generation comes next, and other operations cost little |
| Ranking | `autoSelection.rules` in `models.json` — ordered preference per use case, video-only |

## Strength-area matching

This is the craft layer — which model tends to produce better results for which kind of shot. **None of it is a catalog fact**: the catalog ranks nothing and has no quality, fps or resolution-ceiling field. Present it as judgment, and prefer the catalog's own ordered preference (`autoSelection.rules`, in `mixio-generate/references/model-comparison.md`) when the user wants a defensible default.

| Shot characteristic / Archetype | Better model candidates | Why |
|---------------------------------|------------------------|-----|
| **Dialogue / lip sync** | Models with audio input support (future); currently Veo for natural mouth motion | Lip sync naturalism varies |
| **Fast action / fights** | Seedance, Kling | Better temporal coherence under rapid motion |
| **Slow / cinematic camera** | Veo, Sora | Smooth, intentional camera choreography |
| **Static holds / reactions** | Any (`SINGLE`) — cheapest option wins | Low complexity, all models handle simple holds |
| **Master Anchor reference** | Veo, Seedance (`MASTER_ANCHOR_MULTI_SHOT`) | Strong spatial grounding against the wide scene anchor |
| **Character consistency** | Models with strong `character_ref` / multi-image support | Maintaining identity across frames |
| **Establishing / landscape** | Sora, Veo (`T2V` or `SINGLE`) | Superior scale, depth, and atmospheric coherence |
| **Multi-panel / Montage** | Gemini Image, GPT Image (`GRID`) | Multi-cell layout composition and style adherence |
| **Multi-cut long take (10–15s)** | H3 Ref2Vid (`MULTI_CUT`) | One native multi-shot job with persisted per-cut specs; 15s on a single job |
| **Multi-person blocking** | Veo, Sora | Better spatial reasoning with multiple subjects |

## Multi-cut routing

`MULTI_CUT` shots (the 10–15s band) render as **one native multi-shot job on the
`multi-shot-video` use case** — never through `production-generate-video`, whose H3 duration
enum is `{5,6,8,10,12}` (max 12) and cannot express 13–15s. Route in order and stop at the
first model whose **live** schema accepts the shot; re-read the schema per episode, this table
is validated as of 2026-10:

| # | Model on `multi-shot-video` | Duration | Aspect | Notes |
|---|------|----------|--------|-------|
| 1 | `hailuo_v3_reference_to_video` (H3 Ref2Vid) | string enum `auto,5–15` | `adaptive,21:9,16:9,4:3,1:1,3:4,9:16` | First/default model of `multi-shot-video`; media `image_urls` ≤9, `video_urls` ≤3, `audio_urls` ≤3; six-section composer + `[Shot {n}] At MM:SS.mmm`; no Mixio prompt ceiling |
| 2 | `seedance_reference_to_video_v2` | `auto,3–15` | per schema | Provider tokens `@Image/@Video/@Audio{n}` |
| 3 | `kling_o3_standard_reference_to_video` (or `_pro_`) | `3–15` | per schema | Slots `primary`/`endFrame`/`references`; `@Element`/`@Image{n}`; ≤2 `<<<voice_{n}>>>` |
| 4 | `gemini_omni_multishot` | `3–10` | **`16:9`/`9:16` only** | `image_urls` only; `<IMAGE_REF_{n}>`/`@Image{n}` ≤9 — **skipped when the shot exceeds 10s or delivery is neither 16:9 nor 9:16** |
| — | no route accepts | fall back to `SEQUENCE` | — | Snap cut boundaries to the model's enum (`{5,6,8,10,12}` or `{4,5,6,8,10,12}`; per-cut floor 4–5s on H3/seedance/kling, 3s on gemini), re-check the ±0.05s sum rule, and record the snap in shot metadata |

- Duration types differ: H3 and seedance use string enums with `auto`; kling and gemini use
  numeric enums. Read the live schema per route; never assume a type or a ceiling.
- `cuts[]` stays passthrough on the shot — the job prompt embeds serialized cut lines per route
  (H3 `[Shot {n}] At MM:SS.mmm`; see `mixio-generate/references/prompt-mention-sheet.md`).
- The prompt `@` mention + `slotTags`/`mentionMap` gate applies to multi-cut jobs unchanged.

```
Model recommendation — Shot 7
  Archetype:   DUAL_FRAME
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
    C) Generate as SEQUENCE with Seedance (multiple keyframe beats compensate for action complexity)
```
