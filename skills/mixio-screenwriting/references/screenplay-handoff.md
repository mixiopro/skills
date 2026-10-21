# Screenplay Development Handoff

This handoff is the seam between the upstream `how-to-make-script` writing system and Mixio Studio production. It preserves dramatic intent without asking the production layer to rediscover the story.

## Required package

Return these fields when story development is ready to enter Mixio:

```yaml
medium: feature_film | episodic | short_drama | animation | commercial | branded_film | shortform_video | documentary
logline: "One sentence carrying protagonist, pressure, stakes, and motion."
premise: "Compact paragraph describing the story engine and emotional promise."
character_world:
  protagonist_pressure: "Desire, fear, contradiction, misread, and cost."
  relationships: "Allies, rivals, dependencies, and pressure points."
  world_rules: "Rules that create unavoidable story pressure."
structure:
  artifact: beat_sheet | outline | treatment | null
  content: "Causal turns and escalation, when structure work was requested."
screenplay: "Native-screenplay-ready scene blocks or the latest scene/screenplay draft."
quality_gate:
  status: pass | pass_with_weaknesses | needs_revision
  hard_failures: []
  weighted_weaknesses: []
  next_corrections: []
constraints:
  genre: ""
  tone: ""
  audience: ""
  language: ""
  platform: ""
  duration: ""
  ip_or_voice: ""
```

Fields that do not apply may be `null` or an empty list. Do not use placeholders such as `TBD`, `unknown`, or `n/a` to satisfy the shape. If a required story decision is unresolved, report it as a quality-gate weakness or ask for clarification.

All three outcomes are review findings, not authorization states. Summarize `needs_revision` items and offer focused corrections. If the user confirms the presented screenplay or has already authorized that scope, continue into Mixio with the findings recorded; preserve consequential unresolved story choices as `OPEN DECISION` rather than inventing answers. Resolve a question only when the next dependent action cannot be specified without it.

## What crosses the boundary

The upstream layer sends story intent, craft decisions, source text, and review status. It must preserve source language, line order, standalone native annotations, `#` references as literal source tokens when present, and `~` continuity locks. It must not send or invent:

- Mixio project, episode, scene, shot, element, or reference IDs;
- native `#name.variant[.view]` reference mentions;
- generation model IDs, media URLs, keyframe IDs, or Studio job payloads;
- visual claims that have not been grounded by a Mixio reference or anchor.

## Mixio intake

After receiving the package, Mixio performs the following in order:

1. **Project and episode setup:** resolve scope, then read the current screenplay/script, references, existing shots, settings, and available images.
2. **Source selection:** read `screenplay-grammar.md` when interpreting or authoring native screenplay text. A non-empty native `SCREENPLAY` body is the source; otherwise use the existing episode script or supplied high-level source. Preserve whichever source is selected verbatim during shot planning. Do not require an outline or scene card to be expanded into screenplay form unless the user asked for screenplay development. When the user requests screenplay authoring or revision in Mixio, present the text as a checkpoint; on chat confirmation or prior authorization, save it as a draft with `studio_upsert_screenplay` and continue from its read-back body without requiring a Studio approval status.
3. **Local production plan:** build and audit the director’s shot plan before any breakdown write; show the exact Studio diff as a checkpoint and proceed on chat confirmation or prior authorization for that scope.
4. **Confirmed sync and readiness:** sync the confirmed breakdown and verify readback, then audit and build missing references/anchors before shot planning.
5. **Shot planning and generation:** select methods/models, follow the user's generation-authorization instructions, then generate and evaluate through the production pipeline.

The native screenplay body remains the source of truth for breakdown once it is non-empty. The local shot plan preserves the selected source and labels visual additions as sourced, inferred, or open decisions.

## Re-entry rules

| Change | Return to | Production consequence |
|---|---|---|
| Premise, protagonist, world rule, or arc change | Relevant upstream route + quality gate | Rebuild the handoff before the local shot plan |
| Scene function, beat order, or dialogue change | Upstream scene/dialogue/rewrite route | Re-lock the source and rebuild the local plan before sync |
| Native screenplay formatting or reference mention issue | Project/episode setup, before local planning | Preserve story intent; repair the production source only when authorized |
| Cast & World, staging, prop, or shot continuity issue | Mixio continuity or reference readiness | Do not send a visual continuity issue to rewrite-doctor automatically |
| Generated image/video mismatch | Mixio evaluation and generation steps | Revise or regenerate; story gate stays valid unless intent changed |
