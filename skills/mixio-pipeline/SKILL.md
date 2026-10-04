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
- An existing screenplay/script or source text supplied for this episode.

For full multi-step runs, use the current host’s native task or plan surface when available; use persistent goal features only when the user asks for work to continue across turns. Follow [agent-native tracking](references/agent-native-tracking.md). Native progress never substitutes for the user’s breakdown, image, or cost approval.

## Sequence

| Step | Work | Result |
|---|---|---|
| 00 | Project and episode setup + read-only source snapshot | Confirmed scope; current script, project references, existing shots, settings, and available images inspected |
| 01 | `/mixio:script-breakdown` | Local shot table with source/inference labels and connective coverage |
| 02 | `/mixio:continuity` | Local coverage and continuity audit; corrections stay in the draft |
| 03 | Review and Studio sync | Exact diff shown; explicit approval; existing primitives write it; readback verifies it |
| 04 | Reference readiness | Audit existing references; build missing sheets/anchors as separately confirmed |
| 05 | `/mixio:shot-planning` | Method/model, feasibility, batches, cost estimate, and cost approval |
| 06 | `/mixio:generate`, then `/mixio:eval` | Approved generation batches and evaluated outputs |

## Step 00 — Set up and read

Resolve scope before expensive reads. If the project or episode does not exist, show available projects/episodes and get confirmation before creating it. Read the current project settings, references, existing episode scenes/shots, and available image assets.

Use a non-empty native `SCREENPLAY` body as source, including a draft; use episode `script` / `metadata.fullScript` only when no non-empty screenplay body exists. Preserve the selected source verbatim. Do not normalize, replace, or upsert screenplay text as part of shot planning. If no source text is available, request it before planning.

Read any existing delivery, visual-style, and reference-policy settings as constraints. Capture the user’s intended tone and format when stated; do not invent a style to fill an unset field. Missing settings, sheets, and anchors can be listed as readiness gaps; they do not block a local plan. Do not choose per-shot generation methods, select generation models, estimate spend, or submit image/video jobs before the accepted breakdown.

## Step 01 — Build the local director’s plan

Follow `mixio-script-breakdown`. Work from the source and current references/assets. Infer the missing visual beats required to make the source legible and connected, while distinguishing source facts from proposed direction. Do not mutate Studio scenes, shots, relations, references, or screenplay during this step.

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

Run `/mixio:shot-planning` only against the approved, persisted shots. Choose each shot’s generation method and model from the live use-case contract while preserving its accepted purpose, action, camera direction, and handoff. If a technical limit requires changing direction, return a proposed change for review rather than silently simplifying it. Verify reference readiness and mandatory prompt `@` mentions/maps, then present batches and estimated cost. Get explicit cost approval before billable generation.

## Step 06 — Generate and evaluate

Run `/mixio:generate` for approved batches. Translate the accepted direction faithfully; if the available generation path cannot honor it, pause for a proposed change. Recheck media slots, prompt `@` mentions, `slotTags`, and `mentionMap` immediately before each billable job. Use the deepest confirmed context (`projectId`, `episodeId`, `sceneId`, `shotId`). Upload final outputs through `mixio-workspace`, then run `/mixio:eval` against the approved intent and continuity before delivery.

## Resume and re-entry

The local plan is a review artifact in the current agent context; it has no new Studio schema. If context is lost before sync, rebuild it from the current screenplay, references/assets, and Studio graph. If context is lost after sync, read the persisted graph and resume from that state. Never treat an old, unreviewed draft as approval. A change to an accepted breakdown invalidates downstream shot planning and may change its cost estimate.

## Working sequence

```text
setup + read → local plan → local continuity/coverage audit
             → show exact diff → user approval → sync + readback
             → reference readiness → method/model + cost approval → generation + evaluation
```
