---
name: mixio-pipeline
description: "Run an episode from script to delivered video as gated steps — detailed script, anchor frames, reference audit, panel breakdown, continuity audit, shot planning, video generation — persisting progress and locking each step before the next."
version: 0.2.0
invoke: /mixio:pipeline
---

# Mixio Pipeline

The orchestrator. The other Mixio skills are tool surfaces (`mixio-episode`, `mixio-generate`, …); this one is the **order and the gates**. Generation is billable and non-deterministic, so the whole point is to burn tokens on text passes until the plan is airtight, then spend credits once.

Read `references/shot-grammar.md` before authoring or auditing any breakdown — it is the shared vocabulary that `mixio-sheets`, `mixio-continuity`, and `mixio-shot-planning` all assume.

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
| 00 | **Lock frame contract** | this skill | `studio_update_episode({ metadata.pipeline })` |
| 01 | **Detailed Script** | this skill | `studio_update_episode({ updates: { script, summary } })` |
| 02 | **Anchor Frames** | `mixio-sheets` | CHARACTER/LOCATION refs + one anchor KEYFRAME per scene |
| 02.5 | **Reference Audit** | `mixio-reference-audit` | episode `metadata.pipeline.reference_audit` |
| 03 | **Panel Breakdown** | `mixio-script-breakdown` | `studio_upsert_scene_packages` |
| 04 | **Continuity Audit** | `mixio-continuity` | `studio_revise_shot_specs` + `studio_update_shot_state` |
| 05 | **Shot Planning** | `mixio-shot-planning` | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| 06 | **Video Generation** | `mixio-generate` | VIDEO elements + workspace uploads |

**Gate rule: never start step N+1 until step N is confirmed by the user.** Announce the close explicitly, e.g. `Step 04 — Continuity Audit complete. Corrected breakdown locked. Moving to Step 05.` A step that silently rolls into the next one is how a 40-shot episode gets generated against a stale breakdown.

## Step 00 — lock the frame contract first

Before Step 01, settle two values and never re-derive them:

- `aspect_ratio` — the **delivery** ratio (`9:16` vertical for microdrama, `16:9` for landscape).
- `anchor_aspect_ratio` — the ratio for **anchor frames only**, deliberately wider than delivery (`16:9` when delivering `9:16`).

Anchors are rendered wide on purpose: a wide master of the set gives every downstream shot a shared spatial truth to crop into, so left/right and near/far stay consistent between a wide and a close-up. Delivery shots then render at `aspect_ratio`.

Persist both on the episode so a resumed session doesn't guess:

```
studio_update_episode({ episodeId, updates: { metadata: {
  pipeline: { aspect_ratio: "9:16", anchor_aspect_ratio: "16:9" }
}}})
```

## Step 01 — Detailed Script

Ask what the user already has, and offer the three real answers rather than an open prompt:

1. **Synopsis only** — you write the script, then get sign-off.
2. **Script only** — you parse it; derive the synopsis yourself.
3. **Both** — synopsis for intent, script as source of truth.

Then write/normalize to standard screenplay form: sluglines (`INT./EXT. — LOCATION — TIME`), action, character cues, dialogue. Set every recurring physical object and set dressing in `CAPS` on first mention (`BED`, `BEDSIDE TABLE`, `NAPOLI POSTER`) — those CAPS tokens are what Step 04 greps for prop continuity. Persist via `studio_update_episode({ updates: { script, summary } })`; the `script` field is the Script tab's source of truth.

## Step 02 — Anchor Frames

→ `mixio-sheets`. Extract the location list and cast from the script, get a reference image per location and a turnaround sheet per character, then render one **anchor frame per scene** at `anchor_aspect_ratio`. Locations with no reference are marked `TEXT-ONLY` and grounded in script text alone — flag them, don't silently invent geography.

## Step 02.5 — Reference Audit

→ `mixio-reference-audit`. Runs after sheets so references *should* have images, and catches what was missed:

- **Completeness** — every CAPS entity in the script has a reference; high-usage ones have images
- **Consistency** — name/description vs attached image (gender, age, build mismatches)
- **Duplicates** — fuzzy name matching, alias candidates, variants confused as separate refs
- **Metadata quality** — missing `visualAnchor`, `lighting`, `setting` that downstream prompts need
- **Policy compliance** — `createPolicy`, `variantVocabulary` adherence

Blocking findings must be resolved before Step 03. Advisory findings are presented for acknowledgment. This is the cheapest place to catch a reference problem — later detection costs re-renders.

## Step 03 — Panel Breakdown

→ `mixio-script-breakdown`, which owns the canonical schemas, the two closed enums, and the mapping from shot-grammar prose onto persistable keys. One scene at a time. Emit a `STAGING` block for the scene, then numbered shots using the field schema in `references/shot-grammar.md`. Non-negotiables:

- Every shot carries a `duration` in seconds. Chunking (Step 05) and cost estimates are both arithmetic on this field.
- Every shot names its anchor (`Lighting: as Anchor 1`) or is marked `TEXT-ONLY`.
- Intra-shot beats other shots depend on get a marker — `[M1]`, `[M2]` — so a later shot can say "tablet already with Tony after `[M2]`" instead of re-describing it.
- The seven required canonical fields (`shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, `duration`) must all carry real values. A missing one persists as `"TBD"` and renders blank rather than failing — see `mixio-script-breakdown`.

Persist with `studio_upsert_scene_packages` (see `mixio-episode`), putting the shot spec in shot `metadata` and the cast/set links in `linked_character_ids` / `linked_location_ids` / `linked_prop_ids`.

## Step 04 — Continuity Audit

→ `mixio-continuity`. Four passes: blocking map → checks → report → corrections. Text-only, before any pixels. Emits corrected shots and a per-shot clean/dirty verdict.

## Step 05 — Shot Planning

→ `mixio-shot-planning`. Three decisions per shot, then batching:

1. **Method** — classify each shot as SINGLE (one keyframe → video), DUAL_FRAME (start+end), MULTI_KF (3–12 keyframes), GRID (multi-panel), or T2V (prompt-only)
2. **Model** — match to best available model based on shot characteristics (action density → Seedance, cinematic camera → Veo, establishing → Sora, etc.)
3. **Feasibility** — validate duration vs model max, action density vs duration, dialogue timing, reference readiness

Then group into generation batches using `mixio-chunking`'s algorithm per model-group (different models have different ceilings). Emit a `PRODUCTION SUMMARY` with per-model costs, method distribution, keyframe/video job counts, and high-risk cross-model boundaries.

## Step 06 — Video Generation

→ `mixio-generate`, chunk by chunk, keyframes first then video. Ask before spending unless the user has said otherwise. Offer the three permission levels once, at the top of Step 06, and record the answer:

- **Always allow** — generate without asking.
- **Ask before video** — images are cheap, video is not; this is the sensible default.
- **Always ask** — confirm every job.

**Use case IDs for this step:**
- Keyframes, shot already locked by Step 04: `production-generate-shot-keyframes` with `keyframe_count: 1`, **one job per beat**. Our prompt is used verbatim, nothing re-plans it, and the sequence planner's diversity gate cannot reject a deliberate hold. Pass the previous beat's keyframe as a reference to chain continuity forward.
- Keyframes, beats you want invented for you: `production-generate-shot-keyframe-sequence`. Leave `prompt` unset — a caller prompt *replaces* Studio's shot-spec assembly — and put your direction in `sequence_notes`, which is appended to the planner's prompt instead.
- Video: `production-generate-video`

Do **not** use `keyframe-sequence` — that is the Generate-page version (`outputType: IMAGE`, `surfaces: ["generate"]`) and output will not land under the shot even with correct `context`.

**Run eval yourself.** The server's own evaluation pass is skipped whenever `orchestrate_frames` is true, which is the default on the production sequence path — so nothing checks the rendered frames unless you do. Run `mixio-eval` per chunk against the claims the text layer actually made: `identity_consistency`, `location_consistency`, `lighting_consistency`, `composition_consistency`, `prop_consistency`. Cross-model batch boundaries from Step 05 are where to look first.

After each chunk, set shot state (`approved` / `needs_revision`) with `studio_update_shot_state` so the canvas reflects reality.

**Final assembly is out of scope for this tool surface.** None of the 39 MCP tools stitch, concatenate, export, or render a timeline — the pipeline delivers approved per-chunk video, not a finished cut. Say so rather than implying a single deliverable file is reachable. Audio *is* reachable (`text-to-speech`, `voiceover` and friends through `studio_submit_studio_job` — see `mixio-generate`), so a narration or dialogue track can be generated per shot even though mixing cannot.

## Progress state — how to resume

Mixio has no dedicated shared-memory store, so pipeline state lives in existing metadata. Write it at every step close:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  aspect_ratio, anchor_aspect_ratio,
  step_01: "complete", step_02: "complete", step_02_5: "complete",
  step_03: "in_progress", step_04: "not_started",
  step_05: "not_started", step_06: "not_started",
  anchors: { "1": "<keyframe-element-id>" },
  reference_audit: { checked: 12, blocking: 0, advisory: 1 }
}}}})
```

| Pipeline state | Where it lives in Mixio |
|---|---|
| Source (script, synopsis, aspect ratios) | episode `script`, `summary`, `metadata.pipeline` |
| Locations | LOCATION references + `locationDetails` (`mixio-references`) |
| Reference audit results | episode `metadata.pipeline.reference_audit` |
| Scenes and direction | scene elements via `studio_upsert_scene_packages` |
| Step progress | episode `metadata.pipeline` |
| Shot plan (method/model/batch) | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| Rendered assets and video | KEYFRAME / VIDEO elements + `upload_file` URLs |

On resume, read `studio_get_episode` (cheap) rather than `studio_get_production_context` (100K+ chars on a real production) to find where you left off.

## Workflow

```
00. studio_update_episode(metadata.pipeline)      → lock aspect_ratio + anchor_aspect_ratio
01. script → studio_update_episode({ script })    → GATE: user confirms
02. /mixio:sheets                                  → character + location sheets, anchor per scene → GATE
02.5 /mixio:reference-audit                        → completeness, consistency, duplicates, metadata → GATE
03. /mixio:script-breakdown → studio_upsert_scene_packages    → GATE
04. /mixio:continuity                              → 4 passes, corrected shots → GATE
05. /mixio:shot-planning                           → method + model + feasibility + batches + PRODUCTION SUMMARY → GATE (cost approval)
06. /mixio:generate per batch → studio_update_shot_state → /mixio:eval before delivery
```

## Notes

- Steps 01, 02.5, 03, 04, 05 cost nothing but tokens. Do not shortcut them to reach generation faster; a continuity break found in Step 04 costs a paragraph, the same break found in Step 06 costs a re-render.
- If the user jumps straight to "generate this script", still run 01→05 — just run them fast and present each gate as a short confirm rather than a discussion.
- Re-entering an earlier step invalidates the later ones. Editing Step 03 after Step 05 means re-planning; say so instead of patching one batch.
- Step 02.5 catches reference problems that Step 02 should have resolved. If sheets were skipped or rushed, 02.5 surfaces the gaps. It's a safety net, not a replacement for doing sheets properly.
