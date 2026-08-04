---
name: mixio-script-breakdown
description: "Break a script into canonical references, scenes, and shot specs the way Studio's own breakdown workflow does — same schemas, same closed enums, same verbatim rules — then persist through the breakdown primitives."
version: 0.1.0
invoke: /mixio:script-breakdown
---

# Mixio Script Breakdown

Step 03 of `mixio-pipeline`, and the place where craft becomes data. Studio ships this as a server-side workflow (`api/agent-api/src/workflows/script_breakdown`) **and** exposes its internal steps as MCP primitives, explicitly so a skill can substitute its own analysis and still persist through the same validated path.

Two ways to run it:

| | **Managed** — one job | **Composed** — you author, primitives persist |
|---|---|---|
| Call | `studio_submit_studio_job` | `studio_register_reference_entities` → `studio_upsert_scene_packages` |
| Analysis by | Studio's workflow (Gemini + structured output) | you |
| Detail ceiling | the canonical spec, nothing more | canonical spec **plus** freeform craft keys |
| Use when | you want a fast, schema-safe first pass | you need shot-grammar-level camera/lighting detail |

Use **managed** to get a legitimate breakdown in one call. Use **composed** when the shot grammar matters — the managed path cannot express a lens, and it collapses camera angle into `shot_type` (see the mapping table below).

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- A project and an episode with `script` persisted (`mixio-episode`)

## Managed path

```
studio_submit_studio_job({
  jobType: "script_breakdown",
  model: "script-preproduction",
  useCaseId: "script-preproduction",
  input: { script_content: "<full script text>" },
  context: { projectId, episodeId }
})
→ jobId ; poll studio_get_job_status({ jobId, projectId })
```

It runs four stages: `prepare_inputs` → `load_production_context` → `script_analysis_structured_output` → `persist_breakdown_tool_calls`. Stage 2 loads the project's existing canonical characters/locations/props (with their `aka` aliases and variant names) into the prompt so the analysis reuses them instead of creating near-duplicates — which is why you should register references **before** running a breakdown on episode 2+.

A completed job that persisted zero scenes is converted to `FAILED` with `BREAKDOWN_EMPTY_PERSISTENCE`. Check status, don't assume.

## Composed path — the four stages, done yourself

```
1. read context      studio_get_production_context({ projectId, episodeId })
                     → canonical.characters / .locations / .props (reuse these names)
2. analyze           your own LLM pass → references + scenes + shots
3. register refs     studio_register_reference_entities({ projectId, references })
4. persist           studio_upsert_scene_packages({ projectId, episodeId, scenes })
5. refine (later)    studio_revise_shot_specs / studio_update_shot_state
```

Order matters: register references first so `character_links` / `location_links` / `prop_links` resolve to real elements when the scene package materializes relations.

## Canonical shot metadata

Seven required fields. Persisting a shot without them throws `Shot metadata missing required field <name>` at the materialization gate.

| Key | Required | Notes |
|-----|----------|-------|
| `shot_type` | ✅ | closed enum below — **size and angle conflated** |
| `camera_movement` | ✅ | closed enum below |
| `subject` | ✅ | primary subject; ≤1000 chars |
| `action` | ✅ | what happens in the shot; ≤2000 |
| `context` | ✅ | environment/surroundings; ≤2000 |
| `style_ambiance` | ✅ | visual style, lighting, palette; ≤2000 |
| `duration` | ✅ | seconds — read the duration section, it is not what you expect |
| `temporal_effect` | — | defaults `"normal"`; ≤256 |
| `audio` | — | `{ dialogue?, sfx?, ambient? }`. A bare string is coerced to `{ sfx }` |
| `character_links` | — | canonical **names**, not ids |
| `location_links` | — | canonical names |
| `prop_links` | — | canonical names |
| `linked_character_ids` | — | resolved element ids, if you already have them |
| `linked_location_ids` | — | ” |
| `linked_prop_ids` | — | ” |

Every entity present in a shot must be linked — that's what builds the relation graph `mixio-generate` later reads to pull reference images.

### `shot_type` — one of exactly these

```
wide  establishing  medium  close_up  extreme_close_up  pov
two_shot  over_shoulder  low_angle  high_angle  montage  abstract
```

Pick by story need, not formula:

- `wide` / `establishing` — geography, scale, isolation, new world
- `medium` — conversation, relationship, ordinary human interaction
- `close_up` — emotion, decision, internal conflict, detail
- `extreme_close_up` — obsession, micro-detail, time pressure
- `two_shot` — relationship dynamics, power balance, confrontation
- `over_shoulder` — subjective perspective, dialogue intimacy
- `pov` — immersion, vulnerability, discovery
- `low_angle` — power, threat, heroism, scale
- `high_angle` — vulnerability, surveillance, overview
- `montage` — time passage, parallel action, accumulation
- `abstract` — mood, theme, non-literal storytelling

### `camera_movement` — one of exactly these

```
static  dolly_in  dolly_out  pan_left  pan_right  tilt_up
tilt_down  tracking  crane  handheld  arc  rack_focus
```

Match the move to emotional intent: `static` for tension, contemplation, dialogue weight, formality · `tracking`/`dolly_*` for following action, revealing space, momentum · `crane` for geography, power shifts, emotional distance · `handheld` for urgency, chaos, documentary · `arc` for reveals and circling tension · `rack_focus` for shifting attention between dual subjects · `pan` for surveying and following gaze · `tilt` for scale and vertical discovery.

## Where the fine-grained camera detail actually goes

This is the mapping from shot-grammar prose (`mixio-pipeline/references/shot-grammar.md`) onto what persists. Three of these have **no contracted home** — they survive as freeform passthrough keys, which the write boundary preserves verbatim but does not validate.

| Grammar field | Canonical key | Status |
|---|---|---|
| shot size (`EWS`, `MCU`, `OTS`) | `shot_type` | closed enum |
| camera angle (low/high/eye) | `shot_type`, **or** `angle` | conflated in the enum; `angle` is passthrough but *is* read by prompt builders |
| camera motion | `camera_movement` | closed enum |
| **lens (wide/normal/tele)** | **nothing** | no field exists — put it in `style_ambiance` prose |
| `Lighting: as Anchor N` | `lighting` (passthrough) + `style_ambiance` | read by prompt builders, uncontracted |
| in-frame `FG`/`MG`/`BG` layering | `blocking` or `subjectPosition` (passthrough) | read by prompt builders, uncontracted |
| mood/atmosphere | `mood` or `atmosphere` (passthrough) | read by prompt builders, uncontracted |
| `Dialogue` / `Audio` | `audio.dialogue` / `audio.sfx` / `audio.ambient` | contracted |
| `Cut:` hold + outgoing cut | `action` prose, or `temporal_effect` | no dedicated field |
| `Pacing` (RAPID/PUNCHY) | passthrough `pacing` | skill-local only |
| `[M1]`/`[M2]` markers | inline in `action` text | skill-local only |
| `Camera:` placement sentence | `context`, or passthrough `description` | — |

**Set `lighting`, `blocking`, and `mood` even though they're uncontracted** — six call sites across `production-prompting.ts` and `production-job-submission.ts` read them into every generated prompt. Omitting them silently loses lighting and staging direction at generation time. `angle` likewise: `resolveShotSpec` reads `angle` / `cameraAngle` / `camera_angle` and emits it as `Camera angle`.

Anything not in the canonical key list lands in an unvalidated passthrough partition and persists as-is, so `chunk_index`, `pacing`, and `anchor_ref` are all safe to write — just don't expect a Studio surface to read them.

## Duration — the sharp edge

Two layers disagree, and which one you use decides what you can express.

- **Persistence (`upsert_scene_packages`, `revise_shot_specs`)** accepts any positive finite number. `2.5` persists as `2.5`.
- **The managed workflow** pins duration to `Literal[5, 8, 10, 12, 15]` and *snaps* anything else:

  ```
  ≤6 → 5    ≤9 → 8    ≤11 → 10    ≤13 → 12    else → 15
  ```

So a 2.5s panel submitted through the managed path comes back as 5s, and the authored value is gone — it was never persisted. **For short-form vertical drama with 2.5–4.5s panels, use the composed path**, or every shot collapses onto the 5s floor and the cutting rhythm is unrecoverable.

Duration guidance when you are on the 5/8/10/12/15 grid: `5` for reaction cutaways, inserts, beat transitions, quick reveals · `8`–`10` for dialogue exchanges, character action, reveals · `12`–`15` for complex blocking with camera movement, continuous action, emotional beats that need room, oners. Vary it within a scene; monotonous equal-length shots read flat.

## Canonical scene metadata

| Key | Notes |
|-----|-------|
| `heading` | `INT. CAFE - DAY` |
| `location` | location name |
| `timeOfDay` | `DAY`, `NIGHT`, … |
| `scriptBody` | the **exact scene excerpt**, not a summary; ≤40 000 |
| `screenplayLines` | verbatim action/narration lines |
| `dialogueLines` | verbatim dialogue, original alphabet |
| `dialogueLinesRomanized` | Latin-script reading aid, **index-aligned** with `dialogueLines` |
| `cameraNotes` | verbatim camera cues from the script |
| `directorNotes` | verbatim director/intent lines |
| `transitionFromPrevious` | e.g. `CUT TO` |
| `isContinuation` | true when the scene continues the previous beat without a hard cut |

Scene keys are **camelCase**; shot keys are **snake_case**. Not a typo in this doc — that's the actual contract, and mixing them up sends your field to the passthrough partition where nothing reads it.

Scene `status`: `scripting` (default) → `breakdown` → `approved`.

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

**Missing required fields do not fail loudly — they persist as `"TBD"`.** The workflow fills absent required fields with `"TBD"` (and `duration` with `10`), the materialization gate only rejects null, and the read side filters `""`, `tbd`, `unknown`, `n/a`, `na`, `none`, `null` as placeholders. A thin shot therefore passes validation and renders blank everywhere. Never emit a placeholder to satisfy the gate — either write a real value or don't create the shot.

A scene needs a repair pass when any of these hold; check your own output the same way:

- `scriptBody` under 20 characters, or a placeholder value
- `heading`, `location`, or `timeOfDay` is a placeholder
- `scriptBody` has ≥2 non-empty lines but `screenplayLines`, `dialogueLines`, `cameraNotes`, and `directorNotes` are all empty

On repair: fill missing/weak metadata from the raw script, keep scene and shot ordering stable, preserve existing non-placeholder fields, and split/merge/add scenes only if the draft is genuinely incomplete.

## Persisting

```
studio_upsert_scene_packages({ projectId, episodeId, scenes: [{
  sceneNumber: 1,
  name: "INT. TONY & POPPY'S BROOKLYN APARTMENT — DAY",
  status: "breakdown",
  metadata: { heading, location, timeOfDay, scriptBody, screenplayLines,
              dialogueLines, dialogueLinesRomanized, cameraNotes,
              directorNotes, transitionFromPrevious, isContinuation },
  shots: [{
    shotNumber: 7,
    name: "Tony takes the tablet",
    metadata: {
      shot_type: "over_shoulder", camera_movement: "dolly_in",
      subject: "TONY on the BED, seated cross-legged",
      action: "TONY drops her phone onto the bedding beside her, then reaches with her right hand to take the tablet from POPPY [M2].",
      context: "TONY & POPPY'S BROOKLYN APARTMENT, day, warm sunlight through the two WINDOWS",
      style_ambiance: "warm lived-in Italian-American Brooklyn; normal lens; long diagonal light shafts",
      duration: 4.5,
      audio: { dialogue: "—", ambient: "a truck downshifting outside" },
      character_links: ["TONY", "POPPY"],
      location_links: ["TONY & POPPY'S BROOKLYN APARTMENT"],
      prop_links: ["TABLET", "PHONE"],
      // freeform craft keys — read by prompt builders, not schema-validated
      angle: "eye level", lighting: "as Anchor 1",
      blocking: "FG → TONY's right shoulder; MG → tablet screen; BG → POPPY's face, soft focus"
    }
  }]
}]})
→ { scenes: [...], counts: { scenes, shots } }
```

Max 100 scenes per call. Scenes upsert by `sceneNumber + episodeId`; shots by `shotNumber` within a scene. Both `metadata` and `tags` merge, so a later partial write preserves omitted keys.

For refinement after the initial persist use `studio_revise_shot_specs` (content) and `studio_update_shot_state` (workflow state) — see `mixio-continuity`. `revise_shot_specs` validates the spec partition partially, so you may send just the keys you're changing.

## Workflow

```
1. studio_get_production_context({ projectId, episodeId })   → existing canonical names
2. segment the script into scenes (headings, transitions, time-of-day)
3. extract characters/locations/props → studio_register_reference_entities
4. design shots per scene — purpose, then size/angle/movement/lens, then duration
5. self-check against the repair criteria; fix rather than emitting "TBD"
6. studio_upsert_scene_packages({ scenes })                  → counts.scenes / counts.shots
7. → /mixio:continuity for the audit, then /mixio:chunking
```

## Notes

- Each shot should have a stated purpose — establish, reveal, react, transition, climax, tension, release. Not every scene needs an establishing shot; jump into action when the audience already knows the space, or when disorientation serves the tone.
- One shot with a `tracking` or `crane` move can legitimately cover several story beats. Longer takes suit climaxes.
- Verify `counts.shots` matches what you sent. A silent shortfall means shots were skipped by the per-item validator, not that the call failed.
- The managed path uses `gemini-3-flash-preview` with structured output and a repair pass. If your composed breakdown is thinner than that, use the managed path instead.
