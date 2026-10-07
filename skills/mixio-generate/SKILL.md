---
name: mixio-generate
description: "Generate images, video and audio through Mixio Studio jobs — which use cases exist, which models each supports, what each accepts as input, the relative cost of generation types, and when a Studio production use case beats a Generate one."
version: 0.5.0
invoke: /mixio:generate
---

# Mixio Generate

Submit and track Studio generation jobs through the proxied `studio_*` MCP tools. Jobs are billable and async by default.

Every claim below is grounded in the `mixiopro/studio` repo and cited inline so it can be re-verified. The catalog is the source of truth; this skill is a snapshot.

**Catalog snapshot — verified 2026-09-10** against the checked-in catalogs in `mixiopro/studio`:

| | Count | Source |
|---|---|---|
| Use cases | **42** — 17 `STUDIO`, 13 `IMAGE`, 6 `VIDEO`, 6 `AUDIO` | `api/agent-api/shared_schemas/use-cases.json` |
| Model entries | **75** (includes workflow pseudo-models such as `video-preproduction`) | `api/agent-api/shared_schemas/models.json` |
| Capability profiles / model bindings | 12 / 42 | `api/agent-api/shared_schemas/video-direction.json` |
| Presets | attached to 9 use cases via `presetSlots` | `api/agent-api/shared_schemas/presets.json` |

Re-derive before spending: prefer `studio_get_contract`. It returns a versioned, digested contract for a direct tool (`{ target: "tool", toolName }`), generation pair (`{ target: "generation", useCaseId, modelId }`), Studio element metadata (`{ target: "element", elementType }`), or open project settings (`{ target: "project-settings" }`). For generation, `studio_get_use_case_input_schema({ useCaseId, modelId })` remains a compatible generation-only read from the same UI resolution path (spec `specs/022-mcp-use-case-input-schema/spec.md`).

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- **Resolved scope — required.** You must be working against a project, plus the deepest scope you know (episode / scene / shot) that the user has explicitly confirmed. If it is not established in this session, **fetch the list and show it, numbered, in the same message as the question** (`studio_list_projects` / `studio_list_episodes`) so the answer is one character. Asking "which episode?" without the list is a failure — it hands the lookup back to the user. Resolve this *before* any expensive read; never guess an id, infer one from a title, or create something to avoid asking. See `mixio-project`.

## 1. Discovery tools — what each one actually returns

Registrations: `apps/app-kalaasetu/src/app/api/mcp/server.ts`.

| Tool | Returns | Omits / breaks |
|---|---|---|
| `studio_get_contract({ target, ... })` | **Preferred versioned contract read.** `target: "tool"` returns any hosted tool's input schema, examples, constraints, and applicable semantic rules; `"generation"` resolves a use case/model; `"element"` resolves Studio metadata; `"project-settings"` documents the open settings shape. Every result has `contractVersion` and `contractDigest`. | For a generation contract, pass `modelId` when the selected model is known. The digest identifies the exact contract read; fetch again when it changes rather than relying on this snapshot. |
| `studio_list_use_cases` | `id`, `label`, `outputType`, `description`, `supportedModels`, `count` | Filter by the requested artifact type (`VIDEO` for video; `all` for cross-type discovery). The live video catalog currently returns seven task-specific cases. Does **not** return `surfaces`, `media`, `parameters`, `presetSlots`, `intent`, or `studio`. `workflowId` is mapped but is always `undefined` — the field does not exist on `UseCaseDef` (server.ts:2938) |
| `studio_list_generation_models` | with `useCaseId`: `{ id, label }` per model. Unfiltered: `{ id, label }` × 75 | **Broken — do not rely on it.** `mediaType: "image"` returns `{models:[],count:0}`, verified. It filters on `m.mediaType \|\| m.outputType`, and `ModelDef` has neither field (`packages/shared/src/schemas/generation/schema.ts:771` — only `label`, `providers`, `pricing`, `prompting`, `roleSlotPolicy`, `videoReferenceBudget`, `organizationNameIncludes`), so `provider`, `mediaType`, `outputType` and `supportedUseCases` serialize away as `undefined` and the filter matches nothing (server.ts:2887). Use `supportedModels` from `list_use_cases`, or `model.options` from `studio_get_generation_catalog_detail`, instead |
| `studio_get_use_case_input_schema({ useCaseId, modelId })` | **The authoritative per-model contract.** JSON Schema 2020-12 for `{ prompt?, media, parameters }`, plus `supportedModels` and resolved `presets` | **Always pass `modelId`.** Omitting it resolves a different model and therefore a different schema: `image-hub` with no `modelId` yields `gpt_image_2` (auto is unsupported for `IMAGE`, so it falls back to `models[0]`), `cinematic-video` yields `ltx_2_3_quality_image_to_video` (auto rule). Throws `No model could be resolved for <id>` on the three model-less Studio use cases: `studio-lock-references`, `studio-storyboard-keyframes`, `studio-batch-image-generation`. Responses for the 9 preset-bearing use cases are large — they inline the full preset catalog |
| `studio_get_generation_catalog_detail({ useCaseId, modelId, surface, projectId })` | Same contract flat (`media[]`, `parameters[]` with `options`), plus `supportedActions` and `configDigest` | Needs `projectId`. Use it when you need action ids; the live `multi-shot-video` contract returns `generation.video` and `generation.video.batch` |
| `studio_cancel_studio_job({ jobId, projectId })` | `{ job: { id, status, previouslyTerminal }, message }` | **Exists** (server.ts:1951). Already-terminal jobs return their status without error. Earlier guidance in this skill that cancellation was HTTP-only was wrong |

## 2. Facts not exposed by the contract API

`studio_get_contract` makes tool, generation, element, and project-settings contracts reachable over MCP. The operational facts below are still outside those contracts; read the repo file or ask the user.

| Fact | Where it lives | What to do instead |
|---|---|---|
| **Relative generation cost** | Generation use case and output type | Video generation costs the most, image generation comes next, and other operations cost little. |
| **Model ranking / "when to use what"** | `models.json` → `autoSelection.rules`: ordered `preferredModels` per use case, output type and media signal | Image rules prefer `gemini_image`; video rules prefer a compatible H3 route. `STUDIO` use cases resolve defaults from their ordered model list and production settings |
| **Per-model input capability** | `video-direction.json` → `capabilityProfiles` + `modelBindings`: `profileId`, `supportedInputRoles`, `unsupportedInputRoles`, `promptMode`, `aspectHandling`, `lifecycle`, `routeId` | This is the real strengths/limits layer. A `prompted-frame-anchored-video` model (Seedance I2V, Kling 2.6 Pro, LTX, Grok) takes `primary` + `endFrame` and **rejects 7 other roles**; `prompted-text-video` models reject all 9. Table in `references/model-comparison.md`. Bindings inherit their profile's roles unless they override them (`packages/shared/src/schemas/generation/index.ts:resolveGenerationDirectionInputPolicy`) |
| **Reference caps** | `models.json` → `defaults.stillImageReferencePolicy.maxProviderImages` (**10**) with `coverageOrder`/`fillOrder`/`slotByRole`; `defaults.videoReferenceBudget.maxProviderImages` (**9**), overridden per model — listed Kling routes cap at **4** | Excess references are truncated by policy order, not rejected. Attach only the references that matter, in role order. |
| **Prompt length ceiling** | `models.json` → `prompting.promptMaxCharacters`, present on **15** of 75 models (nine Kling routes at 2500, four Svara/LTX routes at 5000, Grok at 4096, and ElevenLabs sound effects at 450); MiniMax H3 deliberately has no Mixio ceiling | Models without the field have no declared ceiling. Studio's own production path truncates against it (`getPromptMaxCharacters` in `production-job-preparation.ts`); you cannot read it over MCP |
| **Speed / quality tradeoff** | `models.json` → `providers[].requirements`: `balanced \| speed \| cost \| quality` | The **only** such signal in the catalog. There is no fps field, no max-resolution field, no benchmark or quality ranking anywhere in it. If asked which model is "best", say the catalog does not rank models and offer `autoSelection` order instead of inventing a comparison |
| **`surfaces` (studio vs generate)** | `use-cases.json` → `surfaces` | See §3. **`outputType` is not a proxy for it**: `image-edit`, `character-locking`, `refine-character-image`, `character-multi-angle` are `outputType: IMAGE` but `surfaces: ["studio"]`; the two `avgc-*` use cases are on both; `kling-multi-shot-video` has `surfaces: []` and appears in neither UI while still being submittable |

## 3. Normal use cases and production graph context

Use the normal catalog use case that matches the requested operation. Use
[`references/video-use-case-routing.md`](references/video-use-case-routing.md) for the route
table and Step 06 context, media, prompt, mention-map, and graph-readback procedure. Use
`production-*` image/keyframe workflows where their specialized still-image behavior is needed;
they are not the video-generation route for these skills.

The catalog use case selects available controls and media slots. The separate `context` envelope
sets the job's production scope and output policy. For an episode shot, submit the deepest known
`projectId`, `episodeId`, `sceneId`, and `shotId`, with `outputPolicy: "scoped_asset"`. Curate the
selected graph elements and explicitly pass the references and parameters required by the chosen
model. Do not infer graph attachment from a use-case name, UI surface, or job status; read the
resulting asset and its shot relation after completion.

Read `studio_list_use_cases({ outputType: "VIDEO" })` for current task-specific video cases.
Read the exact model schema before submission: supported models, media slots, durations, aspect
ratios, and optional controls can differ within the same use case.

**One job path bypasses the catalog entirely.** `submit_studio_job` accepts any `useCaseId` string, so absence from the catalog is not a rejection. `script-preproduction` is a backend workflow id (`EVENT_DRIVEN_AGNO_WORKFLOWS` in `apps/app-kalaasetu/src/services/job-runner.ts:80`) that the MCP tool's own description advertises, but it is **absent from `use-cases.json`** — so `list_use_cases` will never list it and `get_use_case_input_schema` throws `Unknown use case`. Submit it by id and do not try to discover or schema-check it. For script breakdown from this skill set, prefer `mixio-script-breakdown`, which persists through the breakdown primitives instead. The catalog's own screenplay use cases (`source-screenplay-analysis`, `localized-screenplay-adaptation`, `video-preproduction`) *are* listed and each has a single same-named pseudo-model. The same goes for parameter names: an invented `useCaseId` also means no schema, so nothing filters or warns about what you send with it.

### Verify graph placement

`context.outputPolicy: "scoped_asset"` requests a scoped output asset. After the job completes,
read the output element and query the target shot's elements/relations to confirm it is attached
to the exact `shotId`. `studio_get_job_status` returns lifecycle/tracking information, not proof
of graph placement. If the output exists without a `generated_for` relation, link that output
element to the shot with the project-scoped relation tool and read it back. Never use element
tags as a substitute for graph relations. Job status values: `PENDING`, `RUNNING`, `IN_QUEUE`,
`IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED`.

## 4. Parameters

**`aspect_ratio` has no global option list.** Options are per (use case × model), narrowed by the model's route policy (`models.json` → `providers[].routeCompiler.parameterPolicy.allowedValues`). Verified examples:

| Use case | Model | `aspect_ratio` enum |
|---|---|---|
| `production-generate-shot-keyframes` | `gemini_image` | `auto`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `21:9` |
| `image-hub` | `gpt_image_2` | `auto`, `1:1`, `16:9`, `9:16`, `21:9` |
| `cinematic-video` | `ltx_2_3_quality_image_to_video` | `auto`, `16:9`, `4:3`, `3:2`, `1:1`, `2:3`, `3:4`, `9:16` |

Read each enum from `get_use_case_input_schema` for the exact pair before submitting. `auto`, `duration`, and `resolution` support and value types differ by use case and model. Numeric selects may accept string and number spellings; submit the schema's declared type.

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
Default **model** when none is selected: `gemini_image` for image generation and sheets wherever supported, including production keyframes and grids. For video, select a model from the chosen normal use case using its project pin, task, input roles, and exact schema. A start/end model given a multi-keyframe shot may push middle frames into prompt-only context; choose a model that accepts the ordered references when every frame must be bound.

`keyframe_count` is a **closed set, not a range**: `1/2/3/4/6/8/9` for `production-generate-shot-keyframes` (default `1`), `4/6/8/10/12` for `-shot-keyframe-sequence` (default `6`). The 12 ceiling is 16 reserved output slots shared with background plates; `orchestrate_frames` does not raise it. For more frames, submit more jobs.

`orchestrate_frames: true` (already the default on the sequence path) makes the job return a plan and dispatch one child job per frame. Side effect: the server's own evaluation pass is skipped whenever it is true, so run `mixio-eval` yourself.

`sequence_notes` is appended verbatim to the planner's prompt; a caller-supplied `prompt` **replaces** Studio's auto-assembled shot-spec prompt. Leave `prompt` unset and use `sequence_notes` unless you mean to author the whole prompt.

### Read `schemaWarnings` on every submit — it is not optional

Per spec 022, `input.parameters` is `.loose()` (so catalog parameters reach the backend) but is then **filtered to the derived schema's keys plus six workflow extensions** — `background_concurrency`, `frame_concurrency`, `multi_prompt`, `orchestrate_frames`, `reference_concurrency`, `shot_type` (`apps/app-kalaasetu/src/lib/generation-parameters.ts:18`). Dropped keys are reported **warn-only** in `schemaWarnings`; enum and type mismatches likewise warn and never block.

A job that "succeeded" with warnings ran **with your parameters removed**. Check `schemaWarnings` before polling, and treat any entry as a failed submission to redo — not as noise. Filtering falls open when the schema cannot be derived, so an unresolvable model never strips a valid submission.

## 5. Workflow

```
1. studio_list_use_cases({ outputType: requested type })     → choose the normal case for this task (VIDEO for video)
2. studio_get_project(projectId)                           → resolve the per-use-case model pin
3. studio_get_use_case_input_schema({ useCaseId, modelId }) → exact media slots + parameters
4. studio_list_references(projectId) → studio_get_element   → approved media URLs and variants (§6)
5. Compose prompt + schema-valid `input.media`/parameters + selectedElements; add paired
   mention maps and prompt `@tag`s whenever media is present (§6)
6. studio_submit_studio_job({ jobType: "video", model, useCaseId, prompt,
     input: { media, parameters }, context: { projectId, episodeId, sceneId, shotId,
       outputPolicy: "scoped_asset", contextSelectionMode: "curated" },
     selectedElements, slotReferences, slotTags, mentionMap,
     promptEnhancementMode: "off" })                       → job id + tracking + schemaWarnings
7. read schemaWarnings; if non-empty, stop, fix the input, then submit again
8. studio_get_job_status({ jobId, projectId })             → poll to COMPLETED
9. read the resulting output element and shot relations to verify `scoped_asset` placement
10. optionally record the terminal job using the [job-take report template](references/job-take-report.md)
11. mixio-eval before delivery; upload_file for local renders
```

### Step 2 — honor project defaults before you choose anything

`studio_get_project(projectId)` returns the user's own pinned choices. Confirmed present on live projects; treat them as overriding this skill's suggestions, and only differ when you say so.

### Prompt Enhancement Modes (`Auto` vs `Raw` vs `Review`)

Studio generation workflows support three prompt enhancement modes. For skill-managed jobs,
the prompt is composed from the approved shot contract and resolved references, so use Raw by
default to preserve that exact direction. Choose another mode only when the user asks for Studio
to rewrite or stage a revised prompt.

| Mode | Wire Value (`promptEnhancementMode`) | When to use |
|------|--------------------------------------|-------------|
| **Auto** | `"enhance"` | Studio may enrich and rewrite the prompt using linked character, location, camera, and style context. |
| **Raw** | `"off"` | **Use for verbatim prompts, custom LoRA trigger words, exact benchmark tests, or pre-crafted directions.** Bypasses all LLM prompt rewriting and sends your exact prompt directly to the generation model. |
| **Review** | `"enhance_and_review"` | Enhances the prompt and holds it for user inspection/editing before submitting the final GPU job. |

Pass `promptEnhancementMode` directly to `studio_submit_studio_job` or within `context.intent`:

```js
studio_submit_studio_job({
  jobType: "video",
  model: "hailuo_v3_reference_to_video",
  useCaseId: "multi-shot-video",
  prompt: compiledPrompt,
  input: { media, parameters },
  selectedElements,
  slotReferences,
  slotTags,
  mentionMap,
  promptEnhancementMode: "off",
  context: {
    projectId,
    episodeId,
    sceneId,
    shotId,
    outputPolicy: "scoped_asset",
    contextSelectionMode: "curated"
  }
})
```

For **Audio / Gemini TTS** (`text-to-speech`), raw transcript reading is controlled by `input.parameters.auto_enhance_ssml`:
- `auto_enhance_ssml: true` (default) — wraps transcript in SSML tags and performance directions.
- `auto_enhance_ssml: false` — reads the verbatim transcript text without performance guidance injection.

`settings.generation`: `defaultModelByUseCase` (video pins such as `cinematic-video` and `multi-shot-video`), `defaultParametersByUseCase`, `defaultDurationByUseCase`, `defaultAspectRatioByOutputType`, `defaultResolutionByOutputType`, `recommendedStylePresetIds`, `inferenceMode`.
`settings.studio`: `preferredVideoModel`, `videoDurationSeconds`, `defaultStylePrompt`, `defaultVideoShotMode`, `visualStyle`, `toneAndMood`, `cinematographyDirection`.

Resolve the per-use-case model and its parameter defaults together; a project-level aspect ratio
or old Studio preferred-model field cannot make an unsupported model/control valid. Also read
`settings.references` before creating references (`mixio-references`).

## 6. Resolve and bind approved reference media

Media slots require real URLs, not Payload media IDs. Resolve the approved character look or
location view and the URL using [`reference-media.md`](references/reference-media.md). For local
files, upload first; for external URLs, use `mixio-workspace`'s validated download-and-upload
fallback. Read the selected model's live schema for its exact media slots and cardinality.

### Link every job to everything it knows about

| Field | Shape | Why |
|---|---|---|
| `context` | `{ projectId, episodeId?, sceneId?, shotId?, outputPolicy: "scoped_asset", contextSelectionMode: "curated" }` | Deepest production scope plus requested output placement |
| `selectedElements` | `[{ id, type, identityKey?, mentionCode? }]` | Which characters/locations/props the prompt refers to. `type` ∈ `CHARACTER`, `LOCATION`, `PROP`, `SHOT`, `SCENE`. Also what a character look-binding fallback resolves against — see [reference media](references/reference-media.md) |
| `slotReferences` | `{ <schema-declared slot>: { url, variantId?, variantName? } or [...] }` | Explicit URL provenance and selected reference variant, using fields declared by the live tool contract |
| `slotTags` | `{ <referenceIdentityKey>: "@tag" }` | Binds each active reference identity to its exact semantic mention; see the [Prompt & Mention Sheet](references/prompt-mention-sheet.md) for key selection |
| `mentionMap` | `{ "@tag": "Human Label" }` | Binds that tag to a subject. **Both maps are required** for a tag to bind |
| `prompt` | authored string | Contains each exact `@tag` where the referenced asset acts; skill-managed video uses `promptEnhancementMode: "off"` |
| `input.media` | `{ <schema-declared slot>: { url } or [{ url }] }` | Actual media URLs; the selected model's schema defines valid slots and singular/array shape |

The MCP contract can derive mention data when references are provided. Skill-managed jobs still
send explicit `slotTags` and `mentionMap` with the authored prompt, and validate the serialized
shape before submitting.

### Mentions — binding an image to a subject (Universal across all models)

Sending two character images does not say which is which. Semantic `@tag` tokens in the authored
prompt do; the route compiler maps them into its provider grammar (H3 Ref2Vid uses indexed
`<Picture N>`/`<Video N>`/`<Audio N>` forms; other providers use their catalog grammar). Callers
do not author provider tokens directly.

This is a universal architectural requirement across every image, keyframe, storyboard, and video generation path and every model family (Hailuo, Kling, Seedance, Veo, Sora, Gemini, Wan, LTX, Flux, etc.). A provider may render the tag differently, but it still needs the semantic mention and its paired maps before compilation.

#### Mandatory Invariants

1. **Prompts MUST ALWAYS contain `@` mentions for all active assets/references** (e.g. `@asset1`, `@tony`, `@scene1`). Any asset passed via `media` (`primary`, `references`, `character_ref`, `location_ref`, `enhancer_context`, or another schema-declared slot) must be embedded in the prompt string where the subject acts. Plain descriptive prose without `@` tokens will fail grounding.
2. **Paired `slotTags` AND `mentionMap` are MANDATORY when media is present**: the maps use the exact active reference identity keys and semantic tags (`{ [referenceIdentityKey]: "@tag" }`, `{ "@tag": "Human Label / Description" }`). The pair is one-to-one: every active reference has one tag, every tag has a non-empty label, and neither map may contain an orphan entry. Prompt-only jobs with no media need no slot maps. The maps are top-level submit fields; see `references/prompt-mention-sheet.md` for key selection.

For identity key selection, canonical tag construction, and route-specific token grammar, use the
[Prompt & Mention Sheet](references/prompt-mention-sheet.md). Always author semantic `@tag`s and
let the selected route compile provider tokens; do not hand-write `Image 1`, `@Image1`, or
`<IMAGE_REF_1>` forms.

#### Multi-cut prompt serialization (`MULTI_CUT` shots)

`cuts[]` is never the effective prompt by itself. Serialize every populated per-cut field into
the model prompt, including framing/angle/lens/camera movement, action, blocking, and dialogue,
SFX, or ambient cues. Follow the exact route grammar and worked example in the
[Prompt & Mention Sheet](references/prompt-mention-sheet.md). That sheet is the pre-submit
artifact Step 06 validates. Never reduce a cut to shot type and action.

#### Preflight Gating Checklist (Step 06)

Before calling `studio_submit_studio_job` for any billable generation:
- [ ] **Asset coverage**: Flatten every schema-declared `input.media` slot (including inherited scene anchors and look-bound references); each reference identity key has exactly one `slotTags` entry.
- [ ] **Paired maps**: Both maps exist when media is non-empty; every `slotTags` value is a unique `@tag` with a non-empty `mentionMap` label.
- [ ] **Prompt embedding**: The effective prompt contains every mapped tag at least once where that asset acts. For a sequence use case with no caller `prompt`, validate `sequence_notes` plus the materialized shot prompt instead of treating the omission as a bypass.
- [ ] **No orphaned or colliding tags**: Reject unused `slotTags`/`mentionMap` entries, duplicate tag assignments, and any media asset without a map pair (`PROMPT_MENTION_MISSING`, `MENTION_MAP_UNPAIRED`, `MENTION_TAG_COLLISION`, or `MENTION_MAP_ORPHANED`).
- [ ] **No ungrounded prose**: Descriptive text may supplement a mention, but it never replaces the required `@tag` token.

The complete, model-specific submission shape is in
[`video-use-case-routing.md`](references/video-use-case-routing.md). Treat its example as illustrative and
include only slots and parameters accepted by the selected live schema.

## Audio

Reachable, undiscoverable by filter. `text-to-speech` and `voice-change` are `outputType: AUDIO`, which `list_use_cases`' enum cannot express — call it with `outputType: "all"`. Then the normal path: `get_use_case_input_schema({ useCaseId: "text-to-speech", modelId: "elevenlabs_tts_multilingual_v2" })` → `submit_studio_job`. Models: `elevenlabs_tts_multilingual_v2`, `gemini_3_1_flash_tts_preview`, `elevenlabs_speech_to_speech`. Lip-sync is `outputType: VIDEO`, not audio. Mixing and final assembly are not on the MCP surface at all.

## References

`references/model-comparison.md` — `autoSelection` ranking, model capability data, and per-model input-role capability. All three are catalog facts no MCP tool exposes.

`references/prompt-mention-sheet.md` — the pre-submit pairing sheet: slot key ↔ `@tag` ↔ mention label ↔ route token, with the per-model token table and H3 cut-line grammar.

`references/job-take-report.md` — optional per-job take report template; using it does not add a required metadata write or selection policy.
