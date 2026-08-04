---
name: mixio-sheets
description: "Build the reference layer an episode is generated against — character turnaround sheets, location sheets, prop sheets, and one wide anchor frame per scene — and persist them as Cast & World references so every shot inherits the same look."
version: 0.1.0
invoke: /mixio:sheets
---

# Mixio Sheets

Step 02 of `mixio-pipeline`. Consistency across a 40-shot episode is not a prompting problem, it is a **reference problem**: every shot must be generated against the same images. This skill produces those images and the structured text that travels with them.

Three artifacts, two lifetimes:

| Artifact | Scope | Answers |
|----------|-------|---------|
| **Character sheet** | project | who this person is, from every angle |
| **Location sheet** | project | what this space contains and where |
| **Anchor frame** | episode / scene | how this scene is staged and lit, right now |

Character and location sheets are built once and reused across episodes. Anchors are per scene, and are the thing shots point at (`Lighting: as Anchor 1`).

Vocabulary: `mixio-pipeline/references/shot-grammar.md`.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- A locked script (Step 01) — the cast and location lists come from its sluglines and CAPS tokens
- `aspect_ratio` and `anchor_aspect_ratio` locked on the episode

## MCP tools used

Read `mixio-references` for the write semantics (especially `attachments` vs `referenceVariants`) and `mixio-generate` for job submission — this skill only covers *what* to build.

| Tool | Used for |
|------|----------|
| `studio_register_reference_entities` | Bulk upsert CHARACTER/LOCATION/PROP by name — idempotent, run it first |
| `studio_submit_studio_job` | Render the sheet / anchor images |
| `upload_file` | Bring a user-supplied local image in and get a permanent URL |
| `studio_update_reference` | Attach images + `characterDetails`/`locationDetails`/`propDetails` |
| `studio_list_references` | Check what already exists before rendering anything |

## Always ask before rendering

The user may already have art. Extract the cast and location list from the script, present it, and ask for references:

```
Locations found — drop a reference image for each and tell me which is which.
  • INT. TONY'S BEDROOM — the bed, phone-scrolling area, door POPPY enters through
  • INT/EXT. TONY'S FRONT DOOR — doorway, BENTLEY visible behind

Reply like: TONY'S BEDROOM = [Image 1], FRONT DOOR = [Image 3]
For any location without a reference, say "skip <location>" — it will be
grounded in script text only and marked TEXT-ONLY.
```

Two supplied images may be two angles of one space. Say what you inferred and get it confirmed (`Both [Image 1] and [Image 2] = TONY'S APARTMENT — two angles`) rather than registering two locations that will drift apart.

Generating a reference the user already owns wastes credits and throws away the look they wanted. `studio_list_references` first, ask second, render last.

## Character sheet

A turnaround: one image (or an image set) showing the character from the angles a shot might need, in neutral conditions so the sheet carries **identity, not mood**.

Render spec:
- **Angles**: front, three-quarter-left, profile, three-quarter-right, back — full body; plus a head-and-shoulders pass at front and three-quarter.
- **Background**: flat white or light grey, no set dressing, no props not attached to the character.
- **Lighting**: flat, even, neutral. No dramatic key. A sheet lit at golden hour poisons every shot that references it.
- **Pose**: neutral standing, arms relaxed and clear of the body, expression neutral.
- **Wardrobe**: the character's default costume. One sheet per costume — see variants below.
- **Aspect ratio**: `16:9` or `4:3` regardless of delivery ratio; a turnaround needs horizontal room.

Then persist the structured identity alongside it. These fields are what a shot prompt pulls from when the image alone is ambiguous:

```
studio_update_reference({
  referenceId,
  attachments: [{ url: sheetUrl, label: "Turnaround", isPrimary: true }],
  characterDetails: {
    role: "lead", age: "24", build: "petite, 5'2\"",
    skin: "olive", hair: "dark brown, shoulder-length, loose curls",
    distinctiveFeatures: "small scar left eyebrow; always wears the gold saint pendant",
    visualAnchor: "the gold saint pendant — visible in every shot she is in",
    wardrobeNotes: "default: red tee, dark jeans, bare feet indoors",
    personality: "deadpan, fast", speechStyle: "Brooklyn, dry, clipped"
  },
  workflow: { status: "in_review" }
})
```

`visualAnchor` is the single feature that makes the character recognizable across models — name it explicitly, and repeat it in shot prompts.

### Wardrobe variants

A costume change is a **named variant**, not a new character. Use `referenceVariants` (full replace of the variant list — see `mixio-references`):

```
referenceVariants: [
  { name: "Default Look", isDefault: true, images: [{ url: defaultSheet, isPrimary: true }] },
  { name: "Gala Dress",   images: [{ url: galaSheet, isPrimary: true }] }
]
```

Shots then reference the variant by name in `character_ref`. Registering `TONY (gala)` as a second CHARACTER splits the identity and both halves drift.

### Scale sheets

When relative height matters (adult/child, human/creature), render one `SCALING_SHEET` element with the cast side by side at true relative height against a gridded or plain background. Retrieve it with `studio_list_references({ projectId, type: "SCALING_SHEET" })` and feed it as a reference on any shot with both characters in frame.

## Location sheet

Text first, image second. The six fields, in this order — this is the schema the continuity audit reads:

```
LOCATION SHEET — TONY'S APARTMENT   ([Image 1] + [Image 2])

Layout:            Open studio room. BED against the left wall (window side), COUCH
                   centered facing the staircase wall, OLIVE ARMCHAIR left of the couch,
                   COFFEE TABLE between them, DESK STATION against the right wall.
Entries & exits:   BEDROOM DOOR — dark wood, left wall beside the BED.
                   STAIRCASE — ascends from center-back; dark door at its base.
                   TWO WINDOWS — back wall; not entries, but the key light source.
Key elements:      BED — white bedding, green and rust pillows, beneath the NAPOLI
                   POSTER and NETS BANNER. COFFEE TABLE — rustic wood, lower shelf with
                   books, remote on top. DESK STATION — dual monitors, office chair, mug.
                   RING LIGHT — on tripod near the bed. PERSIAN RUG — dark hardwood under.
Depth & axes:      Long axis runs from the WINDOWS (back-left) through the COUCH/COFFEE
                   TABLE to the STAIRCASE (back-right). [Image 1] looks along this axis
                   toward the staircase; [Image 2] looks the reverse, toward the windows.
Light sources:     NATURAL DAYLIGHT through the two windows, warm gold, long shadows
                   (afternoon). CEILING FIXTURE above the staircase landing. TABLE LAMP
                   on the BEDSIDE TABLE. CANDLE on the coffee table.
Surfaces & palette: Dark hardwood, large Persian rug (deep reds, navy, cream), pressed tin
                   ceiling, off-white walls. Warm, lived-in Italian-American Brooklyn.
```

- **`Depth & axes` is the field that prevents crossing the line.** Name the long axis and which direction each reference image looks along it, and left/right stays stable between a wide and a reverse.
- Every element named here in CAPS becomes a prop-continuity token for Step 04.
- No reference image → header gets `(TEXT-ONLY)`, unknown fields get `UNKNOWN`. Do not fill `Layout: UNKNOWN` with a plausible invention; the audit needs to know it is unverified.

Persist to `locationDetails` (`setting`, `timePeriod`, `mood`, `lighting`, `palette`) plus the full sheet text in the reference description.

## Prop sheet

Only for props that carry story weight or change hands — the ones prop-continuity checks track. A single clean image on neutral background, plus `propDetails` (`category`, `material`, `significance`). Background dressing named in the location sheet does not need its own sheet.

## Anchor frames

One per scene, and the highest-leverage image in the pipeline.

An anchor is a **wide master of the scene at its opening moment**: the set as described in the location sheet, characters in their `Characters at start` staging, lit as the scene's `Time + light`. Every shot in the scene then inherits from it (`Lighting: as Anchor 1`), which is why cuts within a scene hold together.

- Render at `anchor_aspect_ratio` (wider than delivery — `16:9` when delivering `9:16`). The extra horizontal information is the point: shots crop *into* a known space instead of each inventing its own.
- Include: full set with the CAPS key elements visible, the scene's characters at start position/facing/posture, the scene's light direction and shadow length.
- Exclude: dramatic framing, mid-scene action, anything that only happens later. An anchor is a reference, not a shot.
- Feed the location reference into `location_ref` and each character sheet into `character_ref` on the same job so the anchor is consistent with the sheets.
- A scene with a big lighting or staging shift mid-way (day→night, everyone relocates) needs a second anchor. Note the switch shot in the staging block: `Coverage: Shots 1–10 → Anchor 1; Shots 11–18 → Anchor 2`.

Persist as a KEYFRAME element and record the id in `metadata.pipeline.anchors` so Step 04 and Step 06 can find it:

```
studio_create_element({ projectId, type: "KEYFRAME", name: "Anchor 1 — Scene 01",
  metadata: { sceneNumber: 1, kind: "anchor", aspect_ratio: "16:9" },
  tags: { episodeId }, previewUrl: anchorUrl })
```

## Workflow

```
1. parse script → cast list + location list + story-critical props
2. studio_list_references({ projectId })            → what already exists
3. ask the user for reference images; confirm image→location mapping; note skips as TEXT-ONLY
4. studio_register_reference_entities({ projectId, references })   → upsert by name
5. per character: render turnaround → studio_update_reference({ attachments, characterDetails })
   per location:  write the 6-field sheet → studio_update_reference({ locationDetails })
6. per scene: render anchor at anchor_aspect_ratio with location_ref + character_ref
   → studio_create_element({ type: "KEYFRAME" }) → record id in metadata.pipeline.anchors
7. show every sheet and anchor for approval → GATE → Step 03 Panel Breakdown
```

## Notes

- Sheets are the cheapest place to fix a look. Re-rendering one sheet is one job; re-rendering the 12 shots that referenced a wrong sheet is twelve.
- Wrong images already attached? Fix with `referenceVariants` (replaces), not `attachments` (merges) — and never with `thumbnailUrl`, which only changes the card preview. See `mixio-references`.
- External URLs (Drive, etc.) frequently fail through `studio_upload_media_from_url`. Download locally, then `upload_file`.
- Set `workflow.status` honestly (`draft` → `in_review` → `approved`). Downstream steps should treat a non-approved sheet as provisional.
