# Model Comparison

Snapshot of `api/agent-api/shared_schemas/models.json` + `video-direction.json` + `use-cases.json` in the checked-in `mixiopro/studio` catalogs, verified **2026-10-04**. Every column here is a catalog field that **no MCP tool returns** — that is why it is written down. Re-derive with `studio_get_use_case_input_schema({ useCaseId, modelId })` before submitting; if that disagrees with this file, it wins.

The catalog contains **no** fps field, **no** max-resolution field, and **no** quality ranking or benchmark. If asked which model is "best", the honest answer is that the catalog does not say — give `autoSelection` order and input capability instead.

## 1. Ranking — `autoSelection.rules`

`models.json` → `autoSelection`. The `auto` sentinel resolves by matching rules in this order, most specific first (a rule naming the use case beats one matching only `outputTypes`), then taking the first `preferredModels` entry the use case actually supports (`packages/shared/src/schemas/generation/schema.ts:2045`). This ordered preference is the closest thing the catalog has to a recommendation.

| Rule id | Applies to | Signal | Preference order |
|---|---|---|---|
| `keyframe-image-default` | keyframe, image-hub, and production image use cases | — | `gemini_image` → `gemini-3.1-flash-lite-image` |
| `video-motion-transfer` | `motion-transfer` | — | `kling_motion_control_pro` → `seedance_reference_to_video_v2` → `dreamactor_v2` |
| `video-camera-motion-reference` | `camera-motion` | `media.motionRef` present | `ltx_2_3_cameraman_lora` → `kling_camera_motion_control_pro` |
| `video-camera-motion-default` | `camera-motion` | — | `ltx_2_3_cameraman_lora` → `kling_camera_motion_control_pro` |
| `video-lip-sync` | `lip-sync` | — | `svara-1-0` → `omnihuman_v1_5` → `sync_lipsync_v2` → `veed_lipsync` |
| `video-cinematic-default` | `cinematic-video` | — | `hailuo-v3-image-to-video` → `ltx-2-5-image-to-video` → `ltx_2_3_quality_image_to_video` → `gemini_omni_image_to_video` → `kling_image_to_video_2_6_pro` |
| `video-multi-shot-default` | `multi-shot-video` | — | `hailuo_v3_reference_to_video` → `gemini_omni_multishot` → `seedance_reference_to_video_v2` → `kling_o3_standard_reference_to_video` |
| `video-image-to-video` | any `VIDEO` use case | any of `media.primary`, `endFrame`, `references` | `hailuo-v3-image-to-video` → `ltx-2-5-image-to-video` → `seedance_image_to_video_v2` → `seedance_image_to_video_pro` → `kling_image_to_video_pro` → `kling_image_to_video_2_6_pro` |
| `video-text-to-video` | any `VIDEO` use case | — | `hailuo-v3-text-to-video` → `gemini_omni_text_to_video` → `seedance_text_to_video_v2` → `seedance_text_to_video_pro` → `kling_text_to_video_pro` → `kling_text_to_video_2_6_pro` |

Image and production keyframe use cases prefer `gemini_image` when it is supported. The UI's `auto` picker is not exposed for `STUDIO` use cases, so Studio production selection uses project settings, the ordered use-case model list, and the input-aware production defaults (`production-job-preparation.ts`). Video selection follows the H3 family by input type, with H3 Ref2Vid first for reference-to-video and multi-keyframe sequences.

**Multi-cut (10–15s) departs from the catalog order.** `video-multi-shot-default` is the `auto`
order for `multi-shot-video`, but its second entry `gemini_omni_multishot` accepts only `3–10s`
and `16:9`/`9:16` — for a `MULTI_CUT` shot above 10s or any other delivery ratio, skip it:
`hailuo_v3_reference_to_video` → `seedance_reference_to_video_v2` →
`kling_o3_standard_reference_to_video` → `gemini_omni_multishot` (only if ≤10s and 16:9/9:16) →
SEQUENCE fallback. Full duration envelopes and snap rules:
`mixio-shot-planning/references/model-matching.md#multi-cut-routing`. On
`production-generate-video`, H3's duration enum is `{5,6,8,10,12}` (max 12) — 13–15s must go
through `multi-shot-video`.

## 2. Relative cost guidance

Video generation costs the most, image generation comes next, and other operations cost little.
Use this simple order in planning.

## 3. Input capability — what a model accepts and refuses

`video-direction.json` → `capabilityProfiles` (12, including `safe-unknown`) and `modelBindings` (42). A binding names a `profileId` and may override the profile's roles; when it does not, the profile's roles apply (`resolveGenerationDirectionInputPolicy`). `promptMode: none` means the model ignores prompt text entirely.

| Profile | Prompt | Accepts | Refuses |
|---|---|---|---|
| `prompted-frame-anchored-video` | compile | `primary`, `endFrame` | `references`, `image_urls`, `video_urls`, `audio_urls`, `motionRef`, `videoRef`, `audioRef` |
| `prompted-text-video` | compile | *(none)* | all 9 roles |
| `hybrid-text-or-start-frame` | compile | `primary`, `endFrame` | same 7 as frame-anchored |
| `structured-reference-video` | compile | `primary`, `endFrame`, `references`, `image_urls`, `video_urls`, `audio_urls`, `motionRef` | `videoRef`, `audioRef` |
| `structured-multi-shot-reference-video` | compile | `primary`, `endFrame`, `references`, `image_urls` | `video_urls`, `audio_urls`, `motionRef`, `videoRef`, `audioRef` |
| `gemini-omni-image-reference-preview` | compile | `image_urls` | the other 8 |
| `motion-reference-owned` | compile | `primary`, `endFrame`, `motionRef` | `references`, `image_urls`, `video_urls`, `audio_urls`, `videoRef`, `audioRef` |
| `promptless-motion-transfer` | **none** | `primary`, `motionRef` | the other 7 |
| `prompt-guided-video-transform` | compile | `primary` | the other 8 |
| `audio-driven-performance` | compile | `primary`, `audioRef` | the other 7 |
| `promptless-lipsync` | **none** | `videoRef`, `audioRef` | the other 7 |
| `safe-unknown` (default) | passthrough | unconstrained | — |

Model → profile, with `lifecycle`:

| Profile | Models |
|---|---|
| `prompted-frame-anchored-video` | `seedance_image_to_video_pro`, `seedance_image_to_video_v2`/`_fast`/`_mini`, `kling_image_to_video_2_6_pro`, `ltx_2_3_quality_image_to_video`, `grok_imagine_video`, `gemini_omni_image_to_video` *(preview)* |
| `prompted-text-video` | `seedance_text_to_video_pro`, `seedance_text_to_video_v2`/`_fast`/`_mini`, `kling_text_to_video_pro`, `kling_text_to_video_2_6_pro`, `gemini_omni_text_to_video` *(preview)* |
| `hybrid-text-or-start-frame` | `veo_3_1`, `sora_2` *(**retiring**)* |
| `structured-reference-video` | `seedance_reference_to_video_v2`/`_fast`/`_mini`, `hailuo_v3_reference_to_video`, `kling_multi_image_to_video` |
| `structured-multi-shot-reference-video` | `kling_image_to_video_pro`, `kling_o3_standard_reference_to_video`, `kling_o3_pro_reference_to_video` |
| `gemini-omni-image-reference-preview` | `gemini_omni_multishot` *(preview)* |
| `motion-reference-owned` | `kling_motion_control_pro`, `kling_camera_motion_control_pro`, `ltx_2_3_cameraman_lora` |
| `promptless-motion-transfer` | `dreamactor_v2` |
| `prompt-guided-video-transform` | `gemini_omni_edit` *(preview)*, `dreamline_video_series_0_5_v2v` |
| `audio-driven-performance` | `svara-1-0`, `omnihuman_v1_5` |
| `promptless-lipsync` | `kling_lipsync_audio_to_video`, `sync_lipsync_v2`, `veed_lipsync` |

Practical consequences:

- **A binding can narrow its profile, and several do.** These accept `primary` **only** — no `endFrame` — despite sitting on a two-role profile: `seedance_image_to_video_pro`, `ltx_2_3_quality_image_to_video`, `grok_imagine_video`, `gemini_omni_image_to_video`, and `sora_2`. `kling_image_to_video_pro` widens instead, to `primary` + `endFrame` + `references`; `kling_multi_image_to_video` narrows to `image_urls` alone. Read the binding, not just the profile.
- **A text-to-video model discards every image you attach.** Passing `primary` to `seedance_text_to_video_pro` does not make it image-to-video; pick the I2V sibling.
- **Only the `structured-*` profiles carry an ordered keyframe array.** A start/end model given a multi-keyframe shot keeps frame 1 and the last frame and pushes the middle into prompt-only context (`apps/app-kalaasetu/src/lib/studio/sequence-video-models.ts`).
- **Reference count is capped and truncation is silent.** Still-image flows cap at 10 provider images (`defaults.stillImageReferencePolicy`); video flows at 9, or 4 on `kling_multi_image_to_video`, `kling_o3_standard_reference_to_video`, `kling_o3_pro_reference_to_video`. Over-cap references are dropped by coverage/fill order, not rejected.
- **`aspectHandling`** on each profile says which aspects the reference owns versus the prompt. On `prompted-frame-anchored-video`, subject / environment / render / composition are `reference_owned` — prompt text will not override the start frame on those, while camera, blocking, motion, timing and lighting are prompt-driven.
- `lifecycle: preview` and `retiring` are the only stability signal in the catalog. `sora_2` is marked retiring.

## 4. Prompt ceilings

`models.json` → `prompting.promptMaxCharacters`, present on 15 of 75 models: nine Kling routes at 2500, four Svara/LTX routes at 5000, `grok_imagine_video` at 4096, and `elevenlabs-sound-effects-v2` at 450. MiniMax H3 has no Mixio ceiling; all other models without the field have no declared ceiling, which means unknown, not unlimited.
