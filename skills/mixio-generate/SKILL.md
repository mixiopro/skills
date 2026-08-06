---
name: mixio-generate
description: "Generate images, video and audio through Mixio Studio jobs — which use cases exist, which models each supports, what each accepts as input, what it costs, and when a Studio production use case beats a Generate one."
version: 0.3.0
invoke: /mixio:generate
---

# Mixio Generate

Submit and track Studio generation jobs through the proxied `studio_*` MCP tools. Jobs are billable and async by default.

Every claim below is grounded in the `mixiopro/studio` repo and cited inline so it can be re-verified. The catalog is the source of truth; this skill is a snapshot.

**Catalog snapshot — verified 2026-08-05** against a live MCP server and `mixiopro/studio@8999961f`:

| | Count | Source |
|---|---|---|
| Use cases | **38** — 16 `STUDIO`, 13 `IMAGE`, 7 `VIDEO`, 2 `AUDIO` | `api/agent-api/shared_schemas/use-cases.json` |
| Model entries | **61** (includes 7 workflow pseudo-models such as `video-preproduction`) | `api/agent-api/shared_schemas/models.json` |
| Capability profiles / model bindings | 12 / 37 | `api/agent-api/shared_schemas/video-direction.json` |
| Presets | attached to 9 use cases via `presetSlots` | `api/agent-api/shared_schemas/presets.json` |

Re-derive before spending: `studio_get_use_case_input_schema({ useCaseId, modelId })` is generated from the same resolution path the Studio UI renders from (spec `specs/022-mcp-use-case-input-schema/spec.md`), so it cannot drift from reality the way this file can.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- **Resolved scope — required.** You must be working against a project, plus the deepest scope you know (episode / scene / shot) that the user has explicitly confirmed. If it is not established in this session, **fetch the list and show it, numbered, in the same message as the question** (`studio_list_projects` / `studio_list_episodes`) so the answer is one character. Asking "which episode?" without the list is a failure — it hands the lookup back to the user. Resolve this *before* any expensive read; never guess an id, infer one from a title, or create something to avoid asking. See `mixio-project`.

## 1. Discovery tools — what each one actually returns

Registrations: `apps/app-kalaasetu/src/app/api/mcp/server.ts`.

| Tool | Returns | Omits / breaks |
|---|---|---|
| `studio_list_use_cases` | `id`, `label`, `outputType`, `description`, `supportedModels`, `count` | **Always pass `outputType: "all"`.** The enum is `IMAGE \| VIDEO \| all` but the catalog also has `STUDIO` and `AUDIO`, so 18 of 38 use cases — every `production-*`, every screenplay/preproduction workflow, both audio ones — are unreachable through any narrower filter (`IMAGE` returns 13, `VIDEO` returns 7). Does **not** return `surfaces`, `media`, `parameters`, `presetSlots`, `intent`, or `studio`. `workflowId` is mapped but is always `undefined` — the field does not exist on `UseCaseDef` (server.ts:2938) |
| `studio_list_generation_models` | with `useCaseId`: `{ id, label }` per model. Unfiltered: `{ id, label }` × 61 | **Broken — do not rely on it.** `mediaType: "image"` returns `{models:[],count:0}`, verified. It filters on `m.mediaType \|\| m.outputType`, and `ModelDef` has neither field (`packages/shared/src/schemas/generation/schema.ts:771` — only `label`, `providers`, `pricing`, `prompting`, `roleSlotPolicy`, `videoReferenceBudget`, `organizationNameIncludes`), so `provider`, `mediaType`, `outputType` and `supportedUseCases` serialize away as `undefined` and the filter matches nothing (server.ts:2887). Use `supportedModels` from `list_use_cases`, or `model.options` from `studio_get_generation_catalog_detail`, instead |
| `studio_get_use_case_input_schema({ useCaseId, modelId })` | **The authoritative per-model contract.** JSON Schema 2020-12 for `{ prompt?, media, parameters }`, plus `supportedModels` and resolved `presets` | **Always pass `modelId`.** Omitting it resolves a different model and therefore a different schema: `image-hub` with no `modelId` yields `gpt_image_2` (auto is unsupported for `IMAGE`, so it falls back to `models[0]`), `cinematic-video` yields `ltx_2_3_quality_image_to_video` (auto rule). Throws `No model could be resolved for <id>` on the three model-less Studio use cases: `studio-lock-references`, `studio-storyboard-keyframes`, `studio-batch-image-generation`. Responses for the 9 preset-bearing use cases are large — they inline the full preset catalog |
| `studio_get_generation_catalog_detail({ useCaseId, modelId, surface, projectId })` | Same contract flat (`media[]`, `parameters[]` with `options`), plus `supportedActions` and `configDigest` | Needs `projectId`. Use it when you need the action ids. Note `supportedActions` is not media-typed — `production-generate-video` returns `{single: "generation.image", batch: "generation.image.batch"}` |
| `studio_cancel_studio_job({ jobId, projectId })` | `{ job: { id, status, previouslyTerminal }, message }` | **Exists** (server.ts:1951). Already-terminal jobs return their status without error. Earlier guidance in this skill that cancellation was HTTP-only was wrong |

## 2. Facts you cannot discover over MCP

This is the gap that makes agents guess. None of the following is reachable through any MCP tool. Read the repo file, or ask the user.

| Fact | Where it lives | What to do instead |
|---|---|---|
| **Credits / cost** | `models.json` → `pricing.base.credits`, `pricing.modifiers`, `pricing.minCredits`; fallback `defaults.pricing` (15 credits) | Read `references/model-comparison.md`, or the file. Spread is ~70×: `veo_3_1` base **360** / floor 180 against `nano_banana_2` and `seedream_5_lite` at **5**, `gemini_image` 10, `gpt_image_2` 20. **A model swap is a cost decision, not a quality one** — say the number before you spend it |
| **Model ranking / "when to use what"** | `models.json` → `autoSelection.rules`: ordered `preferredModels` per use case, output type and media signal | The 8 rules are reproduced in `references/model-comparison.md`. `auto` resolves through them; there is **no** rule for `IMAGE`, and `supportsAutoModelSelection` returns false for `STUDIO`, so `auto` is video-only (`schema.ts:1603`, `:1752`) |
| **Per-model input capability** | `video-direction.json` → `capabilityProfiles` + `modelBindings`: `profileId`, `supportedInputRoles`, `unsupportedInputRoles`, `promptMode`, `aspectHandling`, `lifecycle`, `routeId` | This is the real strengths/limits layer. A `prompted-frame-anchored-video` model (Seedance I2V, Kling 2.6 Pro, LTX, Grok) takes `primary` + `endFrame` and **rejects 7 other roles**; `prompted-text-video` models reject all 9. Table in `references/model-comparison.md`. Bindings inherit their profile's roles unless they override them (`packages/shared/src/schemas/generation/index.ts:resolveGenerationDirectionInputPolicy`) |
| **Reference budgets** | `models.json` → `defaults.stillImageReferencePolicy.maxProviderImages` (**10**) with `coverageOrder`/`fillOrder`/`slotByRole`; `defaults.videoReferenceBudget.maxProviderImages` (**9**) with `coverageOrder`/`reserve`, overridden per model — `kling_multi_image_to_video`, `kling_o3_standard_reference_to_video`, `kling_o3_pro_reference_to_video` cap at **4** | Over-budget references are **truncated by policy order, not rejected**: `api/agent-api/src/workflows/generation/reference_budget.py` and `apps/app-kalaasetu/src/lib/studio/video-reference-budget.ts` (`droppedIds`). Attach 20 refs and most are silently dropped, with coverage roles winning over fill order. Send the ones that matter, in role order |
| **Prompt length ceiling** | `models.json` → `prompting.promptMaxCharacters`, present on **13** of 61 models (Kling family 2500, Hailuo H3 2000, Grok 4096, Svara and LTX Quality 5000) | Models without the field have no declared ceiling. Studio's own production path truncates against it (`getPromptMaxCharacters` in `production-job-preparation.ts`); you cannot read it over MCP |
| **Speed / quality tradeoff** | `models.json` → `providers[].requirements`: `balanced \| speed \| cost \| quality` | The **only** such signal in the catalog. There is no fps field, no max-resolution field, no benchmark or quality ranking anywhere in it. If asked which model is "best", say the catalog does not rank models and offer `autoSelection` order plus credits instead of inventing a comparison |
| **`surfaces` (studio vs generate)** | `use-cases.json` → `surfaces` | See §3. **`outputType` is not a proxy for it**: `image-edit`, `character-locking`, `refine-character-image`, `character-multi-angle` are `outputType: IMAGE` but `surfaces: ["studio"]`; the two `avgc-*` use cases are on both; `kling-multi-shot-video` has `surfaces: []` and appears in neither UI while still being submittable |

## 3. Generate use case vs Studio production use case

**Default: if the project has scenes and shots and the output must attach to the graph, use a `production-*` use case and pass `context.sceneId` / `context.shotId`.** Everything else is the exception.

That default is not about `context`. Passing a perfectly correct `context` to a Generate use case does **not** bind the output to a shot — the use case decides. A `keyframe-sequence` job submitted with a full `context` including `shotId` lands in the Image Hub list and never appears under the shot; the fix is resubmitting as `production-generate-shot-keyframe-sequence`.

**Studio production** (`outputType: STUDIO`, `surfaces: ["studio"]`) — `production-generate-keyframes`, `-shot-keyframes`, `-scene-keyframes`, `-shot-keyframe-grid`, `-scene-keyframe-grid`, `-shot-keyframe-sequence`, `-video`. The Studio submission path resolves the shot, seeds linked cast/world references, resolves the scene's `anchorRef`/`anchorRefs` into reference slots, and applies a default parameter table (§4) — `apps/app-kalaasetu/src/services/production-job-preparation.ts`.

**Generate** (`surfaces: ["generate"]`) — `image-hub`, `cinematic-video`, `keyframe-grid`, `keyframe-sequence`, `camera-motion`, `motion-transfer`, `multi-shot-video`, `lip-sync`, `video-edit`, `face-swap`, `camera-angle`, `camera-grid`, `text-to-speech`, `voice-change`, `arcane-lora-v3`. Standalone exploration with `context.projectId` only; no graph binding, no reference seeding.

Model sets differ, so a use case swap can change what is even available:

- `image-hub` supports 7 image models including `flux-klein-arcane` and `z-image-turbo-arcane`.
- Every `production-*` keyframe use case supports exactly 5: `gpt_image_2`, `gemini_image`, `nano_banana_2`, `seedream_5_pro`, `seedream_5_lite`.
- `production-generate-video` supports 22 video models; `cinematic-video` supports 12, overlapping but not identical.

**One job path bypasses the catalog entirely.** `submit_studio_job` accepts any `useCaseId` string, so absence from the catalog is not a rejection. `script-preproduction` is a backend workflow id (`EVENT_DRIVEN_AGNO_WORKFLOWS` in `apps/app-kalaasetu/src/services/job-runner.ts:80`) that the MCP tool's own description advertises, but it is **absent from `use-cases.json`** — so `list_use_cases` will never list it and `get_use_case_input_schema` throws `Unknown use case`. Submit it by id and do not try to discover or schema-check it. For script breakdown from this skill set, prefer `mixio-script-breakdown`, which persists through the breakdown primitives instead. The catalog's own screenplay use cases (`source-screenplay-analysis`, `localized-screenplay-adaptation`, `video-preproduction`) *are* listed and each has a single same-named pseudo-model. The same goes for parameter names: an invented `useCaseId` also means no schema, so nothing filters or warns about what you send with it.

### Where output lands

| Use case | Scope | Output appears |
|---|---|---|
| `production-generate-shot-keyframes` | one shot, `keyframe_count` frames | under that shot |
| `production-generate-shot-keyframe-sequence` | one shot, planner-driven sequence (`4/6/8/10/12`) | under that shot |
| `production-generate-shot-keyframe-grid` | one shot, storyboard grid | under that shot |
| `production-generate-scene-keyframes` / `-scene-keyframe-grid` | one scene | under that scene |
| `production-generate-keyframes` / `production-generate-video` | current production scope | under the scene/shot |
| `keyframe-sequence`, `keyframe-grid`, `image-hub` | not production-scoped | Image Hub list, *not* under the shot |

You cannot verify this from the job read: `studio_get_job_status` returns status and tracking only, and never echoes `projectId`/`episodeId`/`sceneId`/`shotId`. Get it right on submit, then confirm by querying the shot's elements or relations. Job status values: `PENDING`, `RUNNING`, `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED`.

## 4. Parameters

**`aspect_ratio` has no global option list.** Options are per (use case × model), narrowed by the model's route policy (`models.json` → `providers[].routeCompiler.parameterPolicy.allowedValues`). Verified examples:

| Use case | Model | `aspect_ratio` enum |
|---|---|---|
| `production-generate-video` | `veo_3_1` | `16:9`, `9:16` — only |
| `production-generate-shot-keyframes` | `gemini_image` | `auto`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `21:9` |
| `image-hub` | `gpt_image_2` | `auto`, `1:1`, `16:9`, `9:16`, `21:9` |
| `cinematic-video` | `ltx_2_3_quality_image_to_video` | `auto`, `16:9`, `4:3`, `3:2`, `1:1`, `2:3`, `3:4`, `9:16` |

Read the enum from `get_use_case_input_schema` for the exact pair before submitting. `auto` is a legal value on many use cases but not all — it is absent from `production-generate-video`. The same is true of `duration` (`veo_3_1`: `4/6/8`, default `6`; the use case's own list is `4/5/6/8/10/12`, default `5`) and `resolution`. Numeric selects accept both string and number spellings (`generation-json-schema.ts`).

### Production defaults you inherit

`PRODUCTION_DEFAULT_PARAMETERS`, `apps/app-kalaasetu/src/services/production-job-preparation.ts:83`. Merge order is defaults → derived video overrides → **your** parameters, so anything you pass wins.

| Use case | Defaults |
|---|---|
| `production-generate-keyframes` | `aspect_ratio: '16:9'` |
| `production-generate-shot-keyframes` | `aspect_ratio: '16:9'`, `keyframe_count: '1'` |
| `production-generate-scene-keyframes` | `aspect_ratio: '16:9'`, `keyframe_count: '4'` |
| `production-generate-shot-keyframe-grid` | `aspect_ratio: '16:9'`, **`grid_layout: '3x2'`** |
| `production-generate-scene-keyframe-grid` | `aspect_ratio: '16:9'`, **`grid_layout: '3x2'`** |
| `production-generate-shot-keyframe-sequence` | `aspect_ratio: '16:9'`, `keyframe_count: '6'`, `orchestrate_frames: true`, `reference_concurrency: 4`, `background_concurrency: 2`, `frame_concurrency: 3` |
| `production-generate-video` | `duration: '5'`, `generate_audio: false` |

Default **model** when you pass none: `gemini_image` for the two grid use cases, otherwise the use case's first model (`gpt_image_2` for keyframes). For `production-generate-video` it depends on state — a keyframe-array model when the shot is a multi-keyframe sequence, else the first `image_to_video` model when a start frame exists, else the first `text_to_video` one. A start/end model given a multi-keyframe shot pushes every middle frame into prompt-only context (`apps/app-kalaasetu/src/lib/studio/sequence-video-models.ts`), so name the model rather than inheriting it.

`keyframe_count` is a **closed set, not a range**: `1/2/3/4/6/8/9` for `production-generate-shot-keyframes` (default `1`), `4/6/8/10/12` for `-shot-keyframe-sequence` (default `6`). The 12 ceiling is 16 reserved output slots shared with background plates; `orchestrate_frames` does not raise it. For more frames, submit more jobs.

`orchestrate_frames: true` (already the default on the sequence path) makes the job return a plan and dispatch one child job per frame. Side effect: the server's own evaluation pass is skipped whenever it is true, so run `mixio-eval` yourself.

`sequence_notes` is appended verbatim to the planner's prompt; a caller-supplied `prompt` **replaces** Studio's auto-assembled shot-spec prompt. Leave `prompt` unset and use `sequence_notes` unless you mean to author the whole prompt.

### Read `schemaWarnings` on every submit — it is not optional

Per spec 022, `input.parameters` is `.loose()` (so catalog parameters reach the backend) but is then **filtered to the derived schema's keys plus six workflow extensions** — `background_concurrency`, `frame_concurrency`, `multi_prompt`, `orchestrate_frames`, `reference_concurrency`, `shot_type` (`apps/app-kalaasetu/src/lib/generation-parameters.ts:18`). Dropped keys are reported **warn-only** in `schemaWarnings`; enum and type mismatches likewise warn and never block.

A job that "succeeded" with warnings ran **with your parameters removed**. Check `schemaWarnings` before polling, and treat any entry as a failed submission to redo — not as noise. Filtering falls open when the schema cannot be derived, so an unresolvable model never strips a valid submission.

## 5. Workflow

```
1. studio_list_use_cases({ outputType: "all" })           → pick useCaseId (never a narrower filter)
2. studio_get_project(projectId)                          → honor the user's pinned defaults (below)
3. studio_get_use_case_input_schema({ useCaseId, modelId })→ exact media slots + parameter enums
4. studio_list_references(projectId) → studio_get_element  → reference image URLs (§6)
5. studio_submit_studio_job({ jobType, model, useCaseId, prompt,
     input: { media, parameters }, context: { projectId, episodeId, sceneId, shotId } })
                                                          → job id + tracking + schemaWarnings
6. read schemaWarnings; if non-empty, fix and resubmit before polling
7. studio_get_job_status({ jobId, projectId })             → poll to COMPLETED
8. mixio-eval before delivery; upload_file for local renders
```

### Step 2 — honor project defaults before you choose anything

`studio_get_project(projectId)` returns the user's own pinned choices. Confirmed present on live projects; treat them as overriding this skill's suggestions, and only differ when you say so.

`settings.generation`: `defaultModelByUseCase`, `defaultParametersByUseCase`, `defaultDurationByUseCase`, `defaultAspectRatioByOutputType`, `defaultResolutionByOutputType`, `recommendedStylePresetIds`, `inferenceMode`.
`settings.studio`: `preferredVideoModel`, `videoDurationSeconds`, `defaultStylePrompt`, `defaultVideoShotMode`, `visualStyle`, `toneAndMood`, `cinematographyDirection`.

A real project reads `{ "production-generate-video": "gemini_omni_multishot" }` with `VIDEO` aspect `9:16` — submitting `veo_3_1` at `16:9` there is both wrong and far more expensive (base 360 credits against a 14-credit floor). Also read `settings.references` before creating references (`mixio-references`).

## 6. Getting reference image URLs

Media slots take **real URLs, not Payload media IDs** — the server rejects UUID-shaped values outright (server.ts, M-024/M-008). Resolve in this order:

1. `studio_list_references({ projectId })` — names, types, and a `hasAttachments` boolean. **No URLs.** This is a directory, not a source of images.
2. `studio_get_element({ elementId })` → `referenceVariants[].attachments[].media.url`, or `studio_get_production_context({ projectId, episodeId })` for the whole graph at once (100K+ characters — prefer the element read when you know the id). If the shot or scene has a bound look, prefer resolving through it rather than picking `referenceVariants[0]` — see §7.
3. Anything local: `upload_file(path)` or `get_public_url(path)` for a permanent URL first. `/api/media/file/{id}` form is also accepted.

Slot ids come from the schema, not from memory. Common ones: `primary`, `endFrame`, `references`, `character_ref`, `location_ref`, `style_ref`, `asset_ref`, `clothing_ref`, `image_urls`, `motionRef`, `audioRef`, `enhancer_context`. Each takes `{ url }` or an array of them.

### Link every job to everything it knows about

| Field | Shape | Why |
|---|---|---|
| `context` | `{ projectId (required), episodeId?, sceneId?, shotId? }` | Where the job belongs. Always the deepest scope you know |
| `selectedElements` | `[{ id, type, identityKey?, mentionCode? }]` | Which characters/locations/props the prompt refers to. `type` ∈ `CHARACTER`, `LOCATION`, `PROP`, `SHOT`, `SCENE`. Also what a look-binding fallback resolves against — see §7 |
| `slotReferences` | `{ <slot>: { url, elementId?, mediaId?, referenceType?, displayLabel? } }` | Images **with provenance**; `elementId` is what lets scene anchors dedupe against an explicit per-shot choice instead of attaching twice |
| `slotTags` | `{ <assetKey>: "@tag" }` | Binds an image to a mention tag; `assetKey` is `elementId \|\| mediaId \|\| url` |
| `mentionMap` | `{ "@tag": "Human Label" }` | Binds that tag to a subject. **Both maps are required** for a tag to bind |
| `input.media` | `{ <slot>: { url } }` | Raw URLs, no provenance. The server derives slot references and mention tags from it automatically |

### Mentions — binding an image to a subject

Sending two character images does not say which is which. `@tag` tokens in the prompt do, rewritten at dispatch into each provider's own syntax (`@Image1`/`@Element1` Kling, indexed `image1`, `Image 1` Hailuo). Substitution is in place, so the tag binds wherever it sits in the sentence.

- **`production-*` use cases derive the maps for you** from the shot's related elements; anything you pass overrides the derived value.
- **No other use case derives anything.** Send `slotTags` + `mentionMap` yourself or multi-reference binding silently does not happen.
- Write the tag as the element's name, slugified with dots — `Tony` → `@tony`, a look variant → `@tony.casual`. `mentionCode`, `title`, `displayLabel` and `name` all resolve as aliases.
- Literal `slotTags` values only survive in generic form (`@char1`, `@loc1`, `@asset2`, `@style1`, `@Image1`); anything else is reassigned.
- An unresolved tag degrades to its plain label — safe, but the binding is lost with no error.
- `@scene`, `@shot`, `@style`, `@pose` prefixes are bookkeeping, not bindable subjects.

Put per-character staging inline next to the mention — `@tony (MC, three-quarter-left, seated cross-legged, on BED)`. Structured staging fields get flattened on the way to the model; the mention token survives with its position intact.

## 7. Look bindings — declaring which variant to render

A shot or scene may bind one of a reference's looks (`referenceVariants`) via `lookRef` on its `appears_in`/`presence` relation — see `mixio-script-breakdown` and `mixio-references`. Resolution order at generation time is **shot → scene → reference default**; a binding that no longer matches a variant degrades to the next rung silently, not with an error. **Check whether your Studio has this before relying on it**: call `studio_get_production_context`; a `lookBindings` key in the response means the cascade and the `variantId`/`variantName` fields below are live. No key means it hasn't landed yet — resolve and pass the variant's URL yourself (§6).

Three ways to hit a specific look, in order of directness:

1. **Pass `variantId` / `variantName` on the media reference itself** — `input.media.<slot>: { url, variantId }`. Bound exactly, no lookup, and always wins over whatever generation would otherwise resolve.
2. **Pass `selectedElements` alongside `media`.** Each reference is linked to its element, so the backend fallback can resolve the shot-then-scene binding for you. This is the step that's easy to skip — omit `selectedElements` and a URL-only reference has no element id, so there's nothing for the fallback to key on.
3. **Read `lookBindings` and pass that look's URL yourself.** `studio_get_production_context` returns `lookBindings: [{ ownerId, referenceId, lookRef }]` for the whole episode; `query_relations` rows expose the same thing per relation as `metadata.lookRef`.

With none of the three, a reference resolves to the element's default variant — indistinguishable from "nothing was bound," so a rebind the user made can silently not render. Whatever you declare (1 or 2) is a snapshot taken at submit time; rebinding after submitting a running job does not change what it renders.

## Audio

Reachable, undiscoverable by filter. `text-to-speech` and `voice-change` are `outputType: AUDIO`, which `list_use_cases`' enum cannot express — call it with `outputType: "all"`. Then the normal path: `get_use_case_input_schema({ useCaseId: "text-to-speech", modelId: "elevenlabs_tts_multilingual_v2" })` → `submit_studio_job`. Models: `elevenlabs_tts_multilingual_v2`, `gemini_3_1_flash_tts_preview` (8 credits each), `elevenlabs_speech_to_speech` (10). Lip-sync is `outputType: VIDEO`, not audio. Mixing and final assembly are not on the MCP surface at all.

## References

`references/model-comparison.md` — `autoSelection` ranking, credits per model, and per-model input-role capability. All three are catalog facts no MCP tool exposes.
