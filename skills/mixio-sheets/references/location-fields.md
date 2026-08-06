# Location sheet — field mapping and persistence

Read this when persisting a location sheet's six fields into `locationDetails`. For how to write the sheet itself, see the main `SKILL.md`.

The sheet has real fields, not prose blobs. Map the sheet like this:

| Sheet field | `locationDetails` key | Shape |
|---|---|---|
| Layout | `spatialLayout` | text, ≤4000 |
| Entries & exits | `accessPoints` | array of strings, max 50 |
| Key elements | `keyLandmarks` | array of strings, max 50 |
| Depth & axes | `depthAxes` | **object**: `{ foreground?, midground?, background? }` |
| — | `sightlines` | text — what sees what, ≤2000 |
| — | `dimensions` | text, e.g. `"about 6m × 4m, 3m ceiling"` |
| Light sources | `lightSources` | array of strings, max 50 — the practicals and windows themselves |
| — | `lighting` | text — the key lighting *setup and quality*, ≤2000 |
| Surfaces & palette | `surfaces` + `palette` | `surfaces` = floors, walls, ceiling, decor (≤4000); `palette` = **colour only** |
| — | `architecturalStyle` | text |
| (header) | `setting` | enum: `interior` \| `exterior` \| `both` |
| — | `timePeriod`, `mood` | text |
| — | `customAttributes` | `[{ key, value }]`, max 100 — anything the fields above don't cover |

Note the two pairs that are easy to collapse and shouldn't be: `lightSources` lists the *fixtures* while `lighting` describes the *setup they produce*; `surfaces` carries material and decor while `palette` is colour alone. Before these fields existed both halves ended up jammed into one free-text note.

```
studio_update_reference({ referenceId, locationDetails: {
  setting: "interior", timePeriod: "present day",
  spatialLayout: "Open studio room. BED against the left wall (window side), COUCH centered facing the staircase wall…",
  accessPoints: ["BEDROOM DOOR — dark wood, left wall beside the BED",
                 "STAIRCASE — ascends from center-back",
                 "TWO WINDOWS — back wall; not entries, but the key light source"],
  keyLandmarks: ["BED — white bedding, green and rust pillows", "COFFEE TABLE — rustic wood",
                 "DESK STATION — dual monitors", "PERSIAN RUG", "RING LIGHT on tripod"],
  depthAxes: { foreground: "COFFEE TABLE and OLIVE ARMCHAIR",
               midground: "COUCH, PERSIAN RUG, BED along the left wall",
               background: "STAIRCASE at back-right, TWO WINDOWS at back-left" },
  sightlines: "From the BED you see the staircase and the front door; the DESK faces away from both",
  dimensions: "long axis WINDOWS (back-left) → COUCH → STAIRCASE (back-right)",
  lightSources: ["TWO WINDOWS — back wall, primary daylight",
                 "CEILING FIXTURE — above the staircase landing",
                 "TABLE LAMP — on the BEDSIDE TABLE"],
  lighting: "warm gold daylight from back-left, long afternoon shadows across the rug; lamp off by default",
  surfaces: "dark hardwood floor, pressed tin ceiling, off-white plaster walls, framed photos on the staircase wall",
  palette: "deep reds, navy, cream",
  architecturalStyle: "brownstone, lived-in"
}})
```

Note `depthAxes` is an **object keyed by depth plane**, not the prose "long axis" sentence — put the axis statement in `dimensions` or `sightlines`. These fields exist precisely so a shot needing a viewpoint the reference image doesn't show can be directed without the model inventing geography.

## The full schema is live — no metadata mirroring needed

One schema owns the character/location/prop detail fields, and generation reads them directly: `production-prompting.ts` projects `locationDetails`/`characterDetails` into the prompt through the shared `referenceDetailPromptPairs` table, not a hand-picked three-key list. Write the fields from the table above straight into `locationDetails`/`characterDetails` — nothing needs mirroring to top-level `metadata`.

If you're on an older Studio that hasn't caught up, `locationDetails` will only retain a narrow field set (`setting`, `timePeriod`, `mood`, `lightingNotes`, `architecturalStyle`; `characterDetails` similarly narrow) and generation will only read a top-level `metadata` mirror — for a LOCATION: `description`, `setting`, `locationType`, `timePeriod`, `lighting`, `palette`, `atmosphere`, `mood` — not the nested bag. Check by reading the reference back after a write: if `spatialLayout`/`depthAxes`/`accessPoints` don't round-trip, write the full bag anyway — it's retained and lights up the moment the instance updates — but also mirror the load-bearing ones to top-level `metadata` as a fallback until it does:

```
metadata: {
  lighting: "warm gold daylight from back-left, long afternoon shadows across the rug; lamp off by default",
  palette:  "deep reds, navy, cream",
  atmosphere: "warm, lived-in, cluttered",
  description: "Open studio room. Long axis runs WINDOWS (back-left) → COUCH/COFFEE TABLE → STAIRCASE (back-right). "
               + "Entries: BEDROOM DOOR (left wall, beside the BED), STAIRCASE (ascends from center-back). "
               + "TWO WINDOWS on the back wall are not entries but are the key light source."
}
```
