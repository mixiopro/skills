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
- **Resolved scope — required.** You must be working against a project (and an episode for anchors) that the user has
  explicitly confirmed. If it is not already established in this session, list the
  candidates (`studio_list_projects` / `studio_list_episodes`) and **ask the user to
  choose** before doing anything else. Never guess an id, infer one from a name, or
  create a new project or episode to avoid asking. See `mixio-project`.
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

## Check the project's reference policy first

Before creating anything, read `settings.references` with `studio_get_project` — a configured project can forbid the writes this skill would otherwise make. See `mixio-references` for the full contract.

- **`createPolicy: link_only`** — do not create references. Link to existing ones, and report any script entity with no match instead of inventing it.
- **`createPolicy: propose`** — surface the proposed reference list for approval rather than writing it.
- **`variantPolicy: closed`** — variant names must come from `variantVocabulary[TYPE]`. Do not invent `"Gala Dress"` when the vocabulary is `['casual','formal']`; map to the vocabulary term or ask.
- **`aliasMatching: true`** — record aliases as you go (below), because matching depends on them.

Record aliases for every reference whose script name differs from its canonical name. This is what stops episode 2 creating a second `Tony Russo` beside episode 1's `TONY`:

```
studio_update_element({ elementId: referenceId, updates: { metadata: {
  aliases: ["Tony Russo", "Antonia"]
}}})
```

## Character sheet

A turnaround: one image (or an image set) showing the character from the angles a shot might need, in neutral conditions so the sheet carries **identity, not mood**.

Render spec:
- **Angles**: front, three-quarter-left, profile, three-quarter-right, back — full body; plus a head-and-shoulders pass at front and three-quarter.
- **Background**: flat white or light grey, no set dressing, no props not attached to the character.
- **Lighting**: flat, even, neutral. No dramatic key. A sheet lit at golden hour poisons every shot that references it.
- **Pose**: neutral standing, arms relaxed and clear of the body, expression neutral.
- **Wardrobe**: the character's default costume. One sheet per costume — see variants below.
- **Aspect ratio**: `16:9` or `4:3` regardless of delivery ratio; a turnaround needs horizontal room.

Then persist the structured identity alongside it. Since Studio PR #502/#504 one schema owns these fields for all surfaces, so what you write here is what the Cast & World UI and generation both read:

```
studio_update_reference({
  referenceId,
  attachments: [{ url: sheetUrl, label: "Turnaround", isPrimary: true }],
  characterDetails: {
    role: "protagonist",              // enum: protagonist|antagonist|supporting|background
    age: "24", build: "petite, 5'2\"", height: "5'2\"",
    skin: "olive", eyes: "dark brown",
    hair: "dark brown, shoulder-length, loose curls",
    distinctiveFeatures: "small scar left eyebrow; always wears the gold saint pendant",
    visualAnchor: "the gold saint pendant — visible in every shot she is in",
    wardrobeNotes: "default: red tee, dark jeans, bare feet indoors",
    personality: "deadpan, fast", speechStyle: "Brooklyn, dry, clipped",
    customAttributes: [{ key: "handedness", value: "right" }]
  },
  workflow: { status: "in_review" }
})
```

Full field set: `role` (enum), `age`, `personality`, `build`, `skin`, `hair`, `eyes`, `height`, `distinctiveFeatures`, `visualAnchor`, `bio`, `backstory`, `motivations`, `speechStyle`, `wardrobeNotes`, `relationshipsSummary`, `castingNotes`, `voiceProfile`, `voiceReference`, `voiceRegistrations`, `looks`, `customAttributes`. Legacy spellings are mapped on read (`dialogueStyle` → `speechStyle`, `visual_anchor` → `visualAnchor`, `age_range` → `age`, `custom_attributes` → `customAttributes`, and similar), so old data keeps working — but write the canonical name.

The three voice fields are structured, not strings: `voiceProfile` takes `{ provider?, voiceId?, voiceName?, language?, accent?, genderPresentation?, agePresentation?, tone?, deliveryStyle?, notes?, previewUrl? }`, `voiceReference` takes `{ sampleAudioMediaId?, sampleAudioUrl?, language?, notes?, label? }`, and `voiceRegistrations` is a provider-keyed record. `looks` is owned by the variant layer — write looks through `referenceVariants`, not by hand here.

`visualAnchor` is the single feature that makes the character recognizable across models — name it explicitly, and repeat it in shot prompts.

**Do not put per-shot state here.** Hair state, condition/damage, and carried props are properties of an *appearance*, not of the character, and belong on the `appears_in` relation's `appearanceState` — see `mixio-script-breakdown`. A soaked-hair value on the character is one global truth that is only correct in a few shots.

### Wardrobe variants

A costume change is a **named variant**, not a new character. Use `referenceVariants` (full replace of the variant list — see `mixio-references`):

```
referenceVariants: [
  { name: "Default Look", kind: "primary", isDefault: true, images: [{ url: defaultSheet, isPrimary: true }] },
  { name: "formal",       kind: "look",    images: [{ url: galaSheet, isPrimary: true }] }
]
```

`kind` is `primary` | `look` | `reference`. Under `variantPolicy: closed` the `name` must come from `variantVocabulary.CHARACTER` — that's why the second entry above is `"formal"` and not `"Gala Dress"`. On an open project use a descriptive name.

Shots then reference the variant by name in `character_ref`. Registering `TONY (gala)` as a second CHARACTER splits the identity and both halves drift.

Hair state (up/down/wet) and condition (bruised, soaked, dusty) are *not* costume changes and should not consume a wardrobe variant name. There is currently no field for them — see the state limitation below.

### Scale sheets

When relative height matters (adult/child, human/creature), render one `SCALING_SHEET` element with the cast side by side at true relative height against a gridded or plain background. Retrieve it with `studio_list_references({ projectId, type: "SCALING_SHEET" })` and feed it as a reference on any shot with both characters in frame.

Cheaper alternative for a single character: set `metadata.scalingLabel` on the reference (via `studio_update_element` — `update_reference` has no `metadata` param). Either mechanism causes scale constraints to be injected into generation prompts; neither one present means the model picks relative heights freshly in every shot.

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

### Persisting the sheet

Since Studio PR #502/#504 the sheet has real fields instead of prose blobs. Map it like this:

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

Persist to `locationDetails` (`setting`, `timePeriod`, `mood`, `lighting`, `palette`) plus the full sheet text in the reference description.

### Time-of-day and weather variants

`lightingNotes` promises "time-of-day variants" but a DAY and a NIGHT version of one room are not one lighting note — they are two different reference images. Use the **same variant mechanism as character costumes**, which works on locations too:

```
referenceVariants: [
  { name: "day",   kind: "primary", isDefault: true, images: [{ url: dayRef,   isPrimary: true }] },
  { name: "night", kind: "look",                     images: [{ url: nightRef, isPrimary: true }] },
  { name: "rain",  kind: "look",                     images: [{ url: rainRef,  isPrimary: true }] }
]
```

Names must sit in `variantVocabulary.LOCATION` when the project is `closed`. Select the variant matching the scene's `timeOfDay` when you render its anchor — nothing does this automatically today, so it is on you to pass the right one. The alternative people reach for — registering `TONY'S APARTMENT (NIGHT)` as a second LOCATION — splits the space and the two halves drift apart exactly like a split character does.

## Per-scene character state: appearance yes, staging not yet

A character's *identity* is project-scoped and belongs here. A character's **state** is per shot and belongs elsewhere — and since Studio PR #504 it has a real home.

**Covered** by `appearanceState` on the `appears_in` relation (`wardrobe`, `hairState`, `condition`, `carriedProps`, `emotionalState`, `lookRef`, `continuityNotes`) — validated, and readable back through the relation. Write it from the breakdown or the audit; see `mixio-script-breakdown`.

**Not covered**: zone, facing, posture, relative-to. The shot's canonical `blocking` is a single string describing the whole frame, not per character. So the `STAGING` block and the continuity blocking map remain session-local for those columns, and posture/facing must be restated in each shot's own `action` / `blocking` text rather than inherited.

## Prop sheet

Only for props that carry story weight or change hands — the ones prop-continuity checks track. A single clean image on neutral background, plus `propDetails`: `category` (enum: `handheld` | `furniture` | `vehicle` | `costume` | `weapon` | `food` | `technology` | `other`), `material`, `sizeScale`, `significance`, and `customAttributes`. Background dressing named in the location sheet does not need its own sheet.

`sizeScale` is the prop's own scale label (`"fits one hand"`, `"waist height"`) and feeds the same scale-constraint path as a character's `scalingLabel` — set it for anything whose size a model could get wrong.

## Anchor frames

One per scene, and the highest-leverage image in the pipeline.

An anchor is a **wide master of the scene at its opening moment**: the set as described in the location sheet, characters in their `Characters at start` staging, lit as the scene's `Time + light`. Every shot in the scene then inherits from it (`Lighting: as Anchor 1`), which is why cuts within a scene hold together.

- Render at `anchor_aspect_ratio` (wider than delivery — `16:9` when delivering `9:16`). The extra horizontal information is the point: shots crop *into* a known space instead of each inventing its own.
- Include: full set with the CAPS key elements visible, the scene's characters at start position/facing/posture, the scene's light direction and shadow length.
- Exclude: dramatic framing, mid-scene action, anything that only happens later. An anchor is a reference, not a shot.
- Feed the location reference into `location_ref` and each character sheet into `character_ref` on the same job so the anchor is consistent with the sheets.
- A scene with a big lighting or staging shift mid-way (day→night, everyone relocates) needs a second anchor. Note the switch shot in the staging block: `Coverage: Shots 1–10 → Anchor 1; Shots 11–18 → Anchor 2`.

Persist the anchor as a KEYFRAME element, then **point the scene at it** so generation attaches it automatically:

```
studio_create_element({ projectId, type: "KEYFRAME", name: "Anchor 1 — Scene 01",
  metadata: { sceneNumber: 1, kind: "anchor", aspect_ratio: "16:9" },
  tags: { episodeId }, previewUrl: anchorUrl })
→ anchorElementId

studio_upsert_scene_packages({ projectId, episodeId, scenes: [{
  sceneNumber: 1, name: "...", metadata: { anchorRef: anchorElementId }
}]})
```

Since Studio PR #502 `anchorRef` (plus `anchorRefs` for extras, max 50) is a canonical scene key, and generation merges it into every job prepared for a shot in that scene. That replaces attaching the anchor by hand per shot. Anchors dedupe by slot reference id so an explicit per-shot choice still wins, and an anchor whose media can't be read is skipped rather than guessed at.

Also record it in `metadata.pipeline.anchors` if you want a resumable index — but `anchorRef` is what actually drives generation. Do **not** write `anchor_ref` — the canonical key is `anchorRef`. A separator variant is silently ignored today and will be rejected outright once Studio PR #503 lands.

## Workflow

```
1. parse script → cast list + location list + story-critical props
2. studio_get_project({ projectId })                → settings.references policy (createPolicy, variantPolicy, vocabulary)
3. studio_list_references({ projectId })            → what already exists
4. ask the user for reference images; confirm image→location mapping; note skips as TEXT-ONLY
5. studio_register_reference_entities({ projectId, references })   → upsert by name (respect createPolicy)
   studio_update_element({ metadata: { aliases } })                → record script-name aliases
6. per character: render turnaround → studio_update_reference({ attachments, characterDetails })
   per location:  write the 6-field sheet → studio_update_reference({ locationDetails, referenceVariants })
7. per scene: render anchor at anchor_aspect_ratio with location_ref + character_ref
   (pick the location variant matching the scene's timeOfDay)
   → studio_create_element({ type: "KEYFRAME" }) → record id in metadata.pipeline.anchors
8. show every sheet and anchor for approval → GATE → Step 03 Panel Breakdown
```

## Notes

- Sheets are the cheapest place to fix a look. Re-rendering one sheet is one job; re-rendering the 12 shots that referenced a wrong sheet is twelve.
- Wrong images already attached? Fix with `referenceVariants` (replaces), not `attachments` (merges) — and never with `thumbnailUrl`, which only changes the card preview. See `mixio-references`.
- External URLs (Drive, etc.) frequently fail through `studio_upload_media_from_url`. Download locally, then `upload_file`.
- Set `workflow.status` honestly (`draft` → `in_review` → `approved`). Downstream steps should treat a non-approved sheet as provisional.
