# Native Screenplay Grammar

This is the canonical contract for text stored by `studio_upsert_screenplay`. It is **not** the authored [shot grammar](../../mixio-pipeline/references/shot-grammar.md): screenplay is the source text that Studio segments and breaks down; shot grammar is the reviewable production format created after breakdown.

## Scope and precedence

- A `SCREENPLAY` element is one per episode. A non-empty `body` wins for breakdown, even while its Studio status is `draft`.
- The episode `script` / `metadata.fullScript` is raw **Idea/Story** fallback text. Use it only when no screenplay has a usable body.
- `studio_upsert_screenplay` creates or updates the draft. A human approves separately in the Studio Screenplay view.
- Preserve the body verbatim when passing it to breakdown: native mentions, locks, annotations, line ordering, and source language are all part of the source record.

## Base screenplay form

Use standard screenplay paragraphs:

```text
INT. ARCHIVE HALL — NIGHT

#maya.wedding.front crosses to the desk beside ~archive-hall.service-counter.left.

[Camera: medium · Camera Movement: dolly in · Lighting: green practicals]

MAYA
Keep the doors locked.
```

- **Slugline**: `INT.`, `EXT.`, `INT/EXT.`, `I/E`, or `EST`, optionally preceded by a scene number; then the location and time of day.
- **Action**: ordinary prose paragraph. Reference tokens and locks can appear inside it.
- **Character cue and dialogue**: ordinary screenplay cue and dialogue paragraphs. They are preserved as source dialogue, not converted or translated.
- **Blank lines** separate paragraphs. A native annotation must occupy its own complete paragraph; ordinary bracketed prose remains ordinary prose.

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

A look with no distinct `views` correctly uses its two-segment `#root.look` mention. `#root` and canonical `#char-…` forms are syntactically valid, but `mentionableLooks` is the authoritative safe form for a particular visual look.

`#` is deliberately separate from `@`: `@` is reserved for Studio's structured prompt mentions such as `@[Label](character:id)`. An unresolved `#` mention fails soft and remains literal text, so a typo does not stop breakdown; it also does not bind a reference. Treat an unresolved token as an error to fix, not as a fallback.

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
[Camera: wide · Camera Movement: dolly in · Lighting: cold blue practicals]
```

An annotation is a single, standalone paragraph whose full trimmed line is bracketed. It can contain one or more key/value pairs separated by `·` or commas. Its recognized keys are case-sensitive and exact:

| Label | Breakdown destination |
|---|---|
| `Camera` | camera direction / framing evidence |
| `Camera Movement` | camera movement |
| `Lighting` | lighting |
| `Mood` | mood |
| `Blocking` | blocking |
| `Background` | background direction |
| `Location` | location direction; use an exact `#` mention when referring to a known location |
| `Shot Type` | framing / shot type |
| `SFX` | `audio.sfx` |
| `Ambient` | `audio.ambient` |
| `Lens` | lens |

Place the annotation immediately before the beat it governs. Breakdown preserves a recognized value verbatim and uses it instead of inferring that field. Do not put annotations mid-sentence: `She whispers [Camera: close_up]` is plain action, not an override. Do not use a bare bracketed aside such as `[whispers]` as an annotation.

A recognized label with an empty value is malformed. If the same recognized label appears more than once, Studio records it as a duplicate and the later value replaces the earlier one; author each key once. Unknown labels are not native direction keys—keep unsupported production notes in ordinary prose or in the later authored shot grammar.

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

1. List project references and copy exact `mentionableLooks` for every existing entity/look you intend to bind.
2. Write sluglines, action, cues, and dialogue normally; keep source language and line order.
3. Use `#` for entity/look binding and `~` only for spatial locks.
4. Put explicit direction in a standalone recognized annotation paragraph; otherwise let breakdown infer it.
5. Upsert the full body as a draft, then preserve it verbatim through breakdown.
