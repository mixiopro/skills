# Shot Grammar

The shared vocabulary for `mixio-pipeline`, `mixio-sheets`, `mixio-continuity`, and `mixio-shot-planning`. Its only job is to make a breakdown **auditable**: fixed field names and a closed value set mean a continuity pass can diff shot N against shot N+1 mechanically instead of interpreting prose.

## Naming

- **Set elements and props in CAPS on every mention** — `BED`, `BEDSIDE TABLE`, `NAPOLI POSTER`, `CEREAL BOWL`. Consistent CAPS tokens are what makes prop continuity greppable across 40 shots.
- **Characters in CAPS** — `TONY`, `POPPY`.
- **Anchors numbered per scene** — `Anchor 1`, `Anchor 2`.
- Sluglines: `INT./EXT. — LOCATION — TIME`.

## Position vocabulary — two independent axes

Never collapse these; a shot needs both.

**Depth** (distance from lens): `FG` foreground · `MG` midground · `BG` background

**Screen zone** (position in frame): `MC` mid-center · `FL` frame-left · `FR` frame-right · `BL` back-left · `BR` back-right

**Facing** (closed set): `toward-camera` · `away` · `three-quarter-left` · `three-quarter-right` · `profile-left` · `profile-right`

**Posture**: free text but must be *specific*. `seated` is a vague field and will be flagged by the audit; `seated cross-legged` is fine.

**Relative to**: anchor the character to a named CAPS set element — `on BED, beside BEDSIDE TABLE`, `at BED FRAME edge`, `off-screen (hallway)`. Absolute coordinates drift between shots; relations don't.

## Shot sizes

`EWS` extreme wide · `WS` wide · `MW` medium-wide · `MS` medium · `MCU` medium close-up · `CU` close-up · `ECU`/`Insert` extreme close-up or screen insert · `OTS` over-the-shoulder · `POV`

Hyphenate a move that changes size mid-shot: `EWS→WS`.

## Movement markers

Beats inside a shot that other shots depend on get a marker, in order: `[M1]`, `[M2]`, `[M3]`.

```
Shot 4 — POPPY [M1] enters through HALLWAY DOORWAY, crosses to BED FRAME edge
Shot 7 — TONY [M2] reaches with right hand to take the tablet from POPPY
Shot 8 — tablet already with TONY (after [M2]); POPPY's hand rests on BED FRAME edge
```

Markers make state transfer explicit. Without them, shot 8 has to re-describe shot 7's action and the two descriptions drift.

## Shot direction fields

The user-visible breakdown is the structured table in `mixio-script-breakdown`. Keep these decisions in distinct fields; the table is a review plan, so its craft detail can be richer than the current Studio schema.

| Field | Put here | Example |
|---|---|---|
| Director’s note | Why the image matters: audience knowledge, feeling, anticipation, or point of view | Hold the audience on TONY’s uncertainty before the handoff |
| Proposed action | Observable action in the frame, using specific verbs and state changes | TONY sets down her phone, then takes the tablet from POPPY |
| Framing | Canonical `shot_type`, then shot scale and composition as helpful | `over_shoulder`; MCU; TONY’s shoulder FG, tablet MG, POPPY BG |
| Camera | Angle, canonical move, lens if motivated, and camera position/path/speed/endpoint where useful | `eye_level`; `dolly_in` 0.5 m toward the tablet; `standard`; behind TONY’s right shoulder |
| Blocking / continuity | FG/MG/BG, screen zone, facing, posture, axis, eyeline, and entry → exit state | TONY’s shoulder holds frame-left; POPPY faces frame-left toward her |
| Look / sound / rhythm / duration | Mood, lighting, palette, dialogue/SFX/ambience, optional pacing cue, and seconds | Intimate, warm window light; apartment tone; slow cadence; 4.5 s |
| Handoff | The motivated cut or transition to the next shot | Cut on TONY’s eyes lifting to POPPY; eyeline match to Shot 8 |

Example camera cell: `angle: eye_level; move: dolly_in, 0.5 m toward the tablet; lens: standard; position: behind TONY’s right shoulder`. Use the exact supported vocabulary below as the machine-facing value, then add a clear path or intent. “Slow push-in” alone is ambiguous: a dolly moves the camera through space; a zoom changes focal length. Keep camera movement separate from actor blocking. `rack_focus` changes the focus plane and is not physical camera travel.

Use standard scale names—extreme wide shot (EWS), wide shot (WS), medium-wide shot (MWS/MW), medium shot (MS), medium close-up (MCU), close-up (CU), extreme close-up (ECU)—and standard composition terms such as over-the-shoulder (OTS), two-shot, point-of-view (POV), insert, clean/dirty single, and master. Map to the closest supported `shot_type`; precise scale or composition detail remains local unless an existing field represents it. Do not encode shot size as camera angle.

Angles use `eye_level`, `low_angle`, `high_angle`, `dutch_angle` (canted), `birds_eye`, `worms_eye`, or `overhead`. Lens choices use `wide_angle`, `standard`, `telephoto`, `macro`, `fisheye`, `anamorphic`, or `tilt_shift`; never invent a focal-length number without a camera format/sensor basis.

Camera moves use exactly `static`, `dolly_in`, `dolly_out`, `pan_left`, `pan_right`, `tilt_up`, `tilt_down`, `tracking`, `crane`, `handheld`, `arc`, or `rack_focus`. A pan/tilt rotates from a position; a dolly/tracking/crane/arc travels through space. State direction and path for travel; state direction for a pan/tilt. `handheld` describes support/feel, not a path. If a motivated move such as zoom or pedestal lacks a supported value, preserve its term in the local plan and flag the mapping limitation in the approval diff.

Use mood words for emotional atmosphere and name what creates that effect—performance, light, palette, framing, or sound. Optional rhythm cues can be `HOOK`, `RAPID`, `PUNCHY`, `NORMAL`, or `SLOW`; they stay in the local plan because Studio has no canonical shot-pacing field. Duration and visible action remain the syncable evidence for timing and feasibility. Use editing terms such as match on action, eyeline match, graphic match, J-cut, and L-cut in Handoff, not as invented shot metadata. Functional labels are distinct from provenance and sync after approval through the existing shot tag `breakdownLabels`; source provenance and the Director’s note remain local review fields.

`lighting: as Anchor N` is the default only when that anchor exists and supports the shot. State and justify any motivated deviation. `duration` is in seconds; Studio accepts a continuous float from 1–60. The exact canonical field mapping and review-only fields are in [canonical-schema.md](../../mixio-script-breakdown/references/canonical-schema.md).

## Scene staging block

Emitted once per scene, before its shots. It is the "frame 0" state the audit's blocking map starts from.

```
STAGING — Scene 01
  Slugline:      INT. — TONY & POPPY'S BROOKLYN APARTMENT — DAY
  Location ref:  TONY & POPPY'S BROOKLYN APARTMENT = Image 3 + Image 4
  Anchor:        Anchor 1 — scene-start staging [master → apartment long axis]
  Time + light:  Day; warm sunlight through the two WINDOWS, long diagonal shafts
                 across the BED and PERSIAN RUG. BEDSIDE TABLE lamp off.
  Coverage:      Shots 1–10 → Anchor 1
  Characters at start:
    TONY:   Position on the BED against the right wall, near the BEDSIDE TABLE /
            Facing down toward the phone in her hands / Posture cross-legged, seated
    POPPY:  Position off-screen, hallway beyond the HALLWAY DOORWAY /
            Facing N/A / Posture N/A (enters at [M1])
```

## Location sheet fields

See `mixio-sheets`. Six fields, always in this order: `Layout` · `Entries & exits` · `Key elements` · `Depth & axes` · `Light sources` · `Surfaces & palette`.

## Grounding modes

- **GROUNDED** — an anchor image exists for the scene. Blocking is checked against real pixels; the audit can catch a shot that contradicts the set.
- **TEXT-ONLY** — no reference image. Everything is grounded in script text only. Mark the scene `TEXT-ONLY` in its staging block and say so in the audit report, because "no anchor mismatches found" means nothing without an anchor.

## Continuity issue taxonomy

The closed set of things the audit reports. Anything that isn't one of these isn't a continuity issue — it's a note.

| Code | Means |
|------|-------|
| `PROP` | An object appears, vanishes, or changes hands with no stated action causing it |
| `PRESENCE` | A character is present/absent inconsistently, or absent without leaving frame |
| `FACING` | Facing changes with no stated turn (and no camera reposition explaining it) |
| `POSTURE` | Posture changes with no stated movement |
| `WARDROBE` | Clothing/accessory changes mid-scene with no costume beat |
| `GAP` | A required field is missing entirely |
| `VAGUE` | A field is present but underspecified (`seated`, `nearby`, `some light`) |
| `ANCHOR` | Staging contradicts the scene's anchor frame (GROUNDED mode only) |
| `AUDIO` | Room tone / ambient audio contradicts established scene tone without cause, or SFX lacks matching action |
| `REF_MISSING` | A linked character/location/prop has no corresponding reference element in the project |
| `REF_NO_IMAGE` | A linked reference element exists but has no attached media — generation will lack visual consistency |

Report format is one line per issue: `Shot 7 | TONY | PROP — phone disappears with no stated put-down action`.
