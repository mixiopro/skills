---
name: mixio-script-breakdown
description: "Use when a screenplay or high-level script needs a director’s shot plan with connective coverage and an approval-ready Studio diff."
version: 0.4.0
invoke: /mixio:script-breakdown
---

# Mixio Script Breakdown

Build a complete local shot plan before writing a breakdown to Studio. The plan turns screenplay beats into visible action, camera choices, and connected shots. Keep the original screenplay unchanged and label what the source states separately from inferred direction.

Use the shared [director’s lens](../mixio-pipeline/references/directors-lens.md): the plan serves audience intent and sequence flow, while source facts, user-authored direction, inference, and open decisions remain distinct. Bring in relevant cinematography, production design, props, script-supervision, editing, sound, or action perspectives to answer craft-specific questions; record their recommendations in the plan rather than treating them as approved story facts.

The normal path is **local analysis → local continuity review → exact Studio diff → explicit approval → sync and readback**. Do not use the write-through `script_breakdown` job as the normal path. This skill does not generate images, video, or audio.

## Read the current production

1. Resolve the project and episode using `mixio-pipeline` scope rules. Never infer an ID.
2. Read the source screenplay. A non-empty native `SCREENPLAY` body wins, even when draft; otherwise use episode `script` / `metadata.fullScript`. Preserve the selected text verbatim, including dialogue, `#mentions`, `~locks`, and standalone `[Key: Value]` paragraphs. See [screenplay grammar](../mixio-episode/references/screenplay-grammar.md).
3. Read current scenes/shots, project references and policy, and available image assets. Use exact canonical names and confirmed element IDs. Existing sheets and anchors help ground the plan; missing ones are recorded as readiness gaps.
4. Keep all breakdown analysis and corrections in the local plan. Do not write screenplay, scene, shot, relation, or reference changes while drafting.

## Director’s decision sequence

Run these questions in story order. Each shot should solve an audience, action, state, space, or flow problem; a shot that solves none of them has not earned its place.

| Pass | Ask | Plan |
|---|---|---|
| Intent | What should the audience know, feel, or anticipate here? Whose point of view carries it? | The shot’s dramatic or informational purpose |
| Change | What shifts in the character’s goal, power, information, relationship, or emotion? What choice or visible action causes it? | The action, reveal, reaction, or reversal the audience must see |
| State | What is true at entry and exit for each character, prop, costume, injury, and environment? | A cause for each material state change, or an explicit off-screen event/open question |
| Geography | Where is everyone in the location? What establishes orientation, screen direction, eyelines, and the axis? | Blocking and spatial relations that make the cut readable |
| Coverage | What minimum images make the action and its cause legible? | Needed establishing, entrance, hand/prop, reveal, reaction, movement, or exit coverage |
| Flow | How does this image connect to the previous and next one? | A motivated cut, action match, eyeline, sound bridge, transition, or deliberate time/space change |
| Expression | What framing, camera movement, performance, sound, and duration serve the intent? | Specific choices; movement and shot size carry meaning rather than decorate the beat |
| Feasibility | Which references/assets exist? What remains unknown or costly? | Readiness gaps and decisions for later production planning; no asset generation |

### Continuity principles

- A material change must happen visibly, be identified as an intentional off-screen event, or remain an `OPEN DECISION`. Never let a new prop, location, injury, costume, or position appear without a cause.
- Plan the transition between shots, not just each shot alone. Track what enters and exits frame, who holds each prop, where people move, and what the next image needs to inherit.
- Establish geography when the audience needs orientation. Do not add a generic wide shot to every scene; a direct start or purposeful disorientation may serve better.
- Keep screenplay facts and authored direction distinct. A useful connective shot may be `INFERRED`; a choice that changes story facts or character intent is an `OPEN DECISION` with options for the user.
- Do not add dialogue or rewrite screenplay action to make the plan easier. Put proposed visual direction in the shot plan.

## Produce the local shot table

Segment the source into scenes and dramatic beats. Preserve original order and line references. Add the visual coverage needed to carry each beat through a coherent sequence. Keep the director’s reason for a shot distinct from the visible action, and keep framing distinct from camera placement and movement. Label provenance at the shot level and split it when a row mixes source and inference—for example, `SCRIPTED action; INFERRED framing and camera move`. Use this table in the user-visible review:

| Scene / shot | Labels | Source beat / status | Director’s note | Proposed action | Framing | Camera | Blocking / continuity | Mood, light, sound, rhythm, duration | Handoff | Readiness / open decision |
|---|---|---|---|---|---|---|---|---|---|---|
| Local shot number | 0–3 functional tags from the list below | Exact source cue or line range; mark `SCRIPTED`, `INFERRED`, or `OPEN DECISION` per part | Why the image matters: audience knowledge, feeling, anticipation, or point of view | Only observable on-screen action; do not put rationale here | Canonical `shot_type`, then shot scale and composition when useful | Angle, canonical camera move, lens when useful, camera position/path | Character, prop, costume, and space state at entry → exit; blocking, axis, and eyelines | Specific emotional tone; lighting, sound, optional rhythm cue, and approximate seconds | The visual, action, eyeline, sound, or time/space link to the next shot | Missing reference/image/anchor, feasibility gap, or the precise choice held for the user |

Use zero to three labels from this controlled set: `GEOGRAPHY`, `ENTRANCE`, `EXIT`, `BRIDGE`, `STATE_CHANGE`, `PROP_INTRO`, `PROP_ACQUISITION`, `PROP_HANDOFF`, `PROP_USE`, `REACTION`, `REVEAL`, `INSERT`, `DIALOGUE_COVERAGE`, `ACTION_COVERAGE`, `TRANSITION`, `TIME_JUMP`, `SOUND_BRIDGE`. Use `—` when none applies. Labels describe a shot’s function; they do not replace source provenance, shot type, or camera terms. After approval, sync labels through the existing shot tags object as `tags.breakdownLabels`; preserve all other tags. When clearing labels on an existing shot, set this key to `[]` only if that removal is in the approved diff. Per-shot Director’s notes remain review-only in v1.

Use precise, standard craft terms and the canonical vocabularies in [canonical-schema.md](references/canonical-schema.md) and [shot grammar](../mixio-pipeline/references/shot-grammar.md). In the `Camera` cell, name the angle and move separately, then give a motivated direction/path, speed or endpoint where useful; distinguish camera travel from actor blocking. For example: `angle: eye_level; move: dolly_in, 0.5 m toward the tablet; lens: standard`. Mark a proposed choice `INFERRED` when the source does not specify it. Framing scale and composition, mood, focus, and cut language can be more specific in the local plan than the current Studio schema; make any lossy mapping visible in the exact diff instead of inventing metadata keys.

Example of a proposed bridge: `INFERRED — the next scripted beat shows the character drawing a sword, but no acquisition is established. Add a brief insert/medium beat showing the sword enter the character’s possession. The source does not say whether it was carried in, found, or received; list those options as an OPEN DECISION if that choice affects the story.`

Use the existing canonical field map in [canonical-schema.md](references/canonical-schema.md) when preparing the approved sync payload. Each synced shot needs real values for `shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, and `duration`; never put `TBD`, `unknown`, or an unresolved story choice into a required field. Keep original dialogue and screenplay lines verbatim. Sync approved functional labels as `tags.breakdownLabels` using the existing tags object and merge semantics. Director’s notes, provenance, source-beat citations, and cut/handoff notes remain in the review plan; do not invent shot metadata keys or persist them as passthrough.

## Check the local draft

Before presenting the diff, confirm:

- Every source beat and required dialogue moment is represented; added coverage is clearly labeled as inference.
- Every character and consequential prop has a legible entry/exit state. Pick-ups, put-downs, handoffs, arrivals, departures, and changes of possession have a cause.
- Location, screen direction, blocking, and eyelines remain understandable across cuts, or a deliberate change is identified.
- Each shot has a purpose and each transition has a visual, action, sound, or time/space relationship to its neighbors.
- Inferred direction does not silently settle a story-changing question.
- Existing images ground only the details they actually show. Missing sheets/anchors are listed as readiness gaps; do not claim visual validation without an image.

Use `/mixio:continuity` for the full local audit. Fix the local plan and repeat the affected checks before preparing the Studio diff.

## Prepare the exact Studio diff

Read the current Studio graph again before comparison. Show a separate change table with one row per operation:

| Operation | Confirmed target ID | Exact change | Related elements | Match confidence / question |
|---|---|---|---|---|
| `ADD`, `UPDATE`, or `NO CHANGE` | Existing scene/shot ID or `NEW` | Exact fields and before → after values | Character, location, prop, and appearance links | Why the match is clear, or what needs resolving |

Match by confirmed element ID and the current scene/shot content. Studio upserts also use scene and shot numbers, so verify each upsert key resolves to the intended ID before calling it. Flag ambiguous matches and unmatched existing shots. Never silently overwrite, renumber, or delete an existing shot. Leave uncertain changes out of the write set and ask a focused question.

Include approved label changes as `tags.breakdownLabels` in the exact diff. For an existing shot, show the prior tag object and the merged result; confirm `episodeId`, `sceneId`, `shotNumber`, and unrelated tags are preserved.

Show the finished shot table and the complete diff, then wait for explicit approval of that diff. If the user changes the plan, rerun the affected checks and show the revised diff before writing.

## Sync after approval

Use the existing tools only after approval:

1. Apply the confirmed scene/shot additions or updates with `studio_upsert_scene_packages` or targeted `studio_revise_shot_specs` as appropriate.
2. Resolve only confirmed Cast & World IDs. Register a missing reference only when it is included in the approved diff and `settings.references.createPolicy` permits it; `propose` and `link_only` require their respective user decision before writing.
3. Add/update typed relations with `studio_link_graph` and appearance state for the approved shot content.
4. Read persisted scenes, shots, references, and relations back. Compare fields and IDs against the approved diff; report exact successes and any partial or mismatched result.

The complete existing write/readback contract is in [persistence-and-audit.md](references/persistence-and-audit.md). That reference documents the post-approval primitives; it does not change the local-first approval gate.

## Workflow

```text
read source + current graph/assets
  → reason through intent, change, state, geography, coverage, flow, expression, feasibility
  → build and locally audit the shot table
  → show the exact ID-matched Studio diff
  → explicit user approval
  → sync with existing primitives and verify by readback
```
