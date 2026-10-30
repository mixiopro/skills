---
name: mixio-blocking
description: "Previsualize actor, prop, and camera blocking as a simple Three.js scene tied to a confirmed Studio shot. Use when spatial staging or movement needs a visual review before video generation; for shot breakdown use mixio-script-breakdown, and for text continuity checks use mixio-continuity."
version: 0.1.0
invoke: /mixio:blocking
---

# Mixio Blocking

Build a reviewable spatial blocking proxy for selected shots. Blocking defines where performers and important props are, how they move and relate, what they look toward, and how the camera sees that action. The Three.js render is a staging reference for review; it is not final animation, a photorealistic look reference, or a replacement for the generated shot.

Use this skill after the breakdown has been confirmed and synced to Studio and reference readiness is complete, because its tools require a persisted shot. Read the screenplay, shot specs, scene anchor, location details, and character/prop references that affect the selected shot. Preserve authored direction. Label any inferred position, route, eyeline, or camera placement, and surface choices that change screen direction, geography, or dramatic emphasis for review.

## Scope and tool contract

Resolve and restate the confirmed project, episode, scene, and shot before reading or writing shot-scoped data. Numbered shot labels repeat across scenes and episodes; use confirmed element IDs, never a guessed ID.

The Mixio CLI exposes `create-threejs-scene-take` and `render-threejs-scene` (the hosted MCP names are `create_threejs_scene_take` and `render_threejs_scene`; the local bridge may prefix them with `studio_`). Call `studio_describe_tools` for the active transport's tool details before use. The CLI contract describes:

- `create-threejs-scene-take`: saves an immutable, non-billable code take for one shot; it does not render. Pass the confirmed `projectId`, `episodeId`, `sceneId`, and `shotId`, plus `input.source`, `input.parameters`, and `input.settings`. A first take may include `name`; a revision may include `parentTakeId` or the existing `sceneProgramId`.
- `input.source`: a JavaScript module exporting a default `createScene` function. The CLI contract's example receives `{ THREE, scene }` and adds Three.js objects to `scene`. Do not assume additional runtime helpers or imports; inspect the live tool description/contract for the deployed environment.
- The current tool contract does not specify a timeline/update callback or animation semantics. Do not claim that a multi-beat blocking path was rendered or validated unless the live runtime contract documents how time drives the scene. If it does not, use static key poses or separate take revisions to show staging states, and mark continuous movement as unverified.
- `input.parameters`: up to 100 declared numeric controls with `id`, `label`, `min`, `max`, `step`, and `defaultValue`.
- `input.settings`: required `width`, `height`, `fps`, and `durationSeconds`; the current schema allows 64–3840 pixels per dimension, 1–60 fps, and durations above 0 through 30 seconds.
- `render-threejs-scene`: submits a capped, non-billable render only when the environment render policy is enabled. It requires the confirmed project/episode/scene/shot, `sceneProgramId`, `takeId`, and a stable `idempotencyKey`; optional `parameterOverrides` must use declared parameters. Poll the returned Studio job with `get_job_status`.

Tool contracts can change. Use `mixio get-contract --target tool --tool-name create_threejs_scene_take` and the corresponding render tool on the CLI, or the active transport's schema discovery, when exact current fields or limits are needed. Do not submit a guessed payload.

## Build a blocking proxy

1. **Extract the staging facts.** Record the playable area and persistent landmarks, entrances/exits, performer start/end positions, facing, posture, eyelines, prop handoffs, and camera position/framing. Choose and state one world-axis convention for the scene (for example, Y-up, X lateral, Z depth), then keep it stable across takes. Track the axis of action and screen direction; flag reversals rather than silently correcting them.
2. **Separate authored facts from inference.** Use `SCRIPTED`, `INFERRED`, and `OPEN DECISION`. Ask for a decision when alternatives alter a reveal, power relationship, eyeline, screen direction, or intended camera coverage.
3. **Represent only what staging needs.** Use simple, readable proxy shapes for performers, furniture, doors, and hand props. Give performers distinct labels/colors, show the floor plane and location landmarks, and use unobtrusive paths or markers to clarify movement and timing. Avoid spending effort on surface realism or final costume detail.
4. **Keep the camera legible.** Show the camera/frustum or a clear view marker when the runtime supports it. Check that the proxy view communicates foreground/background order, entrances, eyelines, key prop interactions, and intended screen direction. Never invent a camera move that conflicts with the shot spec.
5. **Create and render a take.** Write a concise scene module and only the numeric parameters needed for review. Match dimensions and duration to the shot's approved settings where the live tool allows them. Save the take with full confirmed scope, then render it with its returned program/take IDs and a stable idempotency key. A disabled render policy is a reported limitation, not a reason to bypass the tool.
6. **Review and revise.** Inspect the rendered proxy and compare it against the screenplay, shot spec, and anchor. Report concrete issues such as a crossed axis, blocked eyeline, unreachable prop, obscured entrance, or camera path through geometry. Create a child take for revisions so provenance remains intact. Do not overwrite the approved screenplay or silently change shot direction.
7. **Hand off to planning.** Record the reviewed take/render IDs, staging facts, open decisions, and findings. A render does not approve itself. Get human confirmation before treating it as accepted staging evidence. If it changes the accepted shot direction, update the local Continuity Checklist and plan, show the revised Studio diff, and sync the confirmed change before planning production.

## Pipeline relationship

In the full episode workflow, this is optional Step 04.5, after Step 03 Studio sync and Step 04 reference readiness, before Step 05 shot planning. The tools require a confirmed persisted shot, so do not call them on the local-only breakdown. Use this step only for selected shots where staging benefits from spatial review; simple holds, inserts, and shots with unambiguous staging can skip it. The Step 02 Continuity Checklist remains the source of pre-sync concerns; revisit its affected items if proxy review changes direction.

If proxy review finds that the accepted shot direction should change, update the local plan and Continuity Checklist, present the revised exact Studio diff, and return to Step 03 for confirmation and sync. Rebuild affected proxies and refresh reference readiness as needed before Step 05. Any breakdown or blocking change after shot planning invalidates the dependent plan. Track take/render IDs, review state, and unresolved decisions in the host's task/plan surface or working handoff; do not invent an episode metadata key for this optional step.

## Limits

- The Three.js proxy communicates spatial and temporal staging, not final character identity, performance nuance, lighting, wardrobe, or rendered-image quality.
- It does not replace the Continuity Checklist in `mixio-continuity`, the anchor/reference work in `mixio-sheets`, shot planning, generated-video evaluation, or human approval.
- This tool surface delivers a shot-scoped proxy, not an assembled film or timeline.
