---
name: mixio-script-breakdown
description: "Break a script into canonical references, scenes, and shot specs the way Studio's own breakdown workflow does — same schemas, same field vocabularies, same verbatim rules — then persist through the breakdown primitives. Not the continuity check (mixio-continuity) or reference audit (mixio-reference-audit) that follow it. Unclear which step you need → mixio-pipeline."
version: 0.2.0
invoke: /mixio:script-breakdown
---

# Mixio Script Breakdown

Step 03 of `mixio-pipeline`, and the place where craft becomes data. Studio ships this as a server-side workflow (`api/agent-api/src/workflows/script_breakdown`) **and** exposes its internal steps as MCP primitives, explicitly so a skill can substitute its own analysis and still persist through the same validated path.

Two ways to run it:

| | **Managed** — one job | **Composed** — you author, primitives persist |
|---|---|---|
| Call | `studio_submit_studio_job` | `studio_register_reference_entities` → `studio_upsert_scene_packages` → `studio_link_graph` |
| Analysis by | Studio's workflow (Gemini + structured output) | you |
| Granularity | whole script, one call | scene at a time, gated |
| Gates | none, runs to completion | user sign-off between scenes |
| Verbatim safety | regex pass wins over the LLM | you must replicate it (below) |
| Relational audit | server internal | explicit audit emitted + locked into `metadata.pipeline` |
| Use when | you want a fast, schema-safe first pass | you need shot-grammar depth, entity graph linking, per-shot `appearanceState`, and relational audit |

Both paths reach the same contract, so the choice is about **process, not capability** — duration quantization is gone, so there is no longer a field the managed path can't express. Take the managed path for a cheap reproducible draft; take the composed path when you want sheets built first, gates between scenes, explicit entity ID linking, per-shot `appearanceState`, and a verified relational audit.

Best of both: run the **composed** path but keep Studio's two safety properties — derive `scriptBody` / `transitionFromPrevious` / `isContinuation` from the text deterministically rather than authoring them, and self-check against the repair criteria before persisting.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- A project and an episode with source text persisted (`mixio-episode`) — preferably a screenplay, otherwise the raw Idea/Story `script` field

## Source text — screenplay first, `script` only as fallback

Before either path, read the [native screenplay grammar](../mixio-episode/references/screenplay-grammar.md), then read the episode's screenplay element rather than assuming the episode's `script` is current:

```
studio_query_elements({ projectId, type: "SCREENPLAY", tags: { episodeId }, limit: 50, offset: 0, includeFull: true })
```

- A `SCREENPLAY` row with a non-empty `body` wins, **including a draft**. Use its body verbatim as `script_content`; do not strip `#mentions`, `~locks`, or standalone `[Key: Value]` annotation lines because native breakdown consumes them.
- If no screenplay exists, or its `body` is empty, read `studio_get_episode({ episodeId })` and use `metadata.fullScript` as the fallback.

The managed job only analyzes the text supplied in `script_content`. Submitting stale `fullScript` after a screenplay was written silently discards the newer screenplay work.

## Managed path

```
studio_submit_studio_job({
  jobType: "script_breakdown",
  model: "script-preproduction",
  useCaseId: "script-preproduction",
  input: { script_content: "<screenplay body, or fullScript only when no screenplay body exists>" },
  context: { projectId, episodeId }
})
→ jobId ; poll studio_get_job_status({ jobId, projectId })
```

It runs four stages: `prepare_inputs` → `load_production_context` → `script_analysis_structured_output` → `persist_breakdown_tool_calls`. Stage 2 loads the project's existing canonical characters/locations/props (with their `aka` aliases and variant names) into the prompt so the analysis reuses them instead of creating near-duplicates — which is why you should register references **before** running a breakdown on episode 2+.

A completed job that persisted zero scenes is converted to `FAILED` with `BREAKDOWN_EMPTY_PERSISTENCE`. Check status, don't assume.

## Composed path — the six stages, done yourself

```
1. read context      studio_get_production_context({ projectId, episodeId })
                     → canonical.characters / .locations / .props (lookup map for IDs & names)
2. analyze           your own LLM pass → references + scenes + shots (zero placeholders, 7 canonical fields)
3. register refs     studio_register_reference_entities({ projectId, references })
4. persist packages  studio_upsert_scene_packages({ projectId, episodeId, scenes })
                     (with linked_character_ids, linked_location_ids, linked_prop_ids)
5. link appearances  studio_link_graph({ projectId, relations: [...] })
                     (appears_in with appearanceState for every character in each shot)
6. relational audit  audit 100% canonical fields, entity ID graph integrity, scope duration
                     → emit report + lock into episode metadata.pipeline.breakdown_audit
```

Order matters: register references first so `linked_character_ids` / `linked_location_ids` / `linked_prop_ids` (and their name equivalents `character_links` / `location_links` / `prop_links`) resolve to real elements when the scene package materializes relations. Then create typed `appears_in` relations with `appearanceState` via `studio_link_graph` so per-shot wardrobe, condition, and carried props are bound to the graph. Finally, run the relational audit before advancing to Step 04.

## Canonical shot metadata

Seven required fields (`shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, `duration`); persisting a shot without them throws `Shot metadata missing required field <name>` at the materialization gate. Audio cues are decomposed into structured `audio`: `{ dialogue?: string, sfx?: string, ambient?: string }` (populating `audio.sfx` from `[SFX: ...]` and `audio.ambient` from `[Ambient: ...]` verbatim). Every entity present in a shot must be linked — pass both the human-readable canonical names (`character_links` / `location_links` / `prop_links`) and the resolved element IDs (`linked_character_ids` / `linked_location_ids` / `linked_prop_ids`). That's what builds the relation graph `mixio-generate` later reads to pull reference images, and it's what carries per-shot `appearanceState`.

The full field table, the two camera vocabularies (`shot_type` is framing only; `camera_angle`/`lens`/`camera_movement` are their own axes — authoring conventions, not validated enums), the grammar→canonical-key mapping, and the passthrough rules: `references/canonical-schema.md`.

## Duration

A **continuous float, 1–60 seconds**, typical range 3–15. Authored values are preserved exactly: `2.5` persists as `2.5`.

Duration is a continuous float; older Studios quantized it to `Literal[5, 8, 10, 12, 15]` at two normalization sites, so a 2.5s panel silently became 5s and short-form work had to bypass the managed workflow and write through `upsert_scene_packages` directly. **That workaround is retired** — both paths now preserve fractional durations. If a submitted `2.5` reads back as `5`, you're on a Studio that still quantizes — the old snapping applies (`≤6 → 5`, `≤9 → 8`, `≤11 → 10`, `≤13 → 12`, else `15`).

Duration guidance: short holds (2.5–5s) for reaction cutaways, inserts, beat transitions, quick reveals and punctuation; 8–10s for dialogue exchanges, character action and reveals; 12–15s for complex blocking with camera movement, continuous action, emotional beats that need room, and oners. Vary it within a scene — monotonous equal-length shots read flat. Short-form vertical drama typically runs 2.5–4.5s per panel throughout, and that is now expressible on either path.

## Per-shot appearance state

A character reference says who someone *is*. What is true of them in **one shot** — soaked hair, a fresh cut over the left eye, the briefcase they didn't have two shots ago — belongs to the appearance, and a production has many appearances per character. Putting it on the character gives one global value that is only correct somewhere.

It lives on the `appears_in` relation's `metadata`, validated by `appearanceStateSchema`. The
schema permits optional fields, but the breakdown audit requires `wardrobe`, `condition`, and
`carriedProps` for every appearing character; use `[]` when no props are carried. The remaining
fields are optional, and an appearance with no state is not sufficient for a passing breakdown.

| Key | Notes |
|-----|-------|
| `wardrobe` | what they wear in this shot; overrides the character default without editing the reference |
| `hairState` | soaked, cut short, tied back, wind-blown |
| `condition` | injuries, dirt, blood, sweat, exhaustion — cumulative across a sequence |
| `carriedProps` | array of canonical prop names, max 50 |
| `emotionalState` | performance direction. Distinct from the shot's `mood`, which is the mood of the *frame* |
| `lookRef` | point at an existing approved variant by id/name instead of re-describing it |
| `continuityNotes` | anything continuity-relevant the fields above don't cover |

Aliases are mapped, so `costume`/`outfit` → `wardrobe`, `hair`/`hair_state` → `hairState`, `injuries`/`physicalCondition` → `condition`, `props`/`heldProps`/`carried_props` → `carriedProps`, `emotion` → `emotionalState`, `look`/`variant` → `lookRef`, `notes` → `continuityNotes`.

```
studio_link_graph({ projectId, relations: [{
  fromId: characterId, toId: shotId, relationType: "appears_in",
  metadata: { wardrobe: "red tee, dark jeans, bare feet",
              condition: "rested, uninjured",
              hairState: "loose curls, slightly mussed",
              carriedProps: ["PHONE"], emotionalState: "amused, unguarded" }
}]})
```

`lookRef` resolves shot → scene → reference default at generation time, and a stale value (pointing at a renamed/deleted variant) degrades silently to the default rather than erroring, where the cascade is live — check by looking for a `lookBindings` key in `get_production_context`'s response. Re-running this breakdown never wipes an existing binding: presence relations are created only when missing, so an already-bound relation's metadata is untouched by a re-run.

**Still not covered by a canonical field:** zone, facing, posture, and relative-to. `appearanceState` is deliberately appearance, not staging, and the shot's `blocking` is one string for the whole frame. They're durable-but-unchecked, not session-local: written as passthrough they persist and survive re-entry, and — on jobs where the prompt materializer actually runs (`promptEnhancementMode: "enhance"`, see `references/canonical-schema.md`) — reach the generation prompt under `- Additional direction:`. Either way nothing downstream reads or enforces them, so the continuity blocking map's pose columns still need restating per shot rather than trusted from inheritance — see `mixio-continuity`.

## Canonical scene metadata

Scene keys are **camelCase**; shot keys are **snake_case** — mixing them up sends the field to the passthrough partition where nothing reads it. `anchorRef` is the payoff of the sheets step: generation auto-attaches it to **every** shot in the scene, so the caller never restates it per shot.

Full field table (`heading`, `scriptBody`, `dialogueLines`, `anchorRef`, …) and scene `status` progression: `references/canonical-schema.md`.

### Verbatim is a hard rule

Preserve source language exactly. Never translate, romanize, paraphrase, or rewrite `scriptBody`, `screenplayLines`, `dialogueLines`, `cameraNotes`, or `directorNotes` — keep line breaks and ordering.

`dialogueLinesRomanized` is the single exception and never a replacement: keep `dialogueLines` in the source alphabet and supply a transliteration at the same index (Devanagari → IAST-style, Chinese → pinyin, Japanese → romaji). Transliterate the **sound**, not the meaning. Empty list when the dialogue is already Latin script. Never put romanized text into `dialogueLines`, `scriptBody`, `screenplayLines`, or any shot field.

## Scene segmentation

Match Studio's own recognizers so your scene boundaries agree with the server's:

- **Heading** — optional leading scene number, then one of `INT` · `EXT` · `INT/EXT` · `I/E` · `EST`, with optional trailing period.
- **Time of day** — `DAY` `NIGHT` `DAWN` `DUSK` `MORNING` `EVENING` `LATER` `CONTINUOUS` `SUNSET` `SUNRISE` `SAME`.
- **Transitions** — `CUT TO` `SMASH CUT TO` `MATCH CUT TO` `DISSOLVE TO` `FADE TO` `JUMP CUT TO` `WIPE TO` `INTERCUT [TO]` `BACK TO` `CONTINUED` `HARD CUT TO`.
- **Continuations** — `CONTINUED`, `INTERCUT`, `INTERCUT TO`, `BACK TO` set `isContinuation: true`.

`sceneNumber` and `shotNumber` start at 1 and must be ordered. `tags.sceneNumber` and `tags.shotNumber` are set automatically on persist; `tags.episodeId` is what scopes later queries.

### The deterministic pass wins

Studio does not trust the LLM with the source text. A non-LLM pass walks the script line by line, derives scene chunks from the heading regex — heading, `location`, `timeOfDay`, transition cue, `isContinuation`, sequential number, and verbatim body — then matches each LLM scene to a chunk (exact heading, then substring, then location/time, then position). On the three fields that record what the script *says*, the chunk wins:

```python
resolved_script_body = _pick_first_non_empty(
    chunk_map.get("scriptBody"),   # ← parser
    metadata.get("scriptBody"),    # ← LLM
    ...)
```

Same precedence for `transitionFromPrevious` and `isContinuation`. Below that sit two fallbacks: no LLM scenes → synthesize scenes from the chunks alone; no chunks either → one scene holding the whole script with annotation lines derived by pattern.

Consequence for the composed path: **derive those three fields from the text, don't author them.** If the same script ever goes through the managed path, the parser's version is what survives, so authoring them differently just creates a discrepancy. The LLM's job is shot design; the parser's job is the record.

### What the breakdown does and does not produce

The depth is asymmetric, and assuming otherwise is how the sheets step gets skipped:

| | Depth |
|---|---|
| **Scenes** | deep — full verbatim capture |
| **Shots** | deep — the whole canonical spec |
| **References** | **shallow** — `{ name, description, attributes? }` and nothing else |

The breakdown writes no `characterDetails` or `locationDetails`: no build, skin, hair, `visualAnchor`, no `spatialLayout`, `depthAxes`, `accessPoints`. References come out as *stubs*. Enriching them is `mixio-sheets`' job, which is why the pipeline runs sheets at Step 02 and the breakdown at Step 03 — build the sheets first and the breakdown's context-loading stage finds those canonical names, aliases and variants and reuses them instead of minting near-duplicate stubs.

## Reference extraction

Emit three lists, each entry `{ name, description, attributes? }`, then upsert:

```
studio_register_reference_entities({ projectId, references: [
  { type: "CHARACTER", name: "TONY", metadata: { description, attributes } },
  { type: "LOCATION",  name: "TONY & POPPY'S BROOKLYN APARTMENT", ... },
  { type: "PROP",      name: "CEREAL BOWL", ... }
]})
```

Matching is by normalized `project + type + name`, so it is idempotent — run it before every breakdown. Reuse canonical names exactly as `studio_get_production_context` returns them; a name listed as an `aka` is the *same* entity and a listed variant is a *state* of that entity, never a separate reference. `TONY (gala)` as a second CHARACTER splits the identity and both halves drift.

## Quality gates

**Missing required fields do not fail loudly.** Absence persists as `""` rather than the literal `"TBD"` — older Studios wrote `"TBD"` and defaulted `duration` to `10`; check which you're on by reading a thin shot back. Either way the materialization gate only rejects null, and the read side filters `""`, `tbd`, `unknown`, `n/a`, `na`, `none`, `null` as placeholders — so a thin shot passes validation and renders blank everywhere. Reads still filter `"TBD"` because existing rows contain it. Never emit a placeholder to satisfy the gate: write a real value or don't create the shot.

A scene needs a repair pass when any of these hold; check your own output the same way:

- `scriptBody` under 20 characters, or a placeholder value
- `heading`, `location`, or `timeOfDay` is a placeholder
- `scriptBody` has ≥2 non-empty lines but `screenplayLines`, `dialogueLines`, `cameraNotes`, and `directorNotes` are all empty

On repair: fill missing/weak metadata from the raw script, keep scene and shot ordering stable, preserve existing non-placeholder fields, and split/merge/add scenes only if the draft is genuinely incomplete.

## Persisting

Read the production context first and build a name-to-ID map from its canonical references. The
complete ID-safe persistence and relation-linking example lives in
[references/persistence-and-audit.md](references/persistence-and-audit.md). It extracts the
persisted shot ID from `studio_upsert_scene_packages` before calling `studio_link_graph`; if a
Studio response omits nested IDs, query the scoped SHOT by episode, scene number, and shot number.
Never substitute a fabricated ID.

Max 100 scenes per call. Scenes upsert by `sceneNumber + episodeId`; shots by `shotNumber` within a scene. Both `metadata` and `tags` merge, so a later partial write preserves omitted keys.

For refinement after the initial persist use `studio_revise_shot_specs` (content) and `studio_update_shot_state` (workflow state) — see `mixio-continuity`. `revise_shot_specs` validates the spec partition partially, so you may send just the keys you're changing.

## Relational Audit (Immediate Verification)

Immediately after persisting scenes, shots, and appearance relations, execute a deterministic relational audit across three pillars:

### 1. 100% Canonical Fields Audit
Verify that all 7 required canonical fields are populated with real, non-placeholder values across 100% of persisted shots:
- `shot_type`: valid framing convention (e.g. `close_up`, `wide`, `over_shoulder`, `two_shot`).
- `camera_movement`: valid camera movement (e.g. `static`, `dolly_in`, `tracking`, `handheld`).
- `subject`: concrete character/subject description (no blank or generic strings).
- `action`: unambiguous physical action and staging beat.
- `context`: specific environmental setting and conditions.
- `style_ambiance`: lighting/color palette direction.
- `duration`: continuous float between 1.0 and 60.0 seconds (e.g. `3.5`).
- **Zero-placeholder rule**: Fail if any field contains `""`, `"TBD"`, `"tbd"`, `"n/a"`, `"na"`, `"unknown"`, `"none"`, or `"null"`.

### 2. Cast & World Graph Integrity
Verify all relational connections:
- **Entity ID validation**: Every ID in `linked_character_ids`, `linked_location_ids`, `linked_prop_ids` resolves to an existing element in Cast & World (`studio_get_production_context` / `studio_list_references`). Zero orphaned links.
- **Appearance State coverage**: Every character occurring in `linked_character_ids` for a shot must have a corresponding `appears_in` relation with non-empty `wardrobe`, `condition`, and `carriedProps` (use `[]` when no props are carried). Other appearance fields remain optional.
- **Anchor attachment**: Every scene carries `anchorRef` referencing the scene's approved visual anchor.

### 3. Scope & Duration Reconciliation
- **Planned runtime source**: Read `studio_get_episode({ episodeId })` before the audit and require `metadata.pipeline.planned_runtime_seconds`, set during preflight or explicitly supplied by the user. Do not claim a scope match when this value is absent.
- **Total Duration**: Sum of all shot durations must equal that planned scene/episode runtime; report both values and the difference.
- **Shot Count**: Total shots match the decomposed dramatic beats from the screenplay.

### 4. Emit Audit Report & Lock Metadata
Emit a structured audit summary with actual counts, total duration, planned runtime, duration
delta, resolved entity counts, and appearance-state coverage. Lock it into episode
`metadata.pipeline.breakdown_audit` only after all checks pass. The concrete report and metadata
payload are in [references/persistence-and-audit.md](references/persistence-and-audit.md).

## Workflow

```
1. read SCREENPLAY by `tags.episodeId`; use non-empty `body`, otherwise episode `metadata.fullScript`
2. studio_get_production_context({ projectId, episodeId })   → build entity ID & canonical name lookup map
3. segment the selected source verbatim into scenes (headings, transitions, time-of-day); retain native mentions, locks, and standalone annotations
4. extract characters/locations/props → studio_register_reference_entities
5. design shots per scene — 7 canonical fields with zero placeholders; map linked entity IDs and author per-shot appearanceState
6. self-check against the repair criteria; fix rather than emitting "TBD"
7. studio_upsert_scene_packages({ scenes })                  → persist scenes and shots with linked_*_ids
8. studio_link_graph({ relations })                          → attach appears_in relations with appearanceState
9. run relational audit (100% fields, valid entity IDs, duration/scope match) → lock into metadata.pipeline.breakdown_audit
10. → /mixio:continuity for the continuity audit, then /mixio:shot-planning
```

## Notes

- Each shot should have a stated purpose — establish, reveal, react, transition, climax, tension, release. Not every scene needs an establishing shot; jump into action when the audience already knows the space, or when disorientation serves the tone.
- One shot with a `tracking` or `crane` move can legitimately cover several story beats. Longer takes suit climaxes.
- Verify `counts.shots` matches what you sent. A silent shortfall means shots were skipped by the per-item validator, not that the call failed.
- The managed path uses `gemini-3-flash-preview` with structured output and a repair pass. If your composed breakdown is thinner than that, use the managed path instead.
