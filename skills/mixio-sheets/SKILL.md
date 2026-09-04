---
name: mixio-sheets
description: "Build the reference layer an episode is generated against — character turnaround sheets, location sheets, prop sheets, and one wide anchor frame per scene — and persist them as Cast & World references so every shot inherits the same look. Not raw Cast & World CRUD (mixio-references) or auditing references that already exist (mixio-reference-audit). Unclear which step you need → mixio-pipeline."
version: 0.3.1
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

Then persist the structured identity alongside it — one schema owns these fields for every surface. Write it like this:

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

### Mint the mention tag with the sheet

The name you give a reference here becomes its `@tag` at generation time — `Tony` resolves `@tony`, a look variant resolves `@tony.casual`. That token is what binds this sheet's image to this character in a multi-reference prompt; without it the model receives several faces and guesses (see incident `b463831e-ac6f-4a40-a2b2-0ebde2527c92` in `mixio-generate`).

**Mandatory Invariant (Universal across all generations & models)**: Prompts MUST ALWAYS contain `@` mentions for all active assets/references (e.g. `@asset1`, `@tony`, `@scene1`). Any asset passed via `media` (`primary`, `character_ref`, `location_ref`, `enhancer_context`) must be embedded in the prompt string where the subject acts across all image and video models.

So decide the tag **once, here**, and record it in pipeline state next to the reference id, so the breakdown, the audit and the generation step all emit the same vocabulary. Two rules that save a re-render:

- Keep the reference name short and unambiguous. `Tony` is a good tag; `Tony Russo (protagonist, ep1)` slugifies into something nobody will type consistently.
- Do not name two references so they collapse to the same slug. `TONY'S APARTMENT` and `Tonys Apartment` are one tag, and whichever image loses the race silently stops binding.
- Pair every tag in `slotTags` with an entry in `mentionMap` (`{ "@tony": "Tony Russo" }`) when submitting generation payloads.

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

That works, but binding the look once via `lookRef` on the shot's (or scene's) `appears_in` relation — see the appearance-state section below — is the durable path where the shot-scoped look cascade is live: generation then resolves it automatically instead of every shot needing the right `character_ref` passed by hand. Check whether your Studio has it: `get_production_context` returns a `lookBindings` key once it does.

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

The sheet has real fields, not prose blobs — map the six sheet fields onto `locationDetails` (`spatialLayout`, `accessPoints`, `keyLandmarks`, `depthAxes`, `lightSources`, `surfaces`/`palette`, …). Write straight into `locationDetails`/`characterDetails`; the shared prompt-projection table reads them directly, no top-level `metadata` mirroring needed on a current Studio.

Full field-mapping table, a worked `studio_update_reference` call, and the older-Studio metadata-mirroring fallback: `references/location-fields.md`.

### Time-of-day and weather variants

`lightingNotes` promises "time-of-day variants" but a DAY and a NIGHT version of one room are not one lighting note — they are two different reference images. Use the **same variant mechanism as character costumes**, which works on locations too:

```
referenceVariants: [
  { name: "day",   kind: "primary", isDefault: true, images: [{ url: dayRef,   isPrimary: true }] },
  { name: "night", kind: "look",                     images: [{ url: nightRef, isPrimary: true }] },
  { name: "rain",  kind: "look",                     images: [{ url: rainRef,  isPrimary: true }] }
]
```

Names must sit in `variantVocabulary.LOCATION` when the project is `closed`. Select the variant matching the scene's `timeOfDay` when you render its anchor. A scene-level `lookRef` binding — see the appearance-state section below and `mixio-script-breakdown` — can make generation resolve that variant automatically for every shot in the scene. Check it's live before relying on it: `get_production_context` returns a `lookBindings` key once it is. No key, or no binding made, and it's still on you to pass the right variant. The alternative people reach for — registering `TONY'S APARTMENT (NIGHT)` as a second LOCATION — splits the space and the two halves drift apart exactly like a split character does.

## Per-scene character state: appearance yes, staging not yet

A character's *identity* is project-scoped and belongs here. A character's **state** is per shot and belongs elsewhere.

**Covered** — by `appearanceState` on the `appears_in` relation (`wardrobe`, `hairState`, `condition`, `carriedProps`, `emotionalState`, `lookRef`, `continuityNotes`): validated, and readable back through the relation. Write it from the breakdown or the audit; see `mixio-script-breakdown`. `lookRef` is more than record-keeping where the shot-scoped look cascade is live: generation then resolves it shot-then-scene-then-default and renders whatever it points at, so filling that one field becomes enforcement, not just a note for the next session. Check whether your Studio has it: `get_production_context` returns a `lookBindings` key once it does.

**Not covered by a canonical field**: zone, facing, posture, relative-to. The shot's canonical `blocking` is a single string describing the whole frame, not per character. They're durable-but-unchecked, not session-local: written as passthrough (inline in `action`/`blocking`, or as their own keys) they persist, and on jobs where the prompt materializer runs (`promptEnhancementMode: "enhance"`, see `mixio-script-breakdown/references/canonical-schema.md`) they reach the generation prompt. Either way nothing downstream reads or enforces them, so the `STAGING` block and the continuity blocking map still need posture/facing restated in each shot rather than trusted from inheritance.

When you restate them, **hang them off the mention** rather than writing one blended sentence:

```
@tony (MC, three-quarter-left, seated cross-legged, on BED beside BEDSIDE TABLE)
@poppy (FL, three-quarter-right, standing, at BED FRAME edge, tablet extended)
```

One clause per character keeps the columns recoverable by the next audit pass, and the mention token is the one thing that survives prompt assembly with its position intact — so the staging stays attached to the right subject instead of being re-attributed by the model.

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

`anchorRef` (plus `anchorRefs` for extras, max 50) is a canonical scene key, and generation merges it into every job prepared for a shot in that scene. That replaces attaching the anchor by hand per shot. Anchors dedupe by slot reference id so an explicit per-shot choice still wins, and an anchor whose media can't be read is skipped rather than guessed at.

Also record it in `metadata.pipeline.anchors` if you want a resumable index — but `anchorRef` is what actually drives generation. Do **not** write `anchor_ref`: it isn't rejected — it lands in passthrough as inert prompt noise instead of attaching the anchor, and nothing signals that it never took effect. Write `anchorRef`.

### Anchor prompt binding & mention tagging

When an anchor frame is passed in `input.media` (for instance as `enhancer_context` or `location_ref`), the generation prompt MUST explicitly bind it using its `@` mention tag (e.g. `@scene1` or `@anchor1`) alongside character tags (`@tony`, `@asset1`).

Pair the anchor asset in `slotTags` and `mentionMap`:
```json
{
  "slotTags": {
    "elem_anchor_scene_1": "@scene1",
    "elem_tony_ref": "@char1"
  },
  "mentionMap": {
    "@scene1": "Scene 1 Apartment Anchor",
    "@char1": "Tony"
  }
}
```
And embed in the prompt:
`"@char1 sits at the edge of the bed under @scene1 lighting and layout, looking up toward the doorway."`

Without the `@scene1` token in the prompt and paired `slotTags`/`mentionMap`, provider compilers cannot map the anchor to model tokens (`Image 2`, `@Element1`), causing the model to ignore the spatial truth and invent arbitrary room geometry.

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
- External URLs (Drive, Dropbox, third-party CDNs) frequently fail through `studio_upload_media_from_url` with `No files were uploaded`. Use the validated fallback in `mixio-workspace`: create a unique `mktemp` directory, run `curl --fail --silent --show-error --location`, require a non-empty supported MIME type, derive the file extension before `upload_file({ path: asset_path, project_id, organization_id })`, update the reference/slot, and let the cleanup trap remove only that run's directory.
- Set `workflow.status` honestly (`draft` → `in_review` → `approved`). Downstream steps should treat a non-approved sheet as provisional.
