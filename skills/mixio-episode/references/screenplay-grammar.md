# Native Screenplay Grammar

This is the canonical contract for text stored by `studio_upsert_screenplay`. The episode `script` is the raw Idea/Story source; the `SCREENPLAY` is the director-developed, AI-readable production document that Studio segments and breaks down. The screenplay should turn the source into a coherent sequence with playable action, visual direction, continuity, and motivated coverage. The companion [shot grammar](../../mixio-pipeline/references/shot-grammar.md) defines the structured director plan and breakdown fields; it does not replace screenplay prose.

## Scope and precedence

- A `SCREENPLAY` element is one per episode. A non-empty `body` wins for breakdown, even while its Studio status is `draft`.
- The episode `script` / `metadata.fullScript` is raw **Idea/Story** fallback text. Use it only when no screenplay has a usable body.
- `studio_upsert_screenplay` creates or updates the draft. A human approves separately in the Studio Screenplay view.
- Preserve the approved screenplay body verbatim when passing it to breakdown: native mentions, locks, annotations, line ordering, and source language are all part of the production source record. The raw episode script remains unchanged as the underlying story source.

## Base screenplay form

Every scene must include four core components: **sluglines**, **action beats**, **character cues/dialogue**, and **audio/SFX design blocks**:

```text
INT. ARCHIVE HALL — NIGHT

[Ambient: low electrical hum of server racks · Lighting: cold fluorescent and green practicals]

The heavy VAULT DOOR stands ajar. #maya.wedding.front crosses the tiled floor to the OAK DESK beside ~archive-hall.service-counter.left.

[Shot Type: medium · Camera Movement: dolly in · Camera: eye level]

MAYA
(whispering)
Keep the doors locked.

[SFX: metallic click of deadbolt locking into steel frame]

She retrieves the MANILA DOSSIER from the center DRAWER.
```

- **Slugline**: `INT.`, `EXT.`, `INT/EXT.`, `I/E`, or `EST`, optionally preceded by a scene number; then the location and time of day.
- **Action beats**: ordinary prose paragraphs describing physical action, setting the scene, and staging characters. Reference tokens and locks can appear inside it.
- **ALL CAPS Prop & Setting Rule**: Key props (`VAULT DOOR`, `OAK DESK`, `MANILA DOSSIER`, `DRAWER`) and prominent setting elements (`WINDOW`, `BALCONY`, `SERVICE COUNTER`) MUST be capitalized in `ALL CAPS` on first appearance. These tokens help Step 01 identify entities for the local shot plan and help Step 02 trace prop continuity.
- **Character cue and dialogue**: ordinary screenplay cue, optional parenthetical, and dialogue paragraphs. Preserved verbatim in source language and alphabet.
- **Audio & SFX paragraphs**: standalone design blocks (e.g. `[SFX: ...]` and `[Ambient: ...]`) or descriptive audio paragraphs providing deterministic cues for sound design and foley during breakdown.
- **Blank lines** separate paragraphs. A native annotation must occupy its own complete paragraph; ordinary bracketed prose remains ordinary prose.

## Director-led screenplay development

When given a high-level script, outline, or incomplete screenplay for production, develop it into an AI-ready screenplay before breakdown. Make the scene chain, action causes, staging, entrances/exits, geography, visual reveals, reactions, transitions, and material continuity explicit. Add establishing, reaction, insert, or connecting beats when they help the audience understand the action or connect adjacent moments. Treat these as director inferences, not new source facts.

Keep a local change map from source beats to screenplay beats. Mark additions `INFERRED`; preserve source facts and dialogue; hold any consequential change to story, motive, or dialogue as `OPEN DECISION`. The labels belong in the review artifact and are not native screenplay tokens. Review the full proposed screenplay and change map before `studio_upsert_screenplay`; after approval, read back the saved draft. A saved draft still needs human Studio approval before it becomes the production baseline.

Write technical direction into screenplay action and supported `[Key: Value]` annotations. The parser recognizes only the keys listed below; unsupported details must remain clear prose or be captured in the companion director plan and structured shot breakdown. Do not imply that arbitrary annotations become structured Studio metadata.

## Native reference mentions: `#`

```text
#root
#root.look
#root.look.view
#char-a3f9c2e1
```

The parser recognizes a `#` followed by **one to three** dot-separated segments. A segment starts with a Unicode letter or number and may continue with letters, numbers, or hyphens. The native resolver accepts both canonical reference codes and human aliases.

### Authoring rule

For Cast & World references, do not synthesize any of those segments. First call:

```text
studio_list_references({ projectId, limit })
```

Then copy the exact `mentionableLooks[].mention` or `mentionableLooks[].views[].mention` response value. A display name with spaces is one hyphenated root segment, not several dot segments. For example, if Studio returns `#verify-hero.wedding.front`, use that exact form—never `#verify.hero.wedding.front`.

A look with no distinct `views` correctly uses its two-segment `#root.look` mention. For a CHARACTER, the look identifies a script-required age/clothing variant and an optional third segment can identify a sheet view. For a LOCATION, the look identifies a scenario-required configuration (such as exterior or living room), and a third segment identifies a camera-view image within that configuration. `#root` and canonical `#char-…` forms are syntactically valid, but `mentionableLooks` is the authoritative safe form for a particular visual look; copy its exact value and do not hand-build tokens for variants/views that are not yet registered.

`#` is deliberately separate from `@`: `@` is reserved for Studio's structured prompt mentions such as `@[Label](type:id)` (code-level structured wire format, e.g. `@[Tony](character:char_123)`). An unresolved `#` mention fails soft and remains literal text, so a typo does not stop breakdown; it also does not bind a reference. Treat an unresolved token as an error to fix, not as a fallback.

### Mention Validation Taxonomy & Quality Gate

Every `#` token in the screenplay body must be validated against project references. Probing via `studio_resolve_mention({ projectId, mention })` returns `{ resolved, element?, variantId?, reason? }` and never throws on an unresolved mention. The `reason` string categorizes the four diagnosis states:

Before remediating an unresolved entity or look, read `settings.references` with
`studio_get_project`. Honor its `createPolicy` and `variantPolicy`; route the write through
`mixio-references` when a policy needs interpretation.

| Status / Reason | Meaning | Remediation |
|---|---|---|
| `RESOLVED` | Entity and look variant successfully resolved. | None needed. Ready for breakdown. |
| `UNRESOLVED_ENTITY`<br>(`no element named "..." in this project`) | The character/location/prop element does not exist in Cast & World. | After the reference-policy check, register the entity via `studio_register_reference_entities`, then generate its look sheet. |
| `UNRESOLVED_LOOK`<br>(`no look named "..." on element "..."`) | Entity exists, but the specific variant/configuration or view does not. | For local planning, preserve the source mention and record the missing row as a Step 04 readiness gap. Build it through `mixio-sheets` after the breakdown is accepted, subject to reference policy. If authoring screenplay text, use the exact new `mentionableLooks` token only after its image is approved. Otherwise correct a confirmed typo. **Never create a second duplicate character, hand-build a token, or create one location per camera angle.** |
| `AMBIGUOUS`<br>(`ambiguous: 2 elements named "..." in this project`) | Two references collapse to one mention root slug. | Deduplicate or rename the conflicting reference element in Cast & World. |

Script-required variants/views may be ordinary prose and provisional Step 04 inventory rows
before their images are registered; do not invent `#` tokens for them. When authoring new
screenplay text, convert an unresolved token to an existing canonical mention plus descriptive
prose, or defer adding the exact variant/view token until Step 04 has produced an approved image
and `mentionableLooks` value. During the local shot plan, preserve existing source text verbatim
and report unresolved mentions as reference-readiness gaps; do not rewrite the screenplay to
make planning pass. Unresolved mentions fail soft on write but do not bind references downstream.

## Native continuity locks: `~`

```text
~location.landmark
~location.landmark.placement
```

A lock has exactly two required segments—location and landmark—and an optional third placement segment. Segments use the same Unicode letter/number/hyphen rules as mention segments. Examples:

```text
~archive-hall.service-counter
~archive-hall.service-counter.left
```

Locks are advisory spatial continuity cues. They are **not** entity lookups and are never substitutes for a `#` reference mention. Reuse the same spelling for the same point; Studio normalizes equivalent casing/spacing to a slugged lock key. A bare `~location` is malformed and carries no lock.

## Native shot-intent annotations: standalone `[Key: Value]`

```text
[Shot Type: wide · Camera Movement: dolly in · Lighting: cold blue practicals]
```

An annotation is a single, standalone paragraph whose full trimmed line is bracketed. It can contain one or more key/value pairs separated by `·` (interpunct) or `,` (comma). It MUST immediately precede the dramatic beat it governs.

Its 11 recognized keys are case-sensitive and exact:

| Label | Breakdown destination (`ShotMetadata`) | Purpose / Override behavior |
|---|---|---|
| `Camera` | `camera_angle` | Camera angle/elevation only (e.g. `low angle`, `60° high angle`). Use `Shot Type` for framing size and `Camera Movement` for motion. |
| `Camera Movement` | `camera_movement` | Camera move (e.g. `dolly in`, `tracking`, `pan left`, `static`) |
| `Lighting` | `lighting` | Key lighting setup and atmosphere (e.g. `cold blue practicals`, `as Anchor 1`) |
| `Mood` | `mood` | Emotional atmosphere of the frame (e.g. `tense`, `intimate`, `claustrophobic`) |
| `Blocking` | `blocking` | In-frame spatial layering (e.g. `FG → MAYA; MG → OAK DESK; BG → VAULT DOOR`) |
| `Background` | `context` | Specific background action or environment features (e.g. `rain pelting glass`); merge it into the shot's canonical environment context. |
| `Location` | `location_links` | Target location; supports exact `#location.configuration[.view]` mention, copied from `mentionableLooks` |
| `Shot Type` | `shot_type` | Framing size (e.g. `close_up`, `wide`, `over_shoulder`, `two_shot`) |
| `SFX` | `audio.sfx` | Concrete sound effects / foley cues (e.g. `heavy steel door latch click`) |
| `Ambient` | `audio.ambient` | Environmental soundscape / room tone (e.g. `low hum of server fans`) |
| `Lens` | `lens` | Focal length / lens type (e.g. `anamorphic`, `wide_angle`, `telephoto`) |

### Parsing and Override Rules

1. **Preceding Placement**: Place the annotation immediately before the beat it governs. Breakdown assigns the asserted values to the shot(s) derived from that beat.
2. **Verbatim Override**: Breakdown preserves a recognized value verbatim and uses it instead of inferring that field.
3. **Standalone Line Requirement**: An annotation must occupy its own separate paragraph. Inline brackets (e.g. `She whispers [Camera: close_up]`) remain plain action prose. Bare bracketed parentheticals (e.g. `(whispers)`) remain actor direction and are never parsed as annotations.
4. **Duplicate Keys**: If the same recognized label appears more than once in a single line (`[Camera: wide · Camera: close]`), Studio records it as a duplicate and the later value wins.
5. **Empty Values**: A recognized label with an empty value (`[Camera: ]`) is malformed and ignored — never sent to breakdown as an empty override.
6. **Unrecognized Keys**: Keys outside the 11 recognized labels (e.g. `[Vibe: moody]`) are surfaced as advisory notes in Studio's advisory panel and do not fail the parse for recognized sibling keys.

## Deterministic scene segmentation

Scene grammar is not a second free-form language. Studio deterministically segments the screenplay around these cues, while keeping the original text as the scene record:

- **Headings**: optional scene number, then `INT`, `EXT`, `INT/EXT`, `I/E`, or `EST`, with optional period.
- **Time-of-day cues**: `DAY`, `NIGHT`, `DAWN`, `DUSK`, `MORNING`, `EVENING`, `LATER`, `CONTINUOUS`, `SUNSET`, `SUNRISE`, `SAME`.
- **Transitions**: `CUT TO`, `SMASH CUT TO`, `MATCH CUT TO`, `DISSOLVE TO`, `FADE TO`, `JUMP CUT TO`, `WIPE TO`, `INTERCUT [TO]`, `BACK TO`, `CONTINUED`, `HARD CUT TO`.
- **Continuations**: `CONTINUED`, `INTERCUT`, `INTERCUT TO`, and `BACK TO` mark `isContinuation: true`.

Breakdown derives scene `heading`, `location`, `timeOfDay`, `transitionFromPrevious`, `isContinuation`, and the verbatim scene body from these cues. Do not manually rewrite those fields to disagree with the screenplay parser.

## What is not screenplay grammar

| Concern | Canonical contract |
|---|---|
| Shot coverage, `FG`/`MG`/`BG`, `[M1]`, anchor references, pacing, and audit taxonomy | Authored [shot grammar](../../mixio-pipeline/references/shot-grammar.md), then canonical shot metadata. These are breakdown outputs, not native screenplay tokens. |
| Scene/shot storage | `upsert_scene_packages` canonical schema; see `mixio-script-breakdown/references/canonical-schema.md`. |
| Generation prompt syntax | There is **no independent native prompt grammar**. Call `get_use_case_input_schema` for the selected model/use case and supply references through `input.media`, `selectedElements`, and optionally slot bindings. A `#` token can be resolved in a compatible text prompt, but it never replaces the required generation input schema or media references. |

## Authoring checklist

1. **Mention Catalog**: Call `studio_list_references({ projectId, limit })` and copy exact `mentionableLooks` for every existing entity/look you intend to bind. Validate all `#` mentions (0 unresolved tokens); describe unregistered looks in prose and record the readiness gap.
2. **Four Scene Elements**: Every scene must contain sluglines, action beats, character cues/dialogue, and audio/SFX paragraphs (`[SFX: ...]`, `[Ambient: ...]`).
3. **Connected Direction**: Make cause and effect, geography, character/prop state, transitions, and motivated establishing/reaction/connecting beats legible across the sequence.
4. **ALL CAPS Props & Settings**: Capitalize every key prop and notable setting element on first appearance.
5. **Standalone Annotations**: Place standalone `[Key: Value · Key: Value]` override blocks immediately before the beats they govern. Only recognized keys are parsed into structured overrides.
6. **Spatial Locks**: Use `~location.landmark[.placement]` for advisory spatial continuity locks; never as an entity mention.
7. **Review and Draft Upsert**: Show the developed screenplay and source-to-screenplay change map; wait for approval; upsert the full approved body as a draft via `studio_upsert_screenplay`, read it back, then preserve it verbatim through breakdown.
