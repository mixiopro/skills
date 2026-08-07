# Canonical shot and scene schema

Read this when authoring or validating shot/scene metadata by hand (the composed path). The managed path (one `studio_submit_studio_job` call) doesn't need you to know this — Studio's own workflow applies it.

## Canonical shot metadata

Seven required fields. Persisting a shot without them throws `Shot metadata missing required field <name>` at the materialization gate.

| Key | Required | Notes |
|-----|----------|-------|
| `shot_type` | ✅ | vocabulary below (not validated — see note) — **framing only**, angles live on `camera_angle` |
| `camera_movement` | ✅ | vocabulary below (not validated — see note) |
| `camera_angle` | — | enum below; alias `angle` / `cameraAngle`. Omit when the script gives no angle evidence |
| `lens` | — | enum below. Omit when the script gives no lens evidence |
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
| `linked_character_ids` | — | resolved element ids, if you already have them |
| `linked_location_ids` | — | ” |
| `linked_prop_ids` | — | ” |

Every entity present in a shot must be linked — that's what builds the relation graph `mixio-generate` later reads to pull reference images, and it's what carries per-shot `appearanceState`.

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

All four vocabularies above (`shot_type`, `camera_angle`, `lens`, `camera_movement`) are authoring conventions, not validation — the fields are plain strings server-side and an off-vocabulary value persists without complaint. Stay inside them for auditability and because the direction compiler expects them, not because a write outside them will fail.

## Where the fine-grained camera detail goes

The shot-grammar fields map **1:1 onto canonical keys** — camera detail no longer degrades into prose. (On an older Studio, `camera_angle`, `lens`, `lighting`, `mood` and `blocking` aren't recognized as canonical fields yet — they aren't rejected, they land in passthrough same as any other unrecognized key. Write and read one back to see which behavior your Studio has.)

| Grammar field | Canonical key | Notes |
|---|---|---|
| shot size (`EWS`, `MCU`, `OTS`) | `shot_type` | framing **only** — the enum no longer carries angles |
| camera angle (low/high/eye) | `camera_angle` | own axis; alias `angle` / `cameraAngle` |
| camera motion | `camera_movement` | vocabulary, not validated |
| lens (wide/normal/tele) | `lens` | first-class field |
| `Lighting: as Anchor N` | `lighting` | canonical |
| mood/atmosphere | `mood` | canonical |
| in-frame `FG`/`MG`/`BG` layering | `blocking` | canonical; alias `subjectPosition` |
| `Dialogue` / `Audio` | `audio.dialogue` / `.sfx` / `.ambient` | |
| per-character wardrobe/hair/condition/held props | `appearanceState` on the `appears_in` relation | see below |
| scene anchor | scene `anchorRef` / `anchorRefs` | auto-attached to every shot in the scene |
| `Cut:` hold + outgoing cut | `action` prose, or `temporal_effect` | no dedicated field |
| `Pacing` (RAPID/PUNCHY) | passthrough `pacing` | skill-local |
| `[M1]`/`[M2]` markers | inline in `action` | skill-local |

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
