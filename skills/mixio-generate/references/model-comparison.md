# Model Comparison

Snapshot of `api/agent-api/shared_schemas/models.json` + `video-direction.json` + `use-cases.json` in `mixiopro/studio@8999961f`, as of **2026-08-05**. Every column here is a catalog field that **no MCP tool returns** — that is why it is written down. Re-derive with `studio_get_use_case_input_schema({ useCaseId, modelId })` before spending; if that disagrees with this file, it wins.

The catalog contains **no** fps field, **no** max-resolution field, and **no** quality ranking or benchmark. If asked which model is "best", the honest answer is that the catalog does not say — give `autoSelection` order, credits, and input capability instead.

## 1. Ranking — `autoSelection.rules`

`models.json` → `autoSelection`. The `auto` sentinel resolves by matching rules in this order, most specific first (a rule naming the use case beats one matching only `outputTypes`), then taking the first `preferredModels` entry the use case actually supports (`packages/shared/src/schemas/generation/schema.ts:1752`). This ordered preference is the closest thing the catalog has to a recommendation.

| Rule id | Applies to | Signal | Preference order |
|---|---|---|---|
| `video-motion-transfer` | `motion-transfer` | — | `kling_motion_control_pro` → `seedance_reference_to_video_v2` → `dreamactor_v2` |
| `video-camera-motion-reference` | `camera-motion` | `media.motionRef` present | `ltx_2_3_cameraman_lora` → `kling_camera_motion_control_pro` |
| `video-camera-motion-default` | `camera-motion` | — | `ltx_2_3_cameraman_lora` → `kling_camera_motion_control_pro` |
| `video-lip-sync` | `lip-sync` | — | `svara-1-0` → `omnihuman_v1_5` → `sync_lipsync_v2` → `veed_lipsync` |
| `video-cinematic-default` | `cinematic-video` | — | `ltx_2_3_quality_image_to_video` → `gemini_omni_image_to_video` → `kling_image_to_video_2_6_pro` |
| `video-multi-shot-default` | `multi-shot-video` | — | `gemini_omni_multishot` → `seedance_reference_to_video_v2` → `kling_o3_standard_reference_to_video` |
| `video-image-to-video` | any `VIDEO` use case | any of `media.primary`, `endFrame`, `references` | `seedance_image_to_video_v2` → `seedance_image_to_video_pro` → `kling_image_to_video_pro` → `kling_image_to_video_2_6_pro` → `veo_3_1` |
| `video-text-to-video` | any `VIDEO` use case | — | `gemini_omni_text_to_video` → `seedance_text_to_video_v2` → `seedance_text_to_video_pro` → `kling_text_to_video_pro` → `kling_text_to_video_2_6_pro` → `veo_3_1` |

**There is no image or keyframe rule, and none for `STUDIO`.** `supportsAutoModelSelection` returns false for `outputType: STUDIO` outright (`schema.ts:1603`), and no rule declares `outputTypes: ["IMAGE"]`, so `auto` is video-only. For an image or production use case, name the model — otherwise `get_use_case_input_schema` falls back to `models[0]` and the Studio path applies its own default (`production-job-preparation.ts`).

## 2. Credits

`models.json` → `pricing`. Effective cost is `base.credits` × `modifiers` (duration steps, resolution and quality multipliers), rounded per `rounding`, floored at `minCredits`. Models with no `pricing` block inherit `defaults.pricing` = **15**. A `0` base with a non-zero floor means the price is entirely modifier-driven — read the floor as the cheapest possible outcome, not the price.

Image:

| Model | Base | Floor | Modifiers |
|---|---|---|---|
| `nano_banana_2` | 5 | — | 1 |
| `seedream_5_lite` | 5 | — | — |
| `gemini_image` | 10 | — | 1 |
| `seedream_5_pro` | 10 | — | — |
| `flux-klein-arcane`, `z-image-turbo-arcane`, `FaceSwap1.0` | 15 | 15 | — |
| `arcane-lora-v3` | 20 | 20 | — |
| `gpt_image_2` | 20 | 10 | quality: low ×0.5 / medium ×1 / high ×1.5 |
| `avgc-ryan-defrates-v1` | 50 | 50 | — |
| `avgc-ibible-colorize-2` | 100 | 100 | — |
| `qwen_multiple_angles`, `character_sheet`, `character_locking` | *(inherits 15)* | — | — |

Video (floors, since most are modifier-driven):

| Model | Base | Floor | Modifiers |
|---|---|---|---|
| `ltx_2_3_quality_image_to_video` | 0 | 5 | duration |
| `grok_imagine_video` | 0 | 10 | duration |
| `sync_lipsync_v2` | 0 | 10 | duration |
| `gemini_omni_multishot` / `_text_to_video` | 0 | 14 | duration |
| `kling_image_to_video_2_6_pro`, `kling_text_to_video_2_6_pro` | 0 | 15 | duration |
| `dreamactor_v2`, `svara-1-0`, `dreamline_video_series_0_5_v2v`, `ltx_2_3_cameraman_lora` | 0 | 15 | duration |
| `seedance_*_v2_mini` | 0 | 17 | duration + resolution (480p ×0.44 / 720p ×1 / 1080p ×2.27) |
| `seedance_*_v2_fast` | 0 | 27 | duration + resolution |
| `gemini_omni_image_to_video` | 0 | 18 | duration |
| `kling_motion_control_pro`, `kling_camera_motion_control_pro`, `kling_lipsync_audio_to_video`, `veed_lipsync` | 0 | 20 | duration |
| `kling_image_to_video_pro`, `kling_text_to_video_pro`, `kling_o3_standard_reference_to_video` | 0 | 25 | duration |
| `omnihuman_v1_5` | 0 | 30 | duration |
| `seedance_*_v2`, `hailuo_v3_reference_to_video`, `kling_o3_pro_reference_to_video` | 0 | 33 | duration (+ resolution on Seedance) |
| `sora_2` | 0 | 40 | duration |
| `kling_multi_image_to_video` | 0 | 55 | duration |
| `gemini_omni_edit` | 90 | 90 | — |
| `seedance_image_to_video_pro`, `seedance_text_to_video_pro` | 134 | 67 | duration (+ resolution on I2V) |
| **`veo_3_1`** | **360** | **180** | provider model (`veo-3.1` ×0.667, fast ×1) + duration (4s ×0.5, 6s ×0.75, 8s ×1) |

Audio: `elevenlabs_tts_multilingual_v2` 8, `gemini_3_1_flash_tts_preview` 8, `elevenlabs_speech_to_speech` 10.
Workflow pseudo-models (`video-preproduction`, `source-screenplay-analysis`, `localized-*`, `video-keyframe-extraction`) are priced 0.

The spread from `nano_banana_2` (5) to `veo_3_1` (360) is ~70×. Swapping a model is a spend decision — quote the number before submitting.

## 3. Input capability — what a model accepts and refuses

`video-direction.json` → `capabilityProfiles` (12) and `modelBindings` (37). A binding names a `profileId` and may override the profile's roles; when it does not, the profile's roles apply (`resolveGenerationDirectionInputPolicy`). `promptMode: none` means the model ignores prompt text entirely.

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
- **Reference count is capped and truncation is silent.** Still-image flows cap at 10 provider images (`defaults.stillImageReferencePolicy`); video flows at 9, or 4 on `kling_multi_image_to_video`, `kling_o3_standard_reference_to_video`, `kling_o3_pro_reference_to_video`. Over-budget refs are dropped by coverage/fill order, not rejected.
- **`aspectHandling`** on each profile says which aspects the reference owns versus the prompt. On `prompted-frame-anchored-video`, subject / environment / render / composition are `reference_owned` — prompt text will not override the start frame on those, while camera, blocking, motion, timing and lighting are prompt-driven.
- `lifecycle: preview` and `retiring` are the only stability signal in the catalog. `sora_2` is marked retiring.

## 4. Prompt ceilings

`models.json` → `prompting.promptMaxCharacters`, present on 13 of 61 models: nine of the ten Kling models at 2500 (`kling_lipsync_audio_to_video` declares none), `hailuo_v3_reference_to_video` 2000, `grok_imagine_video` 4096, `svara-1-0` and `ltx_2_3_quality_image_to_video` 5000. The rest declare no ceiling — which means unknown, not unlimited.
