---
name: mixio-pipeline
description: "Run an episode from screenplay to delivered video as gated steps — detailed screenplay, anchor frames, reference audit, panel breakdown, continuity audit, shot planning, video generation — persisting progress and locking each step before the next. The entry point for a full episode, and the fallback whenever it's unclear which production skill applies — the others (mixio-sheets, mixio-reference-audit, mixio-script-breakdown, mixio-continuity, mixio-shot-planning) each assume you already know that's the one step you need."
version: 0.4.2
invoke: /mixio:pipeline
---

# Mixio Pipeline

The orchestrator. The other Mixio skills are tool surfaces (`mixio-episode`, `mixio-generate`, …); this one is the **order and the gates**. Generation is non-deterministic, so use text passes to resolve production issues before rendering. Video generation costs the most, image generation comes next, and other operations cost little.

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
| 00 | **Preflight & Settings Lock** | this skill | `studio_update_project({ projectId, updates: { settings } })` + `studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline } } })` |
| 01 | **Detailed Screenplay** | this skill | `studio_upsert_screenplay({ projectId, episodeId, body })` (+ `studio_update_episode({ projectId, episodeId, updates: { summary } })` for the logline) |
| 02 | **Reference Packs & Anchor Frames** | `mixio-sheets` | Confirmed `metadata.pipeline.reference_pack_inventory` + approved CHARACTER/LOCATION packs + one anchor KEYFRAME per scene |
| 02.5 | **Reference Audit** | `mixio-reference-audit` | episode `metadata.pipeline.reference_audit`, including every required look/view's visual evidence or recorded user override (rerun at Step 05 if actual shot zones expose a gap) |
| 03 | **Deterministic Breakdown & Relational Audit** | `mixio-script-breakdown` | `studio_upsert_scene_packages` + `studio_link_graph` + episode `metadata.pipeline.breakdown_audit`; use composed relation writes when the inventory maps non-default character looks |
| 04 | **Continuity Audit** | `mixio-continuity` | `studio_revise_shot_specs` + `studio_update_shot_state` |
| 05 | **Shot Planning** | `mixio-shot-planning` | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| 06 | **Video Generation** | `mixio-generate` | VIDEO elements + workspace uploads |

**Gate rule: never start step N+1 until step N is confirmed by the user.** The Pre-Production Token Ralph Loop is limited to safe text and graph corrections across Step 01, Step 02.5, and Step 04; Step 03 is re-audited only when one of those corrections changes a shot or relation. Step 02's reference renders and anchors remain a separately confirmed step: do not enter an image-generation use case from the loop. The loop re-checks every safe correction until it reaches **0 unacknowledged blocking errors and every required visual row has reviewed evidence or a recorded user override**, then asks the user to approve the converged breakdown before Step 05 shot planning (see `references/pre-production-ralph-loop.md`). Step 05 performs a final check against actual camera zones; a newly required view returns to Step 02 for user confirmation and image review before downstream steps resume. Announce the close explicitly, e.g. `Step 04 — Continuity Audit complete (0 blocking breaks). Pre-production Ralph loop converged. Breakdown locked. Ready for Step 05 approval.`

## Step 00 — Full Project Preflight & Settings Locking

Everything downstream reads project settings. If Step 00 doesn't set them, later steps inherit
defaults. Use `gemini_image` for image generation and sheets wherever the use case supports it.
Use the H3 route that fits each video's input contract: H3 Ref2Vid for ordered keyframes and
reference-to-video, H3 I2V for a start frame, and H3 T2V for prompt-only video. An existing
project setting or explicit model selection takes precedence. Settle any remaining delivery
settings here, write them to the project, and gate Step 01 on the user confirming the contract.

### 1. Confirm the contract — options in the same message as the question

Seven settings, presented with their live legal options. For image and video models, show the
defaults above as the preselected recommendations and ask only when the project already pins a
different model or a route-specific contract makes that default unavailable.

| # | Confirm | Source of the legal values |
|---|---------|----------------------------|
| 1 | **Image model** — the keyframe model for every `production-*` keyframe use case | `gemini_image` is the default when supported; re-read `supportedModels` to confirm it remains available |
| 2 | **Video model** — what Step 06 uses | Prefer H3 Ref2Vid for ordered keyframes/reference-to-video, H3 I2V for a start frame, and H3 T2V without an image; confirm against `supportedModels` and the live schema |
| 3 | **Aspect ratios** — delivery + anchor (see §2 below) | `aspect_ratio` enum from `studio_get_use_case_input_schema({ useCaseId, modelId })` for the chosen pairs — there is no global list |
| 4 | **Resolution** — per output type and per video use case | Same schema read, and **many models expose no `resolution` parameter at all** (`gemini_omni_multishot` and `seedream_5_pro` have none; `veo_3_1` has one defaulting to `720p`). Confirm the parameter exists before locking a value for it |
| 5 | **Visual style / tone** — style, mood, cinematography, default style prompt | The user. This is direction, not a catalog value |
| 6 | **Reference policy** — `createPolicy`, `variantPolicy`, `variantVocabulary` | Closed sets: `allow` · `link_only` · `propose`, and `open` · `closed` (`mixio-references`) |
| 7 | **Shot length** — multi-cut 10–15s (default) vs panel 2.5–4.5s | §3 below; `settings.studio.videoDurationSeconds` (open string, no enum) |

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

### 3. Shot length & multi-cut route

Two shot-length contracts, confirmed once and never re-derived downstream:

- **`multi_cut` (default)** — shots run **10–15s**, planned as one native multi-cut video job with
  per-cut specs persisted on the shot (`cuts[]`, see `references/shot-grammar.md`). Write
  `settings.studio.videoDurationSeconds = "10-15"` and prefer
  `settings.studio.preferredVideoModel = "hailuo_v3_reference_to_video"` — H3 Ref2Vid accepts
  `auto,5–15` seconds on `multi-shot-video` and is the first/default model of both
  `multi-shot-video` and `production-generate-video`.
- **`panel`** — short single-cut shots (2.5–4.5s). Write
  `settings.studio.videoDurationSeconds = "2.5-4.5"` and, when a Studio bias is wanted,
  `settings.studio.defaultVideoShotMode = "single-shot"`.

Record the mode on the episode next to the frame contract:
`metadata.pipeline.shot_contract = { mode: "multi_cut", band: "10-15" }` (or
`{ mode: "panel", band: "2.5-4.5" }`). `defaultVideoShotMode` accepts open strings, but the only
Studio-known biases are `single-shot` / `multi-keyframe` / `grid` — never write an invented value
there; the mode itself lives in `shot_contract`.

**13–15s is only reachable through the `multi-shot-video` use case** — `production-generate-video`'s
H3 duration enum is `{5,6,8,10,12}` (max 12) — so multi-cut model routing (H3 Ref2Vid first, then
seedance → kling → gemini ≤10s → SEQUENCE snap-to-enum) is owned by `mixio-shot-planning`
(`references/model-matching.md`).

### 4. Write and read back

`updates.settings` replaces the complete settings object. Read the project, merge every nested
map, write the whole object, then read it back before closing Step 00. The global `IMAGE` and
`VIDEO` defaults use the delivery ratio; every anchor job supplies `anchor_aspect_ratio`
explicitly. Use [the preflight settings recipe](references/preflight-settings.md) for the exact
read-modify-write payload, resolution routing, and per-episode frame-contract write.

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

Before writing, call `studio_list_references({ projectId, limit })` and build the valid mention catalog from its `mentionableLooks`. Reuse those exact `#name.variant[.view]` tokens for existing Cast & World entities—never hand-construct one. A two-segment mention is complete when a look has no views. If the screenplay requires a variant/view that is not registered yet, describe it in prose and the Step 02 inventory; do not invent a token. Once Step 02 has approved and registered it, add an exact returned token if needed. Validate every remaining `#` mention with `studio_resolve_mention` and resolve all `UNRESOLVED_ENTITY`, `UNRESOLVED_LOOK`, or `AMBIGUOUS` tokens before Step 03. Use `~location.landmark[.placement]` for advisory spatial continuity locks.

For explicit director intent that must override inference, place a standalone `[Key: Value · Key: Value]` paragraph immediately before the beat it governs. The 11 recognized keys are `Camera`, `Camera Movement`, `Lighting`, `Mood`, `Blocking`, `Background`, `Location`, `Shot Type`, `SFX`, `Ambient`, and `Lens`.

Persist with `studio_upsert_screenplay({ projectId, episodeId, body })`, **not** `studio_update_episode({ projectId, episodeId, updates: { script } })`. A screenplay is its own per-episode element and a non-empty body—draft included—wins over raw Idea/Story `script`/`fullScript` in Step 03. `upsert_screenplay` is idempotent and always writes a draft; Studio's human Screenplay view performs approval separately. Persist only the logline with `studio_update_episode({ projectId, episodeId, updates: { summary } })` when needed.

## Step 02 — Reference Packs and Anchor Frames

→ `mixio-sheets`. Read the selected screenplay and existing references, then build a user-reviewable matrix of script-required character variants and location configurations × camera-view looks. A character's approved sheet is the default; add only needed age/clothing combinations. A location variant names the scenario-specific space/configuration and its labeled images are camera views. Reuse supplied images only for rows they actually cover. Confirm the inventory and first billable image-render round before generation, then reconfirm before each retry. Missing or unapproved rows stay blocking. Render one **anchor frame per scene** only after required reference packs are ready, with an explicit `anchor_aspect_ratio`.

### Reference Enrichment (do this before Step 02.5)

Sheet-building creates the reference images, but the **structured detail fields** are what make those images reusable for generation. This enrichment phase must complete before Step 02.5 validates, because Step 03 emits references as **shallow stubs** (`name`, `description`, `attributes` only) and never writes `characterDetails`/`locationDetails`. If enrichment is skipped here, those fields are empty for the whole episode.

For each character, write the full profile via `studio_update_reference`:
```
characterDetails: { role, age, build, height, skin, eyes, hair,
  distinctiveFeatures, visualAnchor, wardrobeNotes, ... }
```
The load-bearing fields prompt materializers in Steps 05/06 depend on: **`build`, `hair`, `skin`, and `visualAnchor`** — `visualAnchor` is the single identity anchor repeated in every shot prompt.

For each location reference, write the place-wide spatial sheet via `studio_update_reference` and map every required camera view to its exact location variant:
```
locationDetails: { setting, spatialLayout, accessPoints, keyLandmarks,
  depthAxes, lightSources, lighting, surfaces, palette, ... }
```
The load-bearing fields: **`setting`, `lighting`, `spatialLayout`, and `depthAxes`** — `lighting` is what anchor-frame generation needs to avoid guessing.

This is the only place structured reference detail is populated; Step 02.5 gates on the HIGH-severity fields (`visualAnchor` for characters, `setting`/`lighting` for locations) and the complete approved variant/view inventory before Step 03. See `mixio-sheets` for the full field schema.

## Step 02.5 — Reference Audit

→ `mixio-reference-audit`. Runs after sheets so references *should* have images, and catches what was missed — including whether the **Reference Enrichment** phase (above) actually populated the structured fields:

- **Completeness** — every CAPS entity in the script has a reference; screenplay-evidenced variants/configurations/views are mapped in a confirmed inventory, and every required row is approved
- **Consistency** — name/description vs attached image (gender, age, build mismatches)
- **Variant/view readiness** — screenplay-evidenced character age/clothing looks and location configuration × camera-view rows are represented in the confirmed inventory and have approved images; compare stable location landmarks, axes, and palette across views/configurations
- **Visual readiness** — character deformation/identity/wardrobe checks, location orientation coverage, and rejected-media cleanup verified by readback
- **Duplicates** — fuzzy name matching, alias candidates, variants confused as separate refs
- **Metadata quality** — missing `visualAnchor`, `lighting`, `setting` that downstream prompts need (HIGH-severity gaps block for any entity in ≥1 scene)
- **Policy compliance** — `createPolicy`, `variantVocabulary` adherence
- **Look-binding integrity** — required non-default character appearances carry a matching `lookRef`, and every bound reference resolves to a real variant; missing/stale bindings otherwise render the default silently

Part of the Pre-Production Token Ralph Loop (`references/pre-production-ralph-loop.md`): safe text and graph corrections are re-checked until **0 unacknowledged blocking errors remain and every required visual row has reviewed evidence or a recorded user override** before Step 03 proceeds. The loop never generates images or submits billable evaluator runs without separate confirmation. Every reference write must first satisfy `settings.references`; a missing image is resolved only by an existing approved attachment, a user upload, or explicit permission to generate. Rejected candidates remain outside active references; if already attached, remove them from current and legacy look stores and clear any matching card-preview URL through a documented operation, then verify by readback. Advisory findings are presented for acknowledgment. This is the cheapest place to catch a reference problem — later detection costs re-renders.

## Step 03 — Deterministic Script Breakdown & Relational Audit

→ `mixio-script-breakdown`. It persists canonical scene packages, resolves Cast & World IDs,
links per-shot appearance state, and must pass its persisted relational audit before Step 04. The
breakdown skill owns the fields, audit checks, and `metadata.pipeline.breakdown_audit` schema.

## Step 04 — Continuity Audit

→ `mixio-continuity`. Four passes: blocking map → checks → report → corrections. Text-only, before any pixels. Emits corrected shots and a per-shot clean/dirty verdict.

**Pre-Production Token Ralph Loop:** Persist the root-cause correction and immediately rerun the audit. When a missing reference or stale look caused the break, the Phase 2 runner first reads `settings.references` and only applies a permitted correction; it never starts image generation from this loop. Do not advance until continuity and reference audits have zero unacknowledged blocking errors and every required visual row has reviewed evidence or a recorded user override.

## Step 05 — Shot Planning

→ `mixio-shot-planning`. Three decisions per shot, then batching:

Before batching, reconcile every broken-down shot's actual camera zone, location configuration, and selected labeled view against `metadata.pipeline.reference_pack_inventory`. If a shot requires an unlisted or unapproved row, emit a blocking reference finding, add the row to the inventory as `proposed`, and stop before writing an awaiting-generation-approval summary. Ask the user to confirm the additional image round, stage and evaluate candidates, attach only approved images, and rerun the reference audit. Re-entering Step 02 invalidates downstream work: rerun Step 02.5, then restart Steps 03–05 because their outputs are stale before Step 06.

1. **Model + live contract** — use the project's explicitly pinned model when present. Otherwise prefer the compatible H3 route: Ref2Vid for ordered keyframes/reference-to-video, I2V when a start frame is supplied, and T2V for prompt-only video. If the matching H3 route is unavailable for that use case, select a supported fallback and read its live input schema, including the duration ceiling.
2. **Archetype / Method** — classify each shot using that contract into one of 6 structural archetypes: `GRID` (multi-panel/montage), `MULTI_CUT` (10–15s multi-cut shot rendered as one native `multi-shot-video` job from persisted `cuts[]`), `SEQUENCE` (multi-beat sequence), `MASTER_ANCHOR_MULTI_SHOT` (coverage grounded by the wide scene-anchor reference through a derived keyframe), `SINGLE` / `DUAL_FRAME` (standard keyframe interpolation), or `T2V` (direct text-to-video).
3. **Execution & Feasibility Audit** — validate duration vs model max, action density (`actions / duration`), dialogue speaking rate (`words / duration`), reference readiness, the shot's selected character look and location variant/view, and **mandatory prompt `@` mentions + paired `slotTags`/`mentionMap` verification**. The chosen location media must match the confirmed variant/view row and be approved; pass its explicit `variantId`/`variantName` with the actual view image. Every active media slot (`primary`, `endFrame`, `references`, `character_ref`, `location_ref`, `style_ref`, `asset_ref`, `clothing_ref`, `image_urls`, `motionRef`, `audioRef`, `enhancer_context`, or a schema-added slot) must have exactly one mapped `@tag` in the effective prompt; reject missing pairs, collisions, and orphan map entries.

Then group consecutive shots only when their model, generation use case, and input contract all match; the planner's live schema limits still apply. Emit a `PRODUCTION SUMMARY` with archetype distribution, keyframe/video job counts, high-risk cross-model boundaries, and the relative cost order: video generation costs the most, image generation comes next, and other operations cost little. Preserve a bound CHARACTER look as relation `lookRef`; Step 06 must resolve it through `selectedElements` or pass `variantId`/`variantName` on the media reference. For locations, pass the confirmed configuration variant and exact approved view image; do not encode the camera angle as character `lookRef` or inert plan metadata (see `mixio-generate`).

## Step 06 — Video Generation

→ `mixio-generate`, batch by batch, keyframes first then video. Ask before video generation unless the user has said otherwise. Offer the three permission levels once, at the top of Step 06, and record the answer:

- **Always allow** — generate without asking.
- **Ask before video** — video generation costs the most, image generation comes next, and other operations cost little.
- **Always ask** — confirm every job.

**Preflight Gating (Mandatory Invariant across all models before submit):**
- Flatten every active `input.media` slot, including references inherited from the scene anchor and a resolved look. For each asset, verify exactly one unique `slotTags` entry and a non-empty `mentionMap` label for its tag; reject missing pairs, collisions, and orphan map entries.
- Verify that the effective prompt explicitly embeds every mapped `@tag` where that asset acts. For `production-generate-shot-keyframe-sequence`, validate `sequence_notes` plus the materialized shot prompt when the caller leaves `prompt` unset; omission is not a bypass.
- Block the job on `PROMPT_MENTION_MISSING`, `MENTION_MAP_UNPAIRED`, `MENTION_TAG_COLLISION`, or `MENTION_MAP_ORPHANED`. Plain descriptive prose without `@` tags prevents the prompt materializer and provider compilers from mapping assets to model tokens (`Image 1`, `@Image1`, `@tag`) or performing subject grounding, causing models to guess identity. Never submit an ungrounded media job.
- Re-run this gate immediately before every billable `studio_submit_studio_job` call, even when Step 05 already reported clean; inherited anchors, variants, or batch edits can change the active media set.

**Use case IDs for this step:**
- Keyframes, shot already locked by Step 04: `production-generate-shot-keyframes` with `keyframe_count: 1`, **one job per beat**. Our prompt is used verbatim, nothing re-plans it, and the sequence planner's diversity gate cannot reject a deliberate hold. Pass the previous beat's keyframe as a reference to chain continuity forward.
- Keyframes, beats you want invented for you: `production-generate-shot-keyframe-sequence`. Leave `prompt` unset — a caller prompt *replaces* Studio's shot-spec assembly — and put your direction in `sequence_notes`, which is appended to the planner's prompt instead.
- Video: `production-generate-video`

Do **not** use `keyframe-sequence` — that is the Generate-page version (`outputType: IMAGE`, `surfaces: ["generate"]`) and output will not land under the shot even with correct `context`.

**Run the modern eval gate yourself.** The server's own evaluation pass is skipped whenever `orchestrate_frames` is true, which is the default on the production sequence path — so nothing checks the rendered frames unless you do. Run `mixio-eval` per batch through the canonical `evals_evaluate_media` hosted tool (or its local `studio_evals_evaluate_media` proxy / CLI `evals-evaluate-media` spelling), with `evals_get_evaluation_result` for polling (local `studio_evals_get_evaluation_result`, CLI `evals-get-evaluation-result`). Before rendering, use `image-character` for character sheets and `image-location` for location packs only after the live catalog and contract confirm that the profile accepts the candidate and required evidence. If no compatible profile is listed, use available vision or human review; leave the required row unresolved when it has no visual evidence. Each evaluator submission is billable and requires confirmation, and reference evaluation does not replace shot evaluation. Request the `human-review` repair-plan extension for reviewable runs. For the strict profile, the request MUST include ordered adjacent candidate inputs plus top-level `keyframe-continuity.frames` entries with concrete `frame-index`/`time-ms`, and `relations` for each declared cross-angle or non-adjacent comparison; bind every relation to the corresponding `shots`/`shot-plan` transition. Use `keyframe-continuity` for strict ordered keyframes and adjacent-transition gating, `sequence-storyboard` only as a general storyboard lens, `video-multi-shot` for rendered multi-shot/cross-angle geography, `video-character` for identity/pose/wardrobe/prop state, `video-general` for catalog-supported general artifacts, style/material, scale, palette, lighting, or camera review, and `delivery-qc` as the final delivery lens. Derive required dimensions from locked style and expected state, verify the selected profile actually covers them, and route uncovered dimensions to another confirmed run or human review. Pass ordered inputs plus `shots`/`shot-plan` expected state, and gate on the worst transition and every blocking finding; an aggregate score cannot override one severe break. Do not copy legacy capability names into the modern request. If only a deprecated compatibility alias is available, use the explicit adapter boundary in `mixio-eval` and do not claim the strict ordered-transition gate when that alias cannot carry its context. Cross-model batch boundaries from Step 05 are where to look first.

### Human review before any retry

After polling the evaluation, present the receipt, localized findings, and
`human-review` repair plan to a human. Do not interpret `proposed` as consent.
The human must choose one of: accept the current render, edit/approve a narrow
repair scope, request a broader re-render, or reject the recommendation. Record
that decision in pipeline metadata before calling `mixio-generate`. At minimum,
record the evaluation receipt ID, repair-plan action ID (when applicable),
decision (`accept-current`, `approved-repair`, `broader-rerender`, `reject`, or
`needs-more-evidence`), reviewer identity, and decision timestamp.

Only an approved repair may proceed. For an approved segment or shot-boundary
repair, preserve the cited reference pack and last good boundary keyframes,
regenerate the smallest approved unit, then evaluate the repaired unit plus its
immediate neighbors. If the plan says `sequence` or `full-delivery`, do not
silently reduce it to a segment retry. A failed or ambiguous recommendation
stays at `needs_revision` and returns to human review.

After each batch, set shot state (`approved` / `needs_revision`) with `studio_update_shot_state` so the canvas reflects reality.

**Final assembly is out of scope for this tool surface.** None of the 39 MCP tools stitch, concatenate, export, or render a timeline — the pipeline delivers approved per-batch video, not a finished cut. Say so rather than implying a single deliverable file is reachable. Audio *is* reachable (`text-to-speech` and `voice-change`, the catalog's two `outputType: AUDIO` use cases, through `studio_submit_studio_job` — see `mixio-generate`), so a narration or dialogue track can be generated per shot even though mixing cannot.

## Progress state — how to resume

Mixio has no dedicated shared-memory store, so pipeline state lives in existing metadata. Write it at every step close:

```
studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  aspect_ratio, anchor_aspect_ratio,
  shot_contract: { mode: "multi_cut", band: "10-15" },
  step_00: "complete", step_01: "complete", step_02: "complete", step_02_5: "complete",
  step_03: "complete", step_04: "complete",
  step_05: "not_started", step_06: "not_started",
  anchors: { "1": "<keyframe-element-id>" },
  // Free-form review ledger; candidate URLs remain here, not in active references.
  reference_pack_inventory: {
    rows: [/* confirmed variant/view rows, source media, shot IDs, status,
             eval run IDs, feedback, human decision */]
  },
  reference_audit: { checked: 12, blocking: 0, advisory: 1 },
  // `breakdown_audit`: exact schema in mixio-script-breakdown's persistence reference.
  // Add `pre_production_loop` exactly as defined in
  // references/pre-production-ralph-loop.md#persisting-loop-state.
}}}})
```

| Pipeline state | Where it lives in Mixio |
|---|---|
| Locked models, resolution, style, reference policy | project `settings.generation` / `settings.studio` / `settings.references` |
| Source (screenplay, synopsis, aspect ratios) | SCREENPLAY `body` (or episode `script` only as fallback), episode `summary`, `metadata.pipeline` |
| Locations | LOCATION references + `locationDetails` (`mixio-references`) |
| Confirmed character/location variant-view matrix and review history | episode `metadata.pipeline.reference_pack_inventory` (free-form metadata; no new API or typed schema) |
| Reference audit results | episode `metadata.pipeline.reference_audit` |
| Relational breakdown audit results | episode `metadata.pipeline.breakdown_audit` |
| Pre-production Ralph loop state | episode `metadata.pipeline.pre_production_loop` — `running`, `blocked`, or `converged`, with the last phase, cycle, findings, and pending user action |
| Scenes and direction | scene elements via `studio_upsert_scene_packages` |
| Step progress | episode `metadata.pipeline` |
| Shot plan (method/model/batch) | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| Rendered assets and video | KEYFRAME / VIDEO elements + `upload_file` URLs |

On resume, read `studio_get_project` for the locked settings and `studio_get_episode` (cheap) for
pipeline state, including `metadata.pipeline.reference_pack_inventory` and its row statuses,
evaluation run IDs, feedback, and human decisions. Then query the episode's `SCREENPLAY` element (`studio_query_elements` with
`type: "SCREENPLAY"` and native-object `tags: { episodeId }`, never `JSON.stringify(...)`) before
reusing source text. Do not substitute a stale `fullScript` when a non-empty screenplay body
exists; avoid `studio_get_production_context` until its graph detail is actually needed.

## Workflow

```
00. studio_get_project → studio_update_project({ projectId, updates: { settings } }) → studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline } } }) → GATE
01. screenplay → studio_upsert_screenplay({ projectId, episodeId, body })
02. /mixio:sheets → approved character defaults/required variants + location configuration/view packs, then anchor per scene → GATE (image work is separately confirmed)
03. /mixio:script-breakdown → studio_upsert_scene_packages + studio_link_graph → relational audit
┌── Pre-Production Token Ralph Loop (01 ↔ 02.5 ↔ 04; safe text/graph corrections only) ─┐
│ 01. repair screenplay mentions or deterministic prose defects                           │
│ 02.5 /mixio:reference-audit → policy-safe reference/binding corrections, then re-check │
│ 04. /mixio:continuity → correct specs/relations, then re-audit                          │
└────────────────────────────────────── ↺ persist every cycle until 0 errors ────────────┘
  → GATE: Pre-production converged & breakdown locked
05. /mixio:shot-planning                           → method + model + feasibility + batches + PRODUCTION SUMMARY → GATE (plan review)
06. /mixio:generate per batch → studio_update_shot_state → /mixio:eval before delivery
```

## Notes

- The Ralph Loop's corrective reads and text/graph writes never start generation. Step 02 can render anchor or sheet images, so it is never entered automatically; a continuity break found in Step 04 is easier to correct than the same break found after a Step 06 render.
- The Ralph Loop stops after three automated correction cycles per scene. If a blocking issue persists, present a focused user decision rather than silently forcing a creative change; persist `running` or `blocked` state at each cycle boundary so a later session resumes honestly.
- If the user jumps straight to "generate this script", still run 01→05 — just run them fast and present each gate as a short confirm rather than a discussion.
- Re-entering an earlier step invalidates the later ones. Editing Step 03 after Step 05 means re-planning; say so instead of patching one batch.
- Step 02.5 catches reference problems that Step 02 should have resolved. If sheets were skipped or rushed, 02.5 surfaces the gaps. It's a safety net, not a replacement for doing sheets properly.
