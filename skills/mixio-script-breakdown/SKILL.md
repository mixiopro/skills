---
name: mixio-script-breakdown
description: "Use when a screenplay or high-level script needs a director’s shot plan with connective coverage and an approval-ready Studio diff."
version: 0.3.0
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

Segment the source into scenes and dramatic beats. Preserve original order and line references. Add the visual coverage needed to carry each beat through a coherent sequence. Label provenance at the shot level and split it when a row mixes source and inference—for example, `SCRIPTED beat; INFERRED framing and camera move`. Use this table in the user-visible review:

| Scene / shot | Source beat | Audience purpose / POV | Action, framing, and camera | Character, prop, and space state | Connection from / to | Provenance and rationale | Readiness gaps |
|---|---|---|---|---|---|---|---|
| Local shot number | Exact source cue or line range | What the audience learns or feels | Concrete action plus shot size, angle/move, sound, and approximate duration | Relevant entry → exit state and blocking | How the shot starts from the last and hands off to the next | `SCRIPTED`, `INFERRED`, or `OPEN DECISION`; explain inference | Missing image, sheet, anchor, or unresolved production input |

Example of a proposed bridge: `INFERRED — the next scripted beat shows the character drawing a sword, but no acquisition is established. Add a brief insert/medium beat showing the sword enter the character’s possession. The source does not say whether it was carried in, found, or received; list those options as an OPEN DECISION if that choice affects the story.`

Use the existing canonical field map in [canonical-schema.md](references/canonical-schema.md) when preparing the approved sync payload. Each synced shot needs real values for `shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, and `duration`; never put `TBD`, `unknown`, or an unresolved story choice into a required field. Keep original dialogue and screenplay lines verbatim. Provenance labels remain in the review plan; do not invent a Studio schema to store them.

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
