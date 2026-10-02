---
name: mixio-continuity
description: "Use when a local shot plan needs coverage, action-state, prop, geography, eyeline, or shot-flow checks before Studio sync or generation."
version: 0.3.0
invoke: /mixio:continuity
---

# Mixio Continuity

Audit the local shot plan before it is written to Studio. The check covers both continuity and missing coverage: can the audience follow what happened, how it happened, where everyone is, and why the next image follows? For the full pre-sync loop, see the [pipeline review cycle](../mixio-pipeline/references/pre-sync-review-cycle.md).

Use the shared [director’s lens](../mixio-pipeline/references/directors-lens.md) to judge continuity in service of audience understanding and dramatic flow, not as a checklist that forces generic coverage. Apply the script-supervisor lens to source, prop, wardrobe, eyeline, and position continuity; use the editor’s lens for coverage and cut logic, and bring in camera, art, costume, prop, sound, or action expertise only when the finding needs it.

**Normal mode is read-and-correct locally.** Do not call Studio mutation tools to repair an unapproved plan. If the user asks for an audit of already-persisted shots, report a proposed diff and wait for approval before changing them.

## Inputs and grounding

- The source screenplay/script selected by `mixio-script-breakdown`.
- The current local shot table, including source/inference provenance and the connection to neighboring shots.
- Current Studio references, existing shots, and available images when scoped and accessible.

Declare the evidence mode:

- **GROUNDED** — a relevant reference image or scene anchor is available. Compare only details it actually shows.
- **TEXT-ONLY** — no relevant image is available. Review source and stated direction; do not claim an anchor comparison or report “zero anchor mismatches.”

Missing sheets and anchors are readiness gaps. They do not block this local audit or local planning.

## Audit passes

Run each pass in story order. Show the trace for every finding so the user can see the cause and proposed correction.

### 1. Source coverage

Map every screenplay beat and required dialogue moment to one or more planned shots. Mark added connecting coverage as `INFERRED`. Flag a missed source beat, unnecessary duplicate coverage, or an inference that changes story facts.

### 2. Character and prop state

For each relevant shot, track character presence, position, facing, posture, wardrobe/condition, and consequential props. Record state at entry and exit. A change must have a visible cause, be named as an intentional off-screen event, or remain an `OPEN DECISION`.

Check prop ownership shot by shot. A pickup, put-down, handoff, reveal, disappearance, arrival, or exit needs a legible beat. Fix the shot where the state changes, then re-check dependent shots.

### 3. Geography and staging

Check the location layout, entrances/exits, blocking, screen direction, eyelines, and axis across cuts. Ask whether the subject moved or the camera moved before calling a facing change a continuity error. If no image grounds the layout, mark the assumption as inferred or as a readiness gap.

### 4. Flow, camera, and rhythm

For each cut, state the connection: continuing action, eyeline, match, reveal, contrast, sound bridge, transition, or intentional time/space jump. Check that shot size, camera angle/movement, performance, sound, and duration serve the beat’s purpose. Add coverage only when it clarifies action, cause, geography, or audience response.

### 5. Asset readiness

Note missing reference elements, images, structured details, or anchors for later generation. Separate these from story/continuity findings. Do not create references, upload media, generate assets, or change bindings during this audit.

## Report and corrections

Report in this order:

1. Evidence mode and scene/shot scope.
2. Source beats covered and any omissions.
3. Findings with shot, category, evidence, consequence, and proposed correction.
4. `OPEN DECISION` questions and generation-readiness gaps.
5. Local correction log and the full revised rows/specs.
6. Re-check result for each corrected finding and a list of clean shots.

Use these categories: `COVERAGE`, `CAUSE`, `PROP`, `PRESENCE`, `BLOCKING`, `FACING`, `POSTURE`, `WARDROBE`, `AXIS`, `FLOW`, `CAMERA`, `AUDIO`, `ANCHOR`, `SOURCE`, and `READINESS`.

Correct the local draft, then repeat the affected passes until there are no unresolved continuity breaks. An open story decision is not silently “fixed”; present the alternatives and hold that portion of the sync until the user decides. A readiness gap may remain visible in the approved plan and be handled before generation.

## If auditing persisted shots

Read current records first and identify each by confirmed Studio element ID. Return the proposed before/after changes and any relation updates. Do not use `studio_revise_shot_specs`, `studio_link_graph`, `studio_update_shot_state`, or another mutation until the user approves the exact correction diff. After approval, write through the appropriate existing primitive and read the records back to verify the changes.

## Workflow

```text
read source + local shot plan + available images
  → coverage → state/cause → geography → flow/camera → readiness
  → report traced findings → correct local rows → re-check
  → return clean plan and unresolved decisions for the Studio diff review
```
