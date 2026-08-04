# Shot Grammar

The shared vocabulary for `mixio-pipeline`, `mixio-sheets`, `mixio-continuity`, and `mixio-chunking`. Its only job is to make a breakdown **auditable**: fixed field names and a closed value set mean a continuity pass can diff shot N against shot N+1 mechanically instead of interpreting prose.

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

## Shot spec fields

Every shot, in this order. Omit nothing; write `—` for genuinely empty.

```
Shot 7 — 4.5s [M2]
  Camera:            OTS (over TONY's shoulder) / slow push-in / normal lens —
                     placed behind TONY on the BED, shooting past her right shoulder
                     onto the tablet screen — In frame: FG → TONY's right shoulder and
                     hair edge; MG → tablet screen; BG → POPPY's face in soft focus
  Action & Movement: TONY drops her phone onto the bedding beside her, then reaches
                     with her right hand to take the tablet from POPPY [M2].
  Lighting:          as Anchor 1
  Cut:               hold 4.5s; cut after her eyes begin to read → Shot 8
  Dialogue:          TONY: "..."        (or —)
  Audio:             ambient apartment; a truck downshifting outside
  Pacing:            NORMAL             (HOOK | RAPID | PUNCHY | NORMAL | SLOW)
```

- `Camera` must state **size / angle / movement / lens**, then **placement** (where the lens physically is, relative to CAPS set elements), then **In frame** as explicit `FG` / `MG` / `BG` layers. "Close-up on Tony" is not a camera field — it doesn't say where the lens is, so two shots can't be checked against each other.
- `Lighting: as Anchor N` is the normal value. Any deviation must be stated and justified, because deviating from the anchor is exactly what makes a cut look like a different room.
- `duration` in seconds, one decimal place. Chunking and cost are arithmetic on it. Studio persists a continuous float 1–60 (pre-#502 it snapped to `5/8/10/12/15`) — see `mixio-script-breakdown`.
- `Pacing` drives the rapid-pacing warning in the production summary.

This is the **authoring** format, and since Studio PR #502 it maps essentially 1:1 onto canonical keys: `Camera` splits across `shot_type` / `camera_angle` / `camera_movement` / `lens`, `In frame` becomes `blocking`, and `Lighting` is its own field. `mixio-script-breakdown` owns the field-by-field mapping — read it before writing a breakdown to Studio.

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
| `REF_MISSING` | A linked character/location/prop has no corresponding reference element in the project |
| `REF_NO_IMAGE` | A linked reference element exists but has no attached media — generation will lack visual consistency |

Report format is one line per issue: `Shot 7 | TONY | PROP — phone disappears with no stated put-down action`.
