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

`pass` and `pass_with_weaknesses` are eligible for Mixio intake. `needs_revision` is a hard stop: return to the upstream route and resolve the listed corrections before locking the screenplay in Mixio.

## What crosses the boundary

The upstream layer sends story intent, craft decisions, source text, and review status. It must preserve source language, line order, standalone native annotations, `#` references as literal source tokens when present, and `~` continuity locks. It must not send or invent:

- Mixio project, episode, scene, shot, element, or reference IDs;
- native `#name.variant[.view]` reference mentions;
- generation model IDs, media URLs, keyframe IDs, or Studio job payloads;
- visual claims that have not been grounded by a Mixio reference or anchor.

## Mixio intake

After receiving the package, Mixio performs the following in order:

1. **Frame contract:** lock delivery and anchor aspect ratios.
2. **Screenplay:** read `screenplay-grammar.md`, preserve source language and line order, list references, normalize mentions and annotations, then persist a draft with `studio_upsert_screenplay`.
3. **Reference layer:** build or reuse character, location, prop, and scene-anchor references.
4. **Production gates:** run reference audit, script breakdown, continuity audit, and shot planning before any billable generation.

The native screenplay body remains the source of truth for breakdown once it is non-empty. If the upstream artifact is only an outline or scene card, Mixio Step 01 must expand it into screenplay form before Step 02.

## Re-entry rules

| Change | Return to | Production consequence |
|---|---|---|
| Premise, protagonist, world rule, or arc change | Relevant upstream route + quality gate | Rebuild the handoff before Step 01 |
| Scene function, beat order, or dialogue change | Upstream scene/dialogue/rewrite route | Re-lock screenplay and repeat affected Mixio steps |
| Native screenplay formatting or reference mention issue | Mixio Step 01 | Preserve story intent; repair only the production source form |
| Cast & World, staging, prop, or shot continuity issue | Mixio sheets/audit/continuity | Do not send a visual continuity issue to rewrite-doctor automatically |
| Generated image/video mismatch | Mixio evaluation and generation steps | Revise or regenerate; story gate stays valid unless intent changed |
