# Canonical shot and scene schema

Read this when preparing or validating the Studio payload for an approved local shot plan. The write-through managed `script_breakdown` job bypasses the plan/diff review and is not the normal production path; see the main skill.

## Canonical shot metadata

Seven required fields. Persisting a shot without them throws `Shot metadata missing required field <name>` at the materialization gate.

| Key | Required | Notes |
|-----|----------|-------|
| `shot_type` | ✅ | vocabulary below (not validated — see note) — **framing only**, angles live on `camera_angle` |
| `camera_movement` | ✅ | vocabulary below (not validated — see note) |
| `camera_angle` | — | enum below; alias `angle` / `cameraAngle`. May be director-inferred from intent; omit when no useful choice is motivated |
| `lens` | — | enum below. May be director-inferred from the desired perspective; omit when no useful choice is motivated |
| `subject` | ✅ | primary subject; ≤1000 chars |
| `action` | ✅ | what happens in the shot; ≤2000 |
| `context` | ✅ | environment/surroundings; ≤2000 |
| `style_ambiance` | ✅ | visual style and palette; ≤2000 |
| `lighting` | — | key lighting setup and quality; ≤2000 |
| `mood` | — | emotional tone and atmosphere; ≤2000 |
| `blocking` | — | subject positioning and movement in frame; ≤2000. Alias `subjectPosition` |
| `duration` | ✅ | seconds, **continuous float 1–60** (typical 3–15) |
| `temporal_effect` | — | defaults `"normal"`; ≤256 |
| `audio` | — | `{ dialogue?, sfx?, ambient? }`. A bare string is coerced to `{ sfx }` |
| `character_links` | — | canonical **names**, not ids |
| `location_links` | — | canonical names |
| `prop_links` | — | canonical names |
| `linked_character_ids` | — | resolved element IDs in Cast & World |
| `linked_location_ids` | — | resolved element IDs in Cast & World |
| `linked_prop_ids` | — | resolved element IDs in Cast & World |

Every entity present in a shot must be linked — passing both canonical names (`character_links`, `location_links`, `prop_links`) and resolved element IDs (`linked_character_ids`, `linked_location_ids`, `linked_prop_ids`). That builds the relation graph `mixio-generate` later reads to pull reference images, and it carries per-shot `appearanceState`.

### Zero-Placeholder Rule
The 7 required fields must never be populated with empty or placeholder strings (`""`, `"TBD"`, `"tbd"`, `"n/a"`, `"na"`, `"unknown"`, `"none"`, `"null"`). Downstream renderers and prompt assemblers treat placeholders as blank frames or corrupt prompts. Every shot must carry concrete, authored cinematic direction.

### `shot_type` — framing only

```
wide  establishing  medium  close_up  extreme_close_up
pov  two_shot  over_shoulder  montage  abstract
```

`low_angle` and `high_angle` used to be in this list and have moved to `camera_angle`. Existing shots still hold them, and reads still resolve them, but new breakdowns should not emit them here.

Pick by story need, not formula:

- `wide` / `establishing` — geography, scale, isolation, new world
- `medium` — conversation, relationship, ordinary human interaction
- `close_up` — emotion, decision, internal conflict, detail
- `extreme_close_up` — obsession, micro-detail, time pressure
- `two_shot` — relationship dynamics, power balance, confrontation
- `over_shoulder` — subjective perspective, dialogue intimacy
- `pov` — immersion, vulnerability, discovery
- `montage` — time passage, parallel action, accumulation
- `abstract` — mood, theme, non-literal storytelling

In the local review table, separate **shot type** from **shot scale** and **composition**. Use standard scale terms such as extreme wide shot (EWS), wide shot (WS), medium-wide shot (MWS/MW), medium shot (MS), medium close-up (MCU), close-up (CU), and extreme close-up (ECU). Terms such as over-the-shoulder (OTS), two-shot, point-of-view (POV), insert, clean single, dirty single, and master describe composition, viewpoint, or coverage role rather than scale. Choose the closest supported `shot_type` value; keep additional scale/composition detail in the local plan and map it only to an existing field that accurately represents it. Do not add a `shot_scale` or `framing` metadata key.

### `camera_angle` — optional, own axis

```
eye_level  low_angle  high_angle  dutch_angle  birds_eye  worms_eye  overhead
```

`low_angle` for power, threat, heroism, scale · `high_angle` for vulnerability, surveillance, overview · `dutch_angle` for unease · `birds_eye`/`overhead` for geometry and detachment. Omit rather than guess — an unevidenced angle is worse than none.

### `lens` — optional

```
wide_angle  telephoto  macro  fisheye  anamorphic  tilt_shift  standard
```

`wide_angle` exaggerates depth and space, `telephoto` compresses and isolates, `macro` for insert detail. Same rule: omit without evidence.

### `camera_movement` — one of exactly these

```
static  dolly_in  dolly_out  pan_left  pan_right  tilt_up
tilt_down  tracking  crane  handheld  arc  rack_focus
```

Match the move to emotional intent: `static` for tension, contemplation, dialogue weight, formality · `tracking`/`dolly_*` for following action, revealing space, momentum · `crane` for geography, power shifts, emotional distance · `handheld` for urgency, chaos, documentary · `arc` for reveals and circling tension · `rack_focus` for shifting attention between dual subjects · `pan` for surveying and following gaze · `tilt` for scale and vertical discovery.

Use these terms accurately in the review table:

- `static` — locked-off camera; no camera travel or reframing.
- `dolly_in` / `dolly_out` — camera physically travels toward / away from the subject. “Push-in” and “pull-back” may describe the intent, but use the canonical value in the synced field.
- `tracking` — camera travels alongside, behind, ahead of, or across the subject. State the path and screen direction so it is reproducible.
- `pan_left` / `pan_right` — camera rotates horizontally from a fixed position; distinguish this from tracking laterally.
- `tilt_up` / `tilt_down` — camera rotates vertically from a fixed position; distinguish this from a crane move.
- `crane` — camera travels vertically or on a crane arm to reveal or change spatial relation; describe the path in the local plan.
- `arc` — camera travels around the subject; state direction and approximate arc when useful.
- `handheld` — camera support/feel, not a path by itself; describe any follow or pan separately if needed.
- `rack_focus` — focus shifts between depth planes; this is a focus pull, not physical camera movement.

If a proposed move or rig has no canonical value (for example, a zoom or pedestal), keep its exact term visible in the local plan and flag the field-mapping limitation in the Studio diff. Never disguise it as a different enum or create an unsupported key. Use the canonical movement value plus path, speed, and endpoint in the review cell; if those details cannot be preserved by existing fields and that loss changes the shot, hold sync for a decision.

### Shot direction language

| Aspect | Use | Do not confuse with |
|---|---|---|
| Camera angle | `eye_level`, `low_angle`, `high_angle`, `dutch_angle` (canted), `birds_eye`, `worms_eye`, `overhead` | Shot size or camera movement |
| Lens | `wide_angle`, `standard`, `telephoto`, `macro`, `fisheye`, `anamorphic`, `tilt_shift` | A focal-length number without a camera format/sensor basis |
| Mood | Specific emotional atmosphere such as `ominous`, `tender`, `playful`, `claustrophobic`, `clinical`, or `triumphant`; support it with performance, light, palette, framing, and/or sound | A camera move, genre label, or vague direction such as “cinematic” |
| Blocking and continuity | Positions, entrances/exits, screen direction, eyelines, axis, foreground/midground/background, and visible state changes | Camera travel; use movement vocabulary for camera motion |
| Editorial handoff | `match on action`, `eyeline match`, `graphic match`, `shot/reverse shot`, `cutaway`, `J-cut`, `L-cut`, or a motivated transition | A new script fact or a Studio shot field; keep it in the local Handoff note unless a supported field represents it |

Mood is free-text in the current schema, not a closed taxonomy. Choose a precise audience-facing tone, then name the visual or sound choices that create it. Mark an authored framing, camera, lens, or mood choice `INFERRED` when the source does not state it; script silence is not a reason to leave motivated direction unspecified.

All four vocabularies above (`shot_type`, `camera_angle`, `lens`, `camera_movement`) are authoring conventions, not validation — the fields are plain strings server-side and an off-vocabulary value persists without complaint. Stay inside them for auditability and because the direction compiler expects them, not because a write outside them will fail.

## Local review fields and Studio mapping

The shot table is more detailed than the Studio shot metadata schema. Sync only values that have a clear mapping to existing fields. Do not create a `director_note`, `labels`, `framing`, `shot_scale`, or `handoff` metadata key. Approved functional labels use the existing shot tags object as `tags.breakdownLabels` (an array of strings); preserve `episodeId`, `sceneId`, `shotNumber`, and every unrelated tag when updating it. Set `breakdownLabels: []` on an existing shot only when the approved diff explicitly clears its labels.

| Grammar field | Canonical key | Notes |
|---|---|---|
| supported shot type | `shot_type` | Select the closest value from the closed authoring vocabulary above |
| precise shot scale / composition | `blocking` only when it describes in-frame placement; otherwise local plan | No separate `shot_scale` field exists |
| `Proposed action` | `action` | Visible action, not the rationale or audience purpose |
| camera angle | `camera_angle` | Own axis; alias `angle` / `cameraAngle` |
| canonical camera move | `camera_movement` | Use exact authoring value; do not put path/speed into a new key |
| lens | `lens` | First-class field when supported; omit rather than invent technical specs |
| camera placement / in-frame `FG`/`MG`/`BG` layering | `blocking` when it describes subject/camera relation in the frame; otherwise local plan | Canonical blocking; alias `subjectPosition` |
| `Lighting` | `lighting` | Canonical |
| mood / atmosphere | `mood` and/or `style_ambiance` | Use mood for emotional tone; use style/ambiance for the overall visual treatment |
| `Dialogue` / `Audio` | `audio.dialogue` / `.sfx` / `.ambient` | Dialogue from cues; SFX from `[SFX: ...]`; Ambient from `[Ambient: ...]` |
| functional Labels | shot `tags.breakdownLabels` | Existing tags object; merge after approval and read back |
| `Director’s note`, source-beat citation/provenance, Handoff | local review plan | Do not persist as passthrough or invented metadata |
| rhythm/pacing cue | local review plan | No canonical shot-pacing field; `duration` and visible `action` carry timing into existing checks |
| per-character wardrobe/hair/condition/held props | `appearanceState` on the `appears_in` relation | see below |
| scene anchor | scene `anchorRef` / `anchorRefs` | auto-attached to every shot in the scene |
| `Handoff` / cut timing | local review plan; include a motivated action only in `action` when it is visible on screen | No dedicated per-shot transition field |
| duration | `duration` | Seconds as a continuous 1–60 float |
| `[M1]`/`[M2]` markers | inline in `action` | skill-local |

`camera_angle`, `lens`, `lighting`, `mood`, and `blocking` may be passthrough on an older Studio version. A permissive write is not proof that a field is recognized: verify the saved field by reading it back. If it lands only in passthrough, report that limitation in the exact diff and do not claim the technical direction was persisted as a canonical field.

### Passthrough is visible — and permissive

Non-spec keys still persist verbatim, and **when the Tier 2 prompt materializer runs**, they reach the generation prompt under `- Additional direction:` (a denylist, not an allowlist). That's not every job: the materializer is skipped — and the gathered element is never woven into the prompt at all — for `promptEnhancementMode: "off"` or `"enhance_and_review"` (the user asked to ship their prompt untouched), for `image-edit`/TTS/voice-change use cases (bypassed before context gathering even starts), and for video-direction requests that are promptless, carry a structured prompt, or hit a disabled/unknown model profile. Only the default `"enhance"` mode, on a use case that isn't one of those bypasses, actually stitches passthrough into what the model sees. Either way, treat a passthrough key as something that *might* become prompt text — write it deliberately or not at all, and don't assume it silently vanished just because a test job didn't show it (check `promptEnhancementMode` first).

The write boundary does not reject an unrecognized or confusable key — it either remaps it or warns and lets it through, but it never throws for this:

1. a casing or separator variant of a key in the *same* spec — `styleambiance`, `Style_Ambiance` — is silently remapped onto the canonical key.
2. a canonical key belonging to the *other* spec — `timeOfDay` on a shot, `shot_type` on a scene — logs a non-fatal warning and still lands in passthrough. `location`, `duration`, and `audio` are exempt even from the warning, being in genuine dual use.

A `ShotSpecValidationError` is thrown only for a *recognized* canonical field holding a malformed value — never for a key it doesn't recognize.

Practical consequence: **write `anchorRef` on the scene, not `anchor_ref`** — not because the latter throws (it doesn't; it becomes an inert passthrough key that never attaches the anchor), but because `anchorRef` is the field generation actually reads. The real risk isn't an error, it's silence: a mistyped correction persists and reads back fine, so nothing tells you it didn't take effect. Write a value back and read it if you need to confirm which key it landed under.

### Passthrough has silent caps

Passthrough isn't unbounded, and none of these limits produce an error, a warning, or a log line — a value or key just quietly stops showing up in the prompt:

- Each passthrough value truncates at **400 characters**.
- Past **20** passthrough keys on one element, the survivors are chosen **alphabetically** (`sorted(extras)[:20]`), not by importance or recency — a 21st key you actually care about can lose to one you don't, purely on spelling.
- The whole per-element passthrough block truncates at **2400 characters** even if every individual value is under the 400-char cap.

Precondition, precisely: element context (episode/scene/shot) is fetched and these three caps are applied whenever the job carries an `episodeId`/`sceneId`/`shotId`, full stop — that part doesn't depend on mode. What's conditional is whether the *capped result* ever reaches the model. It's discarded, not capped-and-sent, on the same three bypass paths as above: `promptEnhancementMode: "off"`/`"enhance_and_review"`, the two literal-content use cases (never even gathered there), and a promptless/structured/disabled-profile video-direction route. So on those paths the caps are moot — not because they're skipped, but because nothing downstream of them ships. Only under `"enhance"` (default), outside those bypasses, do the caps actually shape what the model reads.

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
| `anchorRef` | primary continuity anchor for the scene — element id or media URL |
| `anchorRefs` | additional anchors, max 50 |

`anchorRef` is the payoff of the sheets step: generation auto-attaches it to **every** shot in the scene, so the caller never restates it per shot. Anchors dedupe by slot reference id, an explicit per-shot selection still wins, and an anchor whose media can't be read is skipped rather than guessed at — a stale id cannot inject a broken reference into a paid job.

Scene keys are **camelCase**; shot keys are **snake_case**. Not a typo in this doc — that's the actual contract, and mixing them up sends your field to the passthrough partition where nothing reads it.

Scene `status`: `scripting` (default) → `breakdown` → `approved`.

## Appearance state schema

Attached to `appears_in` relations via `studio_link_graph` for each character appearing in a shot:

The breakdown audit requires `wardrobe`, `condition`, and `carriedProps` for every appearing
character. `carriedProps` is an explicit array and must be `[]` when the character carries
nothing; `hairState`, `emotionalState`, `lookRef`, and `continuityNotes` remain optional.

| Key | Type | Description |
|---|---|---|
| `wardrobe` | string | Clothing/outfit description specific to this shot |
| `hairState` | string | Hair style, state (e.g. wet, tied back, disheveled) |
| `condition` | string | Physical condition (e.g. sweating, bruised, pristine) |
| `carriedProps` | string[] | Array of canonical prop names held or carried in this shot |
| `emotionalState` | string | Performance and emotional direction for the character |
| `lookRef` | string | Variant name or ID from Cast & World reference |
| `continuityNotes` | string | Granular continuity cues (e.g. prop in left hand) |

## Relational audit specification

Run immediately after breakdown persistence and graph linking. The audit reads persisted shots
and relations, verifies the seven canonical fields, Cast & World IDs, appearance state, and the
deterministic screenplay-beat count/duration. Its one authoritative procedure and
`metadata.pipeline.breakdown_audit` payload are in
[persistence-and-audit.md](persistence-and-audit.md); do not recreate that schema here.
