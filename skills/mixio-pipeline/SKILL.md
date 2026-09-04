---
name: mixio-pipeline
description: "Run an episode from screenplay to delivered video as gated steps — detailed screenplay, anchor frames, reference audit, panel breakdown, continuity audit, shot planning, video generation — persisting progress and locking each step before the next. The entry point for a full episode, and the fallback whenever it's unclear which production skill applies — the others (mixio-sheets, mixio-reference-audit, mixio-script-breakdown, mixio-continuity, mixio-shot-planning) each assume you already know that's the one step you need."
version: 0.4.0
invoke: /mixio:pipeline
---

# Mixio Pipeline

The orchestrator. The other Mixio skills are tool surfaces (`mixio-episode`, `mixio-generate`, …); this one is the **order and the gates**. Generation is billable and non-deterministic, so the whole point is to burn tokens on text passes until the plan is airtight, then spend credits once.

Read the [native screenplay grammar](../mixio-episode/references/screenplay-grammar.md) before Step 01 and `references/shot-grammar.md` before authoring or auditing a breakdown. The former is Studio-parsed source syntax; the latter is the authored production vocabulary that `mixio-sheets`, `mixio-continuity`, and `mixio-shot-planning` assume.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- **Resolved scope — required.** You must be working against a project and an episode that the user has
  explicitly confirmed. If it is not established in this session, **fetch the list and show
  it, numbered, in the same message as the question** (`studio_list_projects` /
  `studio_list_episodes`) so the answer is one character. Asking "which episode?" without
  the list is a failure — it hands the lookup back to the user. Resolve this *before* any
  expensive read; never guess an id, infer one from a title, or create something to avoid
  asking. See `mixio-project`.
- A project (`mixio-project`) and an episode (`mixio-episode`)

## The steps

| # | Step | Owned by | Output locked into |
|---|------|----------|--------------------|
| 00 | **Preflight & Settings Lock** | this skill | `studio_update_project({ updates.settings })` + `studio_update_episode({ metadata.pipeline })` |
| 01 | **Detailed Screenplay** | this skill | `studio_upsert_screenplay({ projectId, episodeId, body })` (+ `studio_update_episode({ updates: { summary } })` for the logline) |
| 02 | **Anchor Frames** | `mixio-sheets` | CHARACTER/LOCATION refs + one anchor KEYFRAME per scene |
| 02.5 | **Reference Audit** | `mixio-reference-audit` | episode `metadata.pipeline.reference_audit` |
| 03 | **Deterministic Breakdown & Relational Audit** | `mixio-script-breakdown` | `studio_upsert_scene_packages` + `studio_link_graph` + episode `metadata.pipeline.breakdown_audit` |
| 04 | **Continuity Audit** | `mixio-continuity` | `studio_revise_shot_specs` + `studio_update_shot_state` |
| 05 | **Shot Planning** | `mixio-shot-planning` | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| 06 | **Video Generation** | `mixio-generate` | VIDEO elements + workspace uploads |

**Gate rule: never start a new production step until the preceding step is confirmed by the user.** Steps 01–04 operate as the autonomous Pre-Production Token Ralph Loop: internal corrective passes may move between those steps and immediately re-audit without another prompt. Do not start Step 05 until the loop has **0 blocking errors** and the user has approved the converged breakdown (see `references/pre-production-ralph-loop.md`). Announce the close explicitly, e.g. `Step 04 — Continuity Audit complete (0 blocking breaks). Pre-production Ralph loop converged. Breakdown locked. Moving to Step 05.`

## Step 00 — Full Project Preflight & Settings Locking

Everything downstream reads project settings. If Step 00 doesn't set them, Step 06 doesn't
fail — it inherits. `production-generate-shot-keyframes` renders at `aspect_ratio: '16:9'`
on `gpt_image_2` because that is the production default, not because anyone chose it
(`mixio-generate` §4). Model spread is roughly 70× on credits, so a model nobody picked is a
cost decision nobody made. Settle the contract here, write it to the project, and gate
Step 01 on the user confirming it.

### 1. Confirm the contract — options in the same message as the question

Six confirmations, presented the same way scope is: with the real options enumerated, so the
answer is one character. Never let one default silently.

| # | Confirm | Source of the legal values |
|---|---------|----------------------------|
| 1 | **Image model** — the keyframe model for every `production-*` keyframe use case | The six `production-generate-shot-keyframes` supports: `gemini-3.1-flash-lite-image`, `gpt_image_2`, `gemini_image`, `nano_banana_2`, `seedream_5_pro`, `seedream_5_lite`. Re-read `supportedModels` rather than trusting this list — the catalog grows |
| 2 | **Video model** — what Step 06 spends on | `supportedModels` from `studio_list_use_cases` for `production-generate-video`; quote credits from `mixio-generate/references/model-comparison.md` **before** the user picks |
| 3 | **Aspect ratios** — delivery + anchor (see §2 below) | `aspect_ratio` enum from `studio_get_use_case_input_schema({ useCaseId, modelId })` for the chosen pairs — there is no global list |
| 4 | **Resolution** — per output type and per video use case | Same schema read, and **many models expose no `resolution` parameter at all** (`gemini_omni_multishot` and `seedream_5_pro` have none; `veo_3_1` has one defaulting to `720p`). Confirm the parameter exists before locking a value for it |
| 5 | **Visual style / tone** — style, mood, cinematography, default style prompt | The user. This is direction, not a catalog value |
| 6 | **Reference policy** — `createPolicy`, `variantPolicy`, `variantVocabulary` | Closed sets: `allow` · `link_only` · `propose`, and `open` · `closed` (`mixio-references`) |

Read the project first with `studio_get_project` and show what is *already* set — a configured
project needs a diff confirmed, not a fresh interrogation. On a project whose settings are
already correct, say so and move on; Step 00 is a checkpoint, not a form.

The reference policy is the one the user is least likely to have an opinion about and the one
that most changes agent behaviour: `link_only` forbids Step 02 and Step 03 from creating
references at all, and `closed` constrains every variant name to `variantVocabulary`. Ask for
it explicitly rather than inheriting the permissive defaults (`allow`, `open`, `{}`) by omission.

### 2. The frame contract

Two ratios, never re-derived after this step:

- `aspect_ratio` — the **delivery** ratio (`9:16` vertical for microdrama, `16:9` for landscape).
- `anchor_aspect_ratio` — the ratio for **anchor frames only**, deliberately wider than delivery (`16:9` when delivering `9:16`).

Anchors are rendered wide on purpose: a wide master of the set gives every downstream shot a shared spatial truth to crop into, so left/right and near/far stay consistent between a wide and a close-up. Delivery shots then render at `aspect_ratio`.

### 3. Write the settings — read-modify-write, always

`studio_update_project`'s `updates.settings` is an opaque object that **replaces** the whole
settings blob; it is not a merge, and the tool schema does not validate the keys inside it. Send
a partial and you silently drop every other setting on the project — including the reference
policy someone configured in Studio. Fetch, merge, send back whole:

```
const { settings } = await studio_get_project({ projectId })

// `confirmed` contains the choices the user just approved and the values
// returned by the selected model schemas. Never replace a nested map with a
// partial example: settings are opaque and the update is a whole-blob write.
const confirmed = {
  imageModel: userConfirmed.imageModel,
  videoModel: userConfirmed.videoModel,
  deliveryAspectRatio: userConfirmed.deliveryAspectRatio,
  anchorAspectRatio: userConfirmed.anchorAspectRatio,
  plannedRuntimeSeconds: userConfirmed.plannedRuntimeSeconds,
  imageResolution: userConfirmed.imageResolution,
  videoResolution: userConfirmed.videoResolution,
  visualStyle: userConfirmed.visualStyle,
  toneAndMood: userConfirmed.toneAndMood,
  cinematographyDirection: userConfirmed.cinematographyDirection,
  defaultStylePrompt: userConfirmed.defaultStylePrompt,
  references: userConfirmed.references
}
const videoSchema = await studio_get_use_case_input_schema({
  useCaseId: "production-generate-video",
  modelId: confirmed.videoModel
})
const videoHasResolution = Boolean(
  videoSchema?.properties?.parameters?.properties?.resolution
)
const existingVideoParameters =
  settings?.generation?.defaultParametersByUseCase?.["production-generate-video"]

studio_update_project({ projectId, updates: { settings: {
  ...settings,
  generation: {
    ...settings?.generation,
    defaultModelByUseCase: {
      ...settings?.generation?.defaultModelByUseCase,
      "production-generate-shot-keyframes": confirmed.imageModel,
      "production-generate-video": confirmed.videoModel
    },
    defaultAspectRatioByOutputType: {
      ...settings?.generation?.defaultAspectRatioByOutputType,
      IMAGE: confirmed.anchorAspectRatio,
      VIDEO: confirmed.deliveryAspectRatio
    },
    defaultResolutionByOutputType: {
      ...settings?.generation?.defaultResolutionByOutputType,
      IMAGE: confirmed.imageResolution
    },
    defaultParametersByUseCase: {
      ...settings?.generation?.defaultParametersByUseCase,
      "production-generate-video": {
        ...existingVideoParameters,
        ...(videoHasResolution ? { resolution: confirmed.videoResolution } : {})
      }
    }
  },
  studio: {
    ...settings?.studio,
    preferredVideoModel: confirmed.videoModel,
    visualStyle: confirmed.visualStyle,
    toneAndMood: confirmed.toneAndMood,
    cinematographyDirection: confirmed.cinematographyDirection,
    defaultStylePrompt: confirmed.defaultStylePrompt
  },
  references: {
    ...settings?.references,
    ...confirmed.references
  }
}}})
```

`defaultAspectRatioByOutputType` is keyed by output type (`IMAGE`, `VIDEO`) and
`defaultModelByUseCase` by use case id. **Resolution splits across two keys in practice**:
configured projects set `defaultResolutionByOutputType` for `IMAGE` only, in image vocabulary
(`1k`, `2k`), and carry video resolution as `defaultParametersByUseCase[useCaseId].resolution`
in model vocabulary (`720p`, `768P`). Writing `defaultResolutionByOutputType: { VIDEO: ... }` is
inert on a model that has no `resolution` parameter. Set the video
model in both `generation.defaultModelByUseCase` and `studio.preferredVideoModel`, since the two
surfaces read different keys. `visualStyle`, `toneAndMood`, `cinematographyDirection` and
`defaultStylePrompt` are the user's words, kept short enough to survive prompt assembly. The full
key list for `settings.generation` and `settings.studio` lives in `mixio-generate`; the
`settings.references` contract and its defaults live in `mixio-references`.

Then **read it back** with `studio_get_project` and show the resolved settings. Nothing rejects a
misplaced key, so a typo persists as passthrough and is only visible on the read.

### 4. Persist the frame contract on the episode

Settings are project-scoped and outlive the episode; the frame contract is per-episode:

```
studio_update_episode({ episodeId, updates: { metadata: {
  pipeline: {
    aspect_ratio: "9:16",
    anchor_aspect_ratio: "16:9",
    planned_runtime_seconds: confirmed.plannedRuntimeSeconds,
    step_00: "complete"
  }
}}})
```

### Gate

**Step 01 does not start until Step 00 is confirmed.** Announce the close with the values read
back from `studio_get_project`, not just the word complete. For example:
`Step 00 — Preflight complete. ${resolved.imageModel} / ${resolved.videoModel}, delivery ${resolved.deliveryAspectRatio}, anchors ${resolved.anchorAspectRatio}, image ${resolved.imageResolution}, video ${resolved.videoResolution ?? "model default"}, references ${resolved.references.createPolicy}+${resolved.references.variantPolicy}. Moving to Step 01.` If the user later
changes a model or a ratio, that is a re-entry into Step 00 and it invalidates anchors rendered
at the old ratio — say so rather than quietly re-rendering one scene.

## Step 01 — Detailed Screenplay

Ask what the user already has, and offer the three real answers rather than an open prompt:

1. **Synopsis only** — you write the script, then get sign-off.
2. **Script only** — you parse it; derive the synopsis yourself.
3. **Both** — synopsis for intent; persist the normalized screenplay as the breakdown source of truth.

Then write/normalize to standard screenplay form per the [native screenplay grammar](../mixio-episode/references/screenplay-grammar.md). Every scene must include four core components: **sluglines** (`INT./EXT. — LOCATION — TIME`), **action beats**, **character cues/dialogue**, and **audio/SFX design paragraphs** (`[SFX: ...]`, `[Ambient: ...]`). Set every recurring physical object, prop, and prominent setting element in `ALL CAPS` on first mention (`BED`, `BEDSIDE TABLE`, `NAPOLI POSTER`, `TABLET`, `PHONE`) — those CAPS tokens are what Step 03 extracts and Step 04 greps for prop continuity.

Before writing, call `studio_list_references({ projectId, limit })` and build the valid mention catalog from its `mentionableLooks`. Reuse those exact `#name.variant[.view]` tokens for existing Cast & World entities—never hand-construct one. A two-segment mention is complete when a look has no views. Validate all `#` mentions (probed via `studio_resolve_mention`): resolve all `UNRESOLVED_ENTITY`, `UNRESOLVED_LOOK`, or `AMBIGUOUS` tokens (0 unmapped tokens gate) before proceeding. Use `~location.landmark[.placement]` for advisory spatial continuity locks.

For explicit director intent that must override inference, place a standalone `[Key: Value · Key: Value]` paragraph immediately before the beat it governs. The 11 recognized keys are `Camera`, `Camera Movement`, `Lighting`, `Mood`, `Blocking`, `Background`, `Location`, `Shot Type`, `SFX`, `Ambient`, and `Lens`.

Persist with `studio_upsert_screenplay({ projectId, episodeId, body })`, **not** `studio_update_episode({ script })`. A screenplay is its own per-episode element and a non-empty body—draft included—wins over raw Idea/Story `script`/`fullScript` in Step 03. `upsert_screenplay` is idempotent and always writes a draft; Studio's human Screenplay view performs approval separately. Persist only the logline with `studio_update_episode({ episodeId, updates: { summary } })` when needed.

## Step 02 — Anchor Frames

→ `mixio-sheets`. Extract the location list and cast from the selected screenplay source, get a reference image per location and a turnaround sheet per character, then render one **anchor frame per scene** at `anchor_aspect_ratio`. Locations with no reference are marked `TEXT-ONLY` and grounded in screenplay text alone — flag them, don't silently invent geography.

## Step 02.5 — Reference Audit

→ `mixio-reference-audit`. Runs after sheets so references *should* have images, and catches what was missed:

- **Completeness** — every CAPS entity in the script has a reference; high-usage ones have images
- **Consistency** — name/description vs attached image (gender, age, build mismatches)
- **Duplicates** — fuzzy name matching, alias candidates, variants confused as separate refs
- **Metadata quality** — missing `visualAnchor`, `lighting`, `setting` that downstream prompts need
- **Policy compliance** — `createPolicy`, `variantVocabulary` adherence
- **Look-binding integrity** — a bound `lookRef` that no longer resolves to a real variant, which otherwise renders the default look silently

Part of the Pre-Production Token Ralph Loop (`references/pre-production-ralph-loop.md`): blocking findings are auto-remediated (for example, registering a missing reference, attaching a valid look variant, or correcting a stale binding) and re-checked until **0 blocking errors** remain before Step 03. Advisory findings are presented for acknowledgment. This is the cheapest place to catch a reference problem — later detection costs re-renders.

## Step 03 — Deterministic Script Breakdown & Relational Audit

→ `mixio-script-breakdown`, which owns the canonical schemas, the two camera vocabularies (authoring conventions, not validated), the mapping from shot-grammar prose onto persistable keys, and the immediate post-breakdown relational audit. One scene at a time. Emit a `STAGING` block for the scene, then numbered shots using the field schema in `references/shot-grammar.md`. Non-negotiables:

- **100% Canonical Fields**: The seven required canonical fields (`shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, `duration`) must all carry real, non-placeholder values. Zero `""`, `"TBD"`, `"tbd"`, `"n/a"`, `"unknown"`, `"none"`, or `"null"` strings — placeholders cause blank renders downstream.
- **Continuous Float Duration**: Every shot carries a `duration` in seconds (continuous float 1.0–60.0s). Batching (Step 05) and cost estimates are arithmetic on this field.
- **Anchor Attachment & Spatial Markers**: Every shot names its anchor (`Lighting: as Anchor 1`) or is marked `TEXT-ONLY`. Intra-shot beats other shots depend on get a marker — `[M1]`, `[M2]`.
- **Audio/SFX Decomposition**: Every shot maps audio cues into structured `audio`: `{ dialogue?: string, sfx?: string, ambient?: string }`. Standalone `[SFX: ...]` and `[Ambient: ...]` paragraphs map verbatim to `audio.sfx` and `audio.ambient`.
- **Entity ID Graph Linking**: Persist with `studio_upsert_scene_packages` (see `mixio-episode`), passing resolved entity IDs in `linked_character_ids`, `linked_location_ids`, `linked_prop_ids` (mapped from Cast & World context) along with human-readable names (`character_links`, `location_links`, `prop_links`).
- **Per-Shot Appearance State**: Immediately call `studio_link_graph` with `relationType: "appears_in"` for every character appearing in each shot, binding `appearanceState` (`wardrobe`, `hairState`, `condition`, `carriedProps`, `emotionalState`, `lookRef`, `continuityNotes`).
- **Immediate Relational Audit**: Execute a 3-point audit before closing Step 03:
  1. *Canonical Fields Completeness*: 100% of shots have all 7 canonical fields populated with valid data.
  2. *Graph & ID Integrity*: All linked entity IDs exist in Cast & World (0 orphaned links), and `appears_in` relations exist for all active characters.
  3. *Scope & Duration Reconciliation*: Total shot durations sum to the screenplay scope runtime.
  Emit the audit summary table and record the result into episode `metadata.pipeline.breakdown_audit`.

## Step 04 — Continuity Audit

→ `mixio-continuity`. Four passes: blocking map → checks → report → corrections. Text-only, before any pixels. Emits corrected shots and a per-shot clean/dirty verdict.

**Pre-Production Token Ralph Loop:** Persist the root-cause correction, immediately rerun the audit, and loop back through reference remediation when a missing or stale look caused the break. Do not advance until continuity and reference audits both report zero blocking errors.

## Step 05 — Shot Planning

→ `mixio-shot-planning`. Three decisions per shot, then batching:

1. **Archetype / Method** — classify each shot into one of 5 structural archetypes: `GRID` (multi-panel/montage), `SEQUENCE` (multi-beat sequence), `MASTER_ANCHOR_MULTI_SHOT` (coverage cropped from wide scene anchor), `SINGLE` / `DUAL_FRAME` (standard keyframe interpolation), or `T2V` (direct text-to-video).
2. **Model** — match to best available model based on shot characteristics (action density → Seedance, cinematic camera → Veo, establishing → Sora, etc.).
3. **Execution & Feasibility Audit** — validate duration vs model max, action density (`actions / duration`), dialogue speaking rate (`words / duration`), reference readiness, and **mandatory prompt `@` mentions + paired `slotTags`/`mentionMap` verification**. Every prompt referencing media assets must embed explicit `@tag` tokens.

Then group into generation batches per model-group (different models have different ceilings). Emit a `PRODUCTION SUMMARY` with per-model costs, archetype distribution, keyframe/video job counts, estimated credit costs, and high-risk cross-model boundaries. Where a shot or scene has a bound look, carry the resolved `variantId`/`variantName` into the plan so Step 06 declares it directly (see `mixio-generate`). Gate: require explicit user budget approval before Step 06.

## Step 06 — Video Generation

→ `mixio-generate`, batch by batch, keyframes first then video. Ask before spending unless the user has said otherwise. Offer the three permission levels once, at the top of Step 06, and record the answer:

- **Always allow** — generate without asking.
- **Ask before video** — images are cheap, video is not; this is the sensible default.
- **Always ask** — confirm every job.

**Preflight Gating (Mandatory Invariant across all models before submit):**
- Verify that every prompt string explicitly embeds `@tag` tokens (e.g. `@asset1`, `@tony`, `@scene1`) for all active media assets in `input.media` (`primary`, `enhancer_context`, `character_ref`, `location_ref`). This applies to all generation jobs (keyframes, storyboard grids, video renders) across all model families (Hailuo, Kling, Seedance, Veo, Sora, Gemini, Wan, etc.).
- Verify that `slotTags` and `mentionMap` are present and paired. Plain descriptive prose without `@` tags prevents the prompt materializer and provider compilers from mapping assets to model tokens (`Image 1`, `@Image1`, `@tag`) or performing subject grounding, causing models to guess identity. Never submit ungrounded media jobs.

**Use case IDs for this step:**
- Keyframes, shot already locked by Step 04: `production-generate-shot-keyframes` with `keyframe_count: 1`, **one job per beat**. Our prompt is used verbatim, nothing re-plans it, and the sequence planner's diversity gate cannot reject a deliberate hold. Pass the previous beat's keyframe as a reference to chain continuity forward.
- Keyframes, beats you want invented for you: `production-generate-shot-keyframe-sequence`. Leave `prompt` unset — a caller prompt *replaces* Studio's shot-spec assembly — and put your direction in `sequence_notes`, which is appended to the planner's prompt instead.
- Video: `production-generate-video`

Do **not** use `keyframe-sequence` — that is the Generate-page version (`outputType: IMAGE`, `surfaces: ["generate"]`) and output will not land under the shot even with correct `context`.

**Run eval yourself.** The server's own evaluation pass is skipped whenever `orchestrate_frames` is true, which is the default on the production sequence path — so nothing checks the rendered frames unless you do. Run `mixio-eval` per batch against the claims the text layer actually made: `identity_consistency`, `location_consistency`, `lighting_consistency`, `composition_consistency`, `prop_consistency`. Cross-model batch boundaries from Step 05 are where to look first.

After each batch, set shot state (`approved` / `needs_revision`) with `studio_update_shot_state` so the canvas reflects reality.

**Final assembly is out of scope for this tool surface.** None of the 39 MCP tools stitch, concatenate, export, or render a timeline — the pipeline delivers approved per-batch video, not a finished cut. Say so rather than implying a single deliverable file is reachable. Audio *is* reachable (`text-to-speech` and `voice-change`, the catalog's two `outputType: AUDIO` use cases, through `studio_submit_studio_job` — see `mixio-generate`), so a narration or dialogue track can be generated per shot even though mixing cannot.

## Progress state — how to resume

Mixio has no dedicated shared-memory store, so pipeline state lives in existing metadata. Write it at every step close:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  aspect_ratio, anchor_aspect_ratio,
  step_00: "complete", step_01: "complete", step_02: "complete", step_02_5: "complete",
  step_03: "complete", step_04: "complete",
  step_05: "not_started", step_06: "not_started",
  anchors: { "1": "<keyframe-element-id>" },
  reference_audit: { checked: 12, blocking: 0, advisory: 1 },
  breakdown_audit: {
    total_scenes: 3, total_shots: 18, total_duration: 84.5,
    canonical_fields_complete: "100%", cast_world_links_valid: true,
    unresolved_entities: 0, appearance_states_bound: 24
  },
  pre_production_loop: {
    status: "converged",
    iterations: 2,
    reference_audit: { checked: 12, blocking: 0, advisory: 1 },
    continuity_audit: { total_shots: 14, breaks_auto_corrected: 2, remaining_breaks: 0 }
  }
}}}})
```

| Pipeline state | Where it lives in Mixio |
|---|---|
| Locked models, resolution, style, reference policy | project `settings.generation` / `settings.studio` / `settings.references` |
| Source (screenplay, synopsis, aspect ratios) | SCREENPLAY `body` (or episode `script` only as fallback), episode `summary`, `metadata.pipeline` |
| Locations | LOCATION references + `locationDetails` (`mixio-references`) |
| Reference audit results | episode `metadata.pipeline.reference_audit` |
| Relational breakdown audit results | episode `metadata.pipeline.breakdown_audit` |
| Pre-production Ralph loop convergence | episode `metadata.pipeline.pre_production_loop` |
| Scenes and direction | scene elements via `studio_upsert_scene_packages` |
| Step progress | episode `metadata.pipeline` |
| Shot plan (method/model/batch) | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| Rendered assets and video | KEYFRAME / VIDEO elements + `upload_file` URLs |

On resume, read `studio_get_project` for the locked settings and `studio_get_episode` (cheap) for pipeline state, then query the episode's `SCREENPLAY` element (`studio_query_elements` with `type: "SCREENPLAY"` and `tags: { episodeId }`) before reusing source text. Do not substitute a stale `fullScript` when a non-empty screenplay body exists; avoid `studio_get_production_context` until its graph detail is actually needed.

## Workflow

```
00. studio_get_project → studio_update_project(settings) → studio_update_episode(metadata.pipeline) → GATE
┌── Pre-Production Token Ralph Loop (01 ↔ 02 ↔ 02.5 ↔ 03 ↔ 04) ────────────────────────┐
│ 01. screenplay → studio_upsert_screenplay({ body })                                   │
│ 02. /mixio:sheets                → character + location sheets, anchor per scene       │
│ 02.5 /mixio:reference-audit      → auto-remediate blocking reference/look errors        │
│ 03. /mixio:script-breakdown      → studio_upsert_scene_packages + studio_link_graph    │
│                                    → relational audit → metadata.pipeline.breakdown_audit│
│ 04. /mixio:continuity            → auto-correct specs, then re-audit                    │
└─────────────────────────────────── ↺ iterate until 0 blocking errors ──────────────────┘
  → GATE: Pre-production converged & breakdown locked
05. /mixio:shot-planning                           → method + model + feasibility + batches + PRODUCTION SUMMARY → GATE (cost approval)
06. /mixio:generate per batch → studio_update_shot_state → /mixio:eval before delivery
```

## Notes

- Steps 01, 02.5, 03, 04, 05 cost nothing but tokens. Do not shortcut them to reach generation faster; a continuity break found in Step 04 costs a paragraph, the same break found in Step 06 costs a re-render.
- The Ralph Loop stops after three automated correction cycles per scene. If a blocking issue persists, present a focused user decision rather than silently forcing a creative change.
- If the user jumps straight to "generate this script", still run 01→05 — just run them fast and present each gate as a short confirm rather than a discussion.
- Re-entering an earlier step invalidates the later ones. Editing Step 03 after Step 05 means re-planning; say so instead of patching one batch.
- Step 02.5 catches reference problems that Step 02 should have resolved. If sheets were skipped or rushed, 02.5 surfaces the gaps. It's a safety net, not a replacement for doing sheets properly.
