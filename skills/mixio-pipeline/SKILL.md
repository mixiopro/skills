---
name: mixio-pipeline
description: "Use when coordinating a full Mixio episode or deciding which production skill comes next."
version: 0.5.0
invoke: /mixio:pipeline
---

# Mixio Pipeline

The pipeline moves from confirmed project setup to a locally reviewed director’s plan, then syncs the approved diff to Studio. **Use the director’s lens throughout production and consult the relevant specialist perspectives:** cinematography, production design, costume, props, script supervision, editing, sound, action, and technical or production feasibility checks inform the plan when useful. The director integrates them around audience intent; downstream work serves the accepted shot direction and preserves continuity. Planning and continuity corrections happen in the agent’s working context. The original screenplay stays unchanged. See the shared [director’s lens](references/directors-lens.md).

Read the [native screenplay grammar](../mixio-episode/references/screenplay-grammar.md) when interpreting a screenplay and the [shot grammar](references/shot-grammar.md) when mapping direction to Studio fields.

## Prerequisites

- MCP server configured: `@mixio-pro/mcp`.
- Resolved project and episode. If scope is unknown, list options and ask in the same message; never infer IDs. Follow `mixio-project` and `mixio-episode` for setup.
- An existing screenplay/script, a user-supplied scene/shot breakdown, or another source text for this episode.

For full multi-step runs, use the current host’s native task or plan surface when available; use persistent goal features only when the user asks for work to continue across turns. Follow [agent-native tracking](references/agent-native-tracking.md). Native progress never substitutes for the user’s breakdown, image, or cost approval.

## Sequence

| Step | Work | Result |
|---|---|---|
| 00 | Project and episode setup + read-only source snapshot | Confirmed scope; current script, project references, existing shots, settings, and available images inspected |
| 01 | `/mixio:script-breakdown` | Enriched local plan based on an existing scene/shot breakdown, or a new local breakdown when none exists |
| 02 | `/mixio:continuity` | Local coverage and continuity audit; corrections stay in the draft |
| 03 | Review and Studio sync | Exact diff shown; explicit approval; existing primitives write it; readback verifies it |
| 04 | Reference readiness | Audit existing references; build missing sheets/anchors as separately confirmed |
| 05 | `/mixio:shot-planning` | Method/model, feasibility, batches, cost estimate, and cost approval |
| 06 | `/mixio:generate`, then `/mixio:eval` | Approved generation batches and evaluated outputs |

## Step 00 — Set up and read

Resolve scope before expensive reads. If the project or episode does not exist, show available projects/episodes and get confirmation before creating it. Read the current project settings, references, existing episode scenes/shots, and available image assets.

Identify any scene/shot breakdown supplied in the user's prompt or attachments as well as one already present in Studio. If a usable breakdown exists, it is the planning baseline. Use a non-empty native `SCREENPLAY` body as source text for checking and grounding, including a draft; use episode `script` / `metadata.fullScript` only when no non-empty screenplay body exists. Preserve all selected sources verbatim. If no screenplay/script is available but a usable breakdown was supplied, enrich from that breakdown and make its evidence limits visible. If neither a breakdown nor source text is available, request one before planning. Do not normalize, replace, or upsert screenplay text as part of shot planning.

Read any existing delivery, visual-style, and reference-policy settings as constraints. Capture the user’s intended tone and format when stated; do not invent a style to fill an unset field. Missing settings, sheets, and anchors can be listed as readiness gaps; they do not block a local plan. Do not choose per-shot generation methods, select generation models, estimate spend, or submit image/video jobs before the accepted breakdown.

## Step 01 — Use or create the local director’s plan

First check whether the user supplied a scene/shot breakdown in the prompt or attachments, or the episode already has a usable scene/shot breakdown in Studio. Follow `mixio-script-breakdown` in one of two modes:

- **Breakdown supplied or already present:** Treat its scene order, shot order, authored beats, and stated direction as the baseline. Enrich it with production detail: audience intent, visible action, framing/camera, character and prop state, geography, shot handoffs, source links, and readiness gaps. Preserve its structure and wording where they carry the user's direction. Add clearly labeled inferred detail, missing connective coverage, and useful editorial surplus through extra shots or alternates; show unresolved story-changing choices as `OPEN DECISION`. Do not run a fresh screenplay-to-scenes-and-shots pass over it.
- **No usable breakdown exists:** Build the scene-and-shot structure from the selected screenplay/script, preserving its order and facts, and add clearly labeled inferred coverage where needed.

If an existing breakdown appears incomplete, conflicting, or unsuitable for the requested work, identify the specific gap and propose a targeted repair or rebuild for review. Do not silently replace or discard existing scenes, shots, or user-authored direction. In either mode, keep the work local and do not mutate Studio scenes, shots, relations, references, or screenplay during this step.

Plan for editorial surplus: the stated episode/runtime target is the intended post-production duration, not a limit that all generated shot durations must sum to. Preserve enough coverage for the editor to select, trim, align, and pace the final cut. Add suitable alternate shots and extra coverage when they help editorial choices or protect transitions, and show their purpose and approximate duration in the plan. The planned generated material should exceed the intended final runtime; do not force the breakdown to fit the runtime by deleting useful coverage or shortening shots below what the action needs. Flag material additions as `INFERRED` and include them in the later batch and cost estimate. This surplus direction does not itself approve billable generation.

## Step 02 — Audit and correct locally

Follow `mixio-continuity` and the [local pre-sync review cycle](references/pre-sync-review-cycle.md). Check source-beat coverage, cause and effect, character/prop state, geography, staging, transitions, and camera motivation across neighboring shots. Revise the local table, then repeat the relevant checks. Keep story-changing ambiguity as an `OPEN DECISION` for the user.

Missing images or sheets are readiness findings, not continuity errors. Text-only review may assess intended geography and action, but must not claim an image/anchor comparison was performed when no image is available.

## Step 03 — Show the diff, then sync only after approval

Present the complete reviewed table and a separate Studio diff. For every proposed operation include:

- `ADD`, `UPDATE`, or `NO CHANGE`;
- the confirmed scene/shot element ID for an update, or `NEW` for an addition;
- the exact fields and before/after values;
- source beat and `SCRIPTED` / `INFERRED` / `OPEN DECISION` provenance;
- affected character, location, prop, and appearance relations;
- unresolved match questions and asset-readiness gaps.

Match an update only when the current Studio element ID and the intended scene/shot are confirmed. Before using an upsert key, verify that it resolves to that same element. Flag ambiguous matches and unmatched existing shots; do not silently overwrite, renumber, or delete them. Do not write any breakdown changes until the user approves the presented diff. A later edit to the plan requires an updated diff and approval.

After approval, use the existing primitives documented in `mixio-episode` and `mixio-script-breakdown`. Apply the project’s `settings.references` policy to any required reference registration. Read the persisted scenes, shots, and relations back; compare them with the approved diff and report any missing, altered, or partial writes by element ID. Never claim a write succeeded from the mutation response alone.

## Step 04 — Check readiness

Run `/mixio:reference-audit` against the accepted plan and current Cast & World. Check whether references support the plan’s intended identities, looks, locations, props, and staging. Missing references, images, details, or scene anchors are reported before generation. They did not block local planning; resolve generation blockers now.

Use `/mixio:sheets` only for assets that need building or enrichment. Ask separately before image generation, then re-run the audit after reference changes. Resolve or get explicit acceptance of generation blockers before Step 05. Use `references/preflight-settings.md` after the breakdown is accepted to confirm and read back any missing delivery/anchor settings or generation defaults required for production.

## Step 05 — Plan production and approve cost

Run `/mixio:shot-planning` only against the approved, persisted shots. Choose each shot’s generation method and model from the live use-case contract while preserving its accepted purpose, action, camera direction, and handoff. Include the approved extra coverage and alternates in the batches and estimate. Report total planned generated-material duration separately from the intended post-production runtime; planned generated material must exceed the final-edit target. If a technical limit requires changing direction, return a proposed change for review rather than silently simplifying it. Verify reference readiness and mandatory prompt `@` mentions/maps, then present batches and estimated cost. Get explicit cost approval before billable generation.

Before batching, reconcile each shot’s actual camera zone, location configuration, and selected labeled view against the confirmed `reference_pack_inventory`. If a required view is absent or unapproved, stop before writing an awaiting-generation-approval summary. Ask the user to confirm any additional image round, then stage and evaluate candidates, attach only approved images, and rerun the reference audit. Returning to Step 04 invalidates downstream work: rerun the audit and restart Steps 03–05 because their outputs are stale. Group consecutive shots only when their model, generation use case, and input contract all match.

## Step 06 — Generate and evaluate

Run `/mixio:generate` for approved batches, keyframes first and then video. Ask before video generation unless the user has said otherwise. Translate the accepted direction faithfully; if the available generation path cannot honor it, pause for a proposed change. Recheck media slots, prompt `@` mentions, `slotTags`, and `mentionMap` immediately before each billable job. Use the deepest confirmed context (`projectId`, `episodeId`, `sceneId`, `shotId`). Upload final outputs through `mixio-workspace`.

Run `/mixio:eval` for each rendered batch through `evals_evaluate_media` and poll with `evals_get_evaluation_result` before delivery. Reference-image evaluation may use `image-character` or `image-location` only when the live catalog and contract support the candidate and its evidence; it does not replace shot evaluation. Use `keyframe-continuity` for strict ordered keyframes and adjacent-transition gating, `sequence-storyboard` only as a general storyboard lens, `video-multi-shot` for cross-angle geography, and `delivery-qc` for final delivery review. Request `human-review` when a repair plan is useful. Bind ordered inputs and expected state to the shot plan, and gate on the worst transition and every blocking finding; an aggregate score cannot override a severe break. If the current catalog exposes only a deprecated compatibility alias, follow the adapter boundary in `mixio-eval` and do not claim a strict transition gate when that alias cannot carry its context.

Evaluation submissions are billable and need confirmation. Present the evaluation receipt, localized findings, and any `human-review` repair plan for human review before retrying; a proposed repair is not approval.

## Resume and re-entry

The local plan is a review artifact in the current agent context; it has no new Studio schema. If context is lost before sync, rebuild it from the current screenplay, references/assets, and Studio graph. If context is lost after sync, read the persisted graph and resume from that state. Never treat an old, unreviewed draft as approval. A change to an accepted breakdown invalidates downstream shot planning and may change its cost estimate.

## Working sequence

```text
setup + read → use/enrich supplied or existing plan, or create one if absent → local continuity/coverage audit
             → show exact diff → user approval → sync + readback
             → reference readiness → method/model + cost approval → generation + evaluation
```
