---
name: mixio-pipeline
description: "Use when coordinating a full Mixio episode or deciding which production skill comes next."
version: 0.5.0
invoke: /mixio:pipeline
---

# Mixio Pipeline

The pipeline moves from a raw story/script to a locally developed, AI-ready director’s screenplay, then to a continuity-checked shot plan and approved Studio sync. **Use the director’s lens throughout production and consult relevant craft perspectives:** cinematography, production design, costume, props, script supervision, editing, sound, action, and technical feasibility. The director integrates them around audience intent and a connected sequence. The raw episode `script` remains the story source; the screenplay is a developed production document and may add clearly identified connective direction and coverage. See the shared [director’s lens](references/directors-lens.md).

Read the [native screenplay grammar](../mixio-episode/references/screenplay-grammar.md) when interpreting a screenplay and the [shot grammar](references/shot-grammar.md) when mapping direction to Studio fields.

## Prerequisites

- MCP server configured: `@mixio-pro/mcp`.
- Resolved project and episode. If scope is unknown, list options and ask in the same message; never infer IDs. Follow `mixio-project` and `mixio-episode` for setup.
- An existing screenplay/script, a user-supplied scene/shot breakdown, or another source text for this episode.

For full multi-step runs, use the current host’s native task or plan surface when available; use persistent goal features only when the user asks for work to continue across turns. Follow [agent-native tracking](references/agent-native-tracking.md). Native progress never substitutes for the user’s breakdown, image, or cost approval.

## Sequence

| Step | Work | Result |
|---|---|---|
| 00 | Project and episode setup + read-only source snapshot | Confirmed scope; current script, screenplay, project references, existing shots, settings, and available images inspected |
| 00.5 | Director-led screenplay development | Complete local screenplay draft with scene/shot intent, technical direction, reference cues, continuity, and provenance; review exact screenplay changes and wait for approval before draft upsert |
| 01 | `/mixio:script-breakdown` | Structured local scene/shot plan derived from the approved screenplay, or an accepted existing breakdown enriched against it |
| 02 | `/mixio:continuity` | Local coverage and continuity audit; corrections stay in the draft |
| 03 | Review and Studio sync | Exact scene/shot diff shown; explicit approval; existing primitives write it; readback verifies it |
| 04 | Reference readiness | Audit existing references; build missing sheets/anchors as separately confirmed |
| 05 | `/mixio:shot-planning` | Method/model, feasibility, batches, cost estimate, and cost approval |
| 06 | `/mixio:generate`, then `/mixio:eval` | Approved generation batches and evaluated outputs |

## Step 00 — Set up and read

Resolve scope before expensive reads. If the project or episode does not exist, show available projects/episodes and get confirmation before creating it. Read the current project settings, references, existing episode scenes/shots, and available image assets.

Read the raw episode `script` / `metadata.fullScript`, current native `SCREENPLAY`, any supplied or persisted breakdown, references, settings, and images. Treat the raw script as story source material. A non-empty screenplay is the current production draft, even when it is only a copy of the script; assess whether it is sufficiently developed for the requested production. A high-level script or underdeveloped screenplay requires Step 00.5. Preserve the raw script; never silently treat it as a finished screenplay. If neither source text nor a usable supplied breakdown exists, request source material.

Read any existing delivery, visual-style, and reference-policy settings as constraints. Capture the user’s intended tone and format when stated; do not invent a style to fill an unset field. Missing settings, sheets, and anchors can be listed as readiness gaps; they do not block a local plan. Do not choose per-shot generation methods, select generation models, estimate spend, or submit image/video jobs before the accepted breakdown.

## Step 00.5 — Develop the director’s screenplay

When the source is a high-level script, outline, or underdeveloped screenplay, use `/mixio:screenwriting` (scene-writing plus the relevant quality gate) to create a complete AI-readable screenplay locally before shot breakdown. Preserve the story’s stated events, dialogue, character intent, and canon while developing them into playable scenes and explicit visual beats. Use full, concrete screenplay action rather than a terse restatement of the source. Include scene headings and transitions; entrances, exits, establishing geography, staging, action and cause; reaction and connective beats; character, prop, wardrobe, location, and look continuity; and motivated framing, camera angle/movement, lens, lighting, sound, and pacing where known. Add reasonable connective coverage even when it is absent from the raw script, so scenes form a coherent sequence rather than isolated clips.

Keep a source-to-screenplay change list that distinguishes source facts and dialogue from `INFERRED` director additions. Do not invent consequential story facts, character motives, or dialogue to conceal gaps; present those as `OPEN DECISION`s with options. Use exact existing `#` mentions from `mentionableLooks`; describe unregistered looks/views in prose and record them as readiness needs. Keep shot-specific direction in readable screenplay action and supported standalone annotations; only the 11 keys listed in the native screenplay grammar are parsed into breakdown overrides. Capture duration, detailed per-shot fields, cut timing, and other data without a native screenplay key in the companion local director’s plan, then carry them into the structured breakdown.

Before writing, present the complete screenplay draft, exact source-to-screenplay changes, unresolved decisions, and reference gaps. Wait for explicit approval. Then upsert the approved full body as a Studio draft and read it back. Studio draft status is not human approval; do not proceed to breakdown until the user approves the screenplay in the applicable review surface. For an already approved, production-ready screenplay, confirm it as the baseline and continue without rewriting it. A screenplay edit after shot sync invalidates the breakdown and all downstream work.

## Step 01 — Use or create the local director’s plan

First check whether the user supplied a scene/shot breakdown in the prompt or attachments, or the episode already has a usable scene/shot breakdown in Studio. Follow `mixio-script-breakdown` in one of two modes:

- **Breakdown supplied or already present:** Treat its scene order, shot order, authored beats, and stated direction as the baseline. Enrich it with production detail: audience intent, visible action, framing/camera, character and prop state, geography, shot handoffs, source links, and readiness gaps. Preserve its structure and wording where they carry the user's direction. Add clearly labeled inferred detail, missing connective coverage, and useful editorial surplus through extra shots or alternates; show unresolved story-changing choices as `OPEN DECISION`. Do not run a fresh screenplay-to-scenes-and-shots pass over it.
- **No usable breakdown exists:** Build the scene-and-shot structure from the approved, developed screenplay, preserving its order and facts, and add clearly labeled inferred coverage where needed.

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

Run `/mixio:generate` for approved batches, keyframes first and then video. Ask before video generation unless the user has said otherwise. Translate the accepted direction faithfully; if the available generation path cannot honor it, pause for a proposed change. Recheck schema-valid media slots, URL-valued `mentionMap` bindings, and prompt `@` mentions immediately before each billable job. The MCP adapter derives Studio’s internal `slotTags` and labels. Use the deepest confirmed context (`projectId`, `episodeId`, `sceneId`, `shotId`). Upload final outputs through `mixio-workspace`.

Run `/mixio:eval` for each rendered batch through `evals_evaluate_media` and poll with `evals_get_evaluation_result` before delivery. Reference-image evaluation may use `image-character` or `image-location` only when the live catalog and contract support the candidate and its evidence; it does not replace shot evaluation. Use `keyframe-continuity` for strict ordered keyframes and adjacent-transition gating, `sequence-storyboard` only as a general storyboard lens, `video-multi-shot` for cross-angle geography, and `delivery-qc` for final delivery review. Request `human-review` when a repair plan is useful. Bind ordered inputs and expected state to the shot plan, and gate on the worst transition and every blocking finding; an aggregate score cannot override a severe break. If the current catalog exposes only a deprecated compatibility alias, follow the adapter boundary in `mixio-eval` and do not claim a strict transition gate when that alias cannot carry its context.

Evaluation submissions are billable and need confirmation. Present the evaluation receipt, localized findings, and any `human-review` repair plan for human review before retrying; a proposed repair is not approval.

## Resume and re-entry

The screenplay change map and shot plan are review artifacts in the current agent context; they have no new Studio schema. If context is lost before screenplay approval, reread the raw script and current Studio screenplay and rebuild the proposed screenplay/change map. If context is lost before breakdown sync, rebuild the shot plan from the approved screenplay, references/assets, and Studio graph. If context is lost after sync, read the persisted graph and resume from that state. Never treat an old, unreviewed draft as approval. A screenplay edit invalidates any unsynced local breakdown; after breakdown sync it invalidates downstream planning and may change its cost estimate.

## Working sequence

```text
setup + read → develop/review screenplay when needed → screenplay approval + draft upsert/readback
             → use/enrich supplied or existing plan, or create one if absent → local continuity/coverage audit
             → show exact breakdown diff → user approval → sync + readback
             → reference readiness → method/model + cost approval → generation + evaluation
```
