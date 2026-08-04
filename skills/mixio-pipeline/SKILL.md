---
name: mixio-pipeline
description: "Run an episode from script to delivered video as six gated steps — detailed script, anchor frames, panel breakdown, continuity audit, chunking, video generation — persisting progress and locking each step before the next."
version: 0.1.0
invoke: /mixio:pipeline
---

# Mixio Pipeline

The orchestrator. The other Mixio skills are tool surfaces (`mixio-episode`, `mixio-generate`, …); this one is the **order and the gates**. Generation is billable and non-deterministic, so the whole point is to burn tokens on text passes until the plan is airtight, then spend credits once.

Read `references/shot-grammar.md` before authoring or auditing any breakdown — it is the shared vocabulary that `mixio-sheets`, `mixio-continuity`, and `mixio-chunking` all assume.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- A project (`mixio-project`) and an episode (`mixio-episode`)

## The six steps

| # | Step | Owned by | Output locked into |
|---|------|----------|--------------------|
| 01 | **Detailed Script** | this skill | `studio_update_episode({ updates: { script, summary } })` |
| 02 | **Anchor Frames** | `mixio-sheets` | CHARACTER/LOCATION refs + one anchor KEYFRAME per scene |
| 03 | **Panel Breakdown** | `mixio-script-breakdown` | `studio_upsert_scene_packages` |
| 04 | **Continuity Audit** | `mixio-continuity` | `studio_revise_shot_specs` + `studio_update_shot_state` |
| 05 | **Chunking** | `mixio-chunking` | shot `metadata.chunk_index` |
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

## Step 03 — Panel Breakdown

→ `mixio-script-breakdown`, which owns the canonical schemas, the two closed enums, and the mapping from shot-grammar prose onto persistable keys. One scene at a time. Emit a `STAGING` block for the scene, then numbered shots using the field schema in `references/shot-grammar.md`. Non-negotiables:

- Every shot carries a `duration` in seconds. Chunking (Step 05) and cost estimates are both arithmetic on this field.
- Every shot names its anchor (`Lighting: as Anchor 1`) or is marked `TEXT-ONLY`.
- Intra-shot beats other shots depend on get a marker — `[M1]`, `[M2]` — so a later shot can say "tablet already with Tony after `[M2]`" instead of re-describing it.
- The seven required canonical fields (`shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, `duration`) must all carry real values. A missing one persists as `"TBD"` and renders blank rather than failing — see `mixio-script-breakdown`.

Persist with `studio_upsert_scene_packages` (see `mixio-episode`), putting the shot spec in shot `metadata` and the cast/set links in `linked_character_ids` / `linked_location_ids` / `linked_prop_ids`.

## Step 04 — Continuity Audit

→ `mixio-continuity`. Four passes: blocking map → checks → report → corrections. Text-only, before any pixels. Emits corrected shots and a per-shot clean/dirty verdict.

## Step 05 — Chunking

→ `mixio-chunking`. Group shots into generation chunks under the duration and count caps, then emit a `PRODUCTION SUMMARY` so the user sees total runtime and cost surface before approving spend.

## Step 06 — Video Generation

→ `mixio-generate`, chunk by chunk, keyframes first then video. Ask before spending unless the user has said otherwise. Offer the three permission levels once, at the top of Step 06, and record the answer:

- **Always allow** — generate without asking.
- **Ask before video** — images are cheap, video is not; this is the sensible default.
- **Always ask** — confirm every job.

After each chunk, set shot state (`approved` / `needs_revision`) with `studio_update_shot_state` so the canvas reflects reality.

**Final assembly is out of scope for this tool surface.** None of the 39 MCP tools stitch, concatenate, export, or render a timeline — the pipeline delivers approved per-chunk video, not a finished cut. Say so rather than implying a single deliverable file is reachable. Audio *is* reachable (`text-to-speech`, `voiceover` and friends through `studio_submit_studio_job` — see `mixio-generate`), so a narration or dialogue track can be generated per shot even though mixing cannot.

## Progress state — how to resume

Mixio has no dedicated shared-memory store, so pipeline state lives in existing metadata. Write it at every step close:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  aspect_ratio, anchor_aspect_ratio,
  step_01: "complete", step_02: "complete", step_03: "in_progress",
  step_04: "not_started", step_05: "not_started", step_06: "not_started",
  anchors: { "1": "<keyframe-element-id>" }
}}}})
```

| What Dashtoon keeps in shared memory | Where it lives in Mixio |
|---|---|
| `source` (script, synopsis, aspect ratios) | episode `script`, `summary`, `metadata.pipeline` |
| `locations` | LOCATION references + `locationDetails` (`mixio-references`) |
| `direction` / `scenes` | scene elements via `studio_upsert_scene_packages` |
| `progress` | episode `metadata.pipeline` |
| `chunks` | shot `metadata.chunk_index` |
| `assets` / `videos` | KEYFRAME / VIDEO elements + `upload_file` URLs |

On resume, read `studio_get_episode` (cheap) rather than `studio_get_production_context` (100K+ chars on a real production) to find where you left off.

## Workflow

```
00. studio_update_episode(metadata.pipeline)      → lock aspect_ratio + anchor_aspect_ratio
01. script → studio_update_episode({ script })    → GATE: user confirms
02. /mixio:sheets                                  → character + location sheets, anchor per scene → GATE
03. /mixio:script-breakdown → studio_upsert_scene_packages    → GATE
04. /mixio:continuity                              → 4 passes, corrected shots → GATE
05. /mixio:chunking                                → chunks + PRODUCTION SUMMARY → GATE (cost approval)
06. /mixio:generate per chunk → studio_update_shot_state → /mixio:eval before delivery
```

## Notes

- Steps 01, 03, 04, 05 cost nothing but tokens. Do not shortcut them to reach generation faster; a continuity break found in Step 04 costs a paragraph, the same break found in Step 06 costs a re-render.
- If the user jumps straight to "generate this script", still run 01→05 — just run them fast and present each gate as a short confirm rather than a discussion.
- Re-entering an earlier step invalidates the later ones. Editing Step 03 after Step 05 means re-chunking; say so instead of patching one chunk.
