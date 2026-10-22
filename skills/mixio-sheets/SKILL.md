---
name: mixio-sheets
description: "Use when an episode needs character or location references prepared for consistent image generation, especially when the script requires multiple character looks or views across rooms, interiors, and exteriors. Not raw Cast & World CRUD (mixio-references) or auditing existing references (mixio-reference-audit). Unclear which step you need → mixio-pipeline."
version: 0.3.1
invoke: /mixio:sheets
---

# Mixio Sheets

Step 04 of `mixio-pipeline`, after the accepted shot plan is synced. Consistency across a 40-shot episode is not a prompting problem, it is a **reference problem**: every shot must be generated against the same images. This skill produces those images and the structured text that travels with them.

Three artifact families, two lifetimes:

| Artifact | Scope | Answers |
|----------|-------|---------|
| **Character reference pack** | project | who this person is by default and which script-required age/clothing variants are needed |
| **Location variant/view packs** | project | which spatial configurations the script needs and how each looks from required camera angles |
| **Anchor frame** | episode / scene | how this scene is staged and lit, right now |

Character and location reference packs are project-scoped and reused across episodes. A character default is an approved character sheet. A location reference is a configurable set of variants, each with labeled camera-view images; it is not assumed to be one image or one universal sheet. Anchors are per scene, and are the thing shots point at (`Lighting: as Anchor 1`).

Use the scenario-driven inventory and view rules in [variant-view-matrix.md](references/variant-view-matrix.md). The `referenceVariants` container is generic; character and location variant meanings are different.

Vocabulary: `mixio-pipeline/references/shot-grammar.md`.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- An accepted, persisted shot plan (pipeline Step 03) — use its character, location, prop, and camera-view demand while preserving the source screenplay
- `aspect_ratio` and `anchor_aspect_ratio` read from project/episode settings; resolve missing values in Step 04 before rendering

## MCP tools used

Read `mixio-references` for the write semantics (especially `attachments` vs `referenceVariants`) and `mixio-generate` for job submission — this skill only covers *what* to build.

| Tool | Used for |
|------|----------|
| `studio_register_reference_entities` | Bulk upsert CHARACTER/LOCATION/PROP by name — idempotent, run it first |
| `studio_submit_studio_job` | Render the sheet / anchor images |
| `upload_file` | Bring a user-supplied local image in and get a permanent URL |
| `studio_update_reference` | Attach images + `characterDetails`/`locationDetails`/`propDetails` |
| `studio_list_references` | Check what already exists before rendering anything |

## Reference rendering checkpoint

The user may already have art. Read the screenplay and current Cast & World references, then build a required variant/view matrix before asking what to render. Derive demand from screenplay evidence, not from registered `#` mentions alone: capture explicit age and costume changes from action, dialogue, and appearance notes; distinguish them from per-shot hair, injury, emotion, or carried-prop state. For locations, account for `INT.`/`EXT.`, named rooms and areas, environmental configurations required by the script, and stated camera geography. A single default is correct when the script requires no other look/configuration. Map supplied images to the exact character look or location configuration and camera-view row they cover. Use a supplied image as visual guidance when deriving missing variants or angles, but count it as coverage only for the row(s) its framing proves. One image does not establish that every script-required look or view is covered.

```
Reference gaps from the script:
  • TONY — default sheet supplied; teen/formal variant needed for scenes 2 and 5
  • THE HOUSE / interior-living-room — [Image 1] covers entry-wide; sofa-to-dining
    and dining-to-balcony views are still needed
  • THE HOUSE / exterior — no supplied view; front-establishing and door-reverse needed

Present the variant/view inventory and which missing images may be generated.
A clear chat "proceed" or prior authorization for that round is enough to render.
For anything the user does not want generated, say "skip <row>" and mark it
TEXT-ONLY. If the user accepts a missing view, carry the limitation into the
shot plan and continue when the selected schema accepts the available inputs;
if it requires the image, offer a compatible model/method or state that technical
constraint. Do not silently claim the missing view was evaluated.
```

Two supplied images may be camera looks for one location variant. Map them to separate view rows (`[Image 1] = entry-wide; [Image 2] = reverse-to-windows`) rather than creating duplicate location entries. When room or indoor/outdoor grouping is ambiguous, show the proposed grouping and ask the user to confirm it.

Present the inventory and first candidate round as a checkpoint. A clear chat “proceed” or prior authorization for that round is sufficient to render. For retries and candidate selection, follow the checkpoint in `mixio-references`; do not require a separate Studio approval state. Attach only media the user selects or has already authorized. Incomplete rows are readiness findings, not planning blockers; explain their likely effect and continue if the user accepts the risk and the model schema/project policy allow it.

## Check the project's reference policy first

Before creating anything, read `settings.references` with `studio_get_project` — a configured project can forbid the writes this skill would otherwise make. See `mixio-references` for the full contract.

- **`createPolicy: link_only`** — do not create references. Link to existing ones, and report any script entity with no match instead of inventing it.
- **`createPolicy: propose`** — surface the proposed reference list for approval rather than writing it.
- **`variantPolicy: closed`** — variant names must come from `variantVocabulary[TYPE]`. Do not invent `"Gala Dress"` when the vocabulary is `['casual','formal']`; map to the vocabulary term or ask.
- **`aliasMatching: true`** — record aliases as you go (below), because matching depends on them.

Record aliases for every reference whose script name differs from its canonical name. This is what stops episode 2 creating a second `Tony Russo` beside episode 1's `TONY`:

```
studio_update_element({ projectId, elementId: referenceId, updates: { metadata: {
  aliases: ["Tony Russo", "Antonia"]
}}})
```

## Reference Enrichment

Everything in this step that writes structured detail — the character sheet's `characterDetails`, the location sheet's `locationDetails`, and the prop sheet's `propDetails` — is collectively the **Reference Enrichment** phase of `mixio-pipeline` Step 04. The local breakdown does not write reference stubs or enrich references; missing details remain readiness gaps until this step.

Write every enrichment via `studio_update_reference` (on an older Studio, mirror load-bearing fields to top-level metadata — see `references/location-fields.md`). The required load-bearing fields are `build`, `hair`, `skin` and **`visualAnchor`** for characters, and `setting`, `lighting`, `spatialLayout` and `depthAxes` for locations — Step 04 (`mixio-reference-audit`) checks the HIGH-severity ones (`visualAnchor`, `setting`, `lighting`) before Step 05 shot planning.

## Character sheet

A turnaround: one image (or an image set) showing the character from the angles a shot might need, in neutral conditions so the sheet carries **identity, not mood**.

Render spec:
- **Angles**: front, three-quarter-left, profile, three-quarter-right, back — full body; plus a head-and-shoulders pass at front and three-quarter.
- **Background**: flat white or light grey, no set dressing, no props not attached to the character.
- **Lighting**: flat, even, neutral. No dramatic key. A sheet lit at golden hour poisons every shot that references it.
- **Pose**: neutral standing, arms relaxed and clear of the body, expression neutral.
- **Wardrobe**: show the character's default costume on the default sheet; add sheets for only the age/clothing combinations required by the script, as listed in the variant matrix below.
- **Aspect ratio**: always `16:9`; the approved contact-sheet template requires this horizontal canvas.

### Natural skin rendering (photorealistic / hyperrealistic intent)

When the locked project style or user direction calls for photorealistic or hyperrealistic characters, describe skin directly in every character-sheet candidate prompt; do not rely on `ultra-realistic`, `8K`, or similar quality slogans. Preserve the character's documented complexion and add natural detail at a scale the view can resolve: fine pores, subtle tonal variation, soft peach fuzz, and faint expression lines in close views. Allow mild natural facial asymmetry and only source-supported freckles, marks, scars, and teeth details; do not invent identity features. Ask for soft, broad, neutral light with gentle directional shape, natural contrast and shadow detail, plausible portrait-lens perspective in face views, and crisp but unretouched, low-noise focus. Exclude poreless smoothing, airbrushing, beauty-filter skin, waxy/plastic gloss, and a CGI mannequin finish. Keep the sheet's neutral conditions; don't add dramatic HDR or a glossy key light to force texture.

For these projects, write the canonical complexion plus stable surface/finish direction into `characterDetails.skin` so the shared prompt projection carries it into image and video jobs. Example: `"medium olive complexion with natural tonal variation and realistic, softly textured skin; no artificial gloss"`. Keep scars and distinctive marks in `distinctiveFeatures`; don't put temporary flushing, sweat, lighting, or per-shot condition in this stable field.

Example prompt direction (include a matching `@` token and URL-valued `mentionMap` binding whenever reference media is supplied):

```text
Photorealistic neutral character turnaround of @tony, matching the approved identity reference and documented complexion. At face-view scale retain natural fine pores, subtle tonal variation, soft peach fuzz, faint expression lines, and mild natural asymmetry; preserve only established marks. Soft broad neutral daylight with gentle camera-left shaping, natural contrast, plausible portrait-lens perspective, and crisp unretouched low-noise focus. No dramatic HDR, airbrushing, poreless smoothing, beauty-filter finish, waxy/plastic shine, or CGI mannequin skin. Keep identity, age, hair, and default wardrobe consistent in every view.
```

Use an approved image of that character as the identity reference when available and permitted by the selected model's live media schema. Do not use an unrelated face as a texture reference. Do not invent numeric reference-strength/weight parameters; send one only when the selected model's live schema exposes it. If the current candidate remains waxy or smooth against the requested realistic style, reject it and retry with the visible defect stated directly in the repair prompt.

### Character-sheet visual gate

Do not approve a sheet because one panel looks plausible. Inspect every view
for facial identity drift, warped eyes or teeth, extra/fused fingers, duplicated
limbs, impossible joints, hallucinated accessories, wardrobe/color changes,
unexplained silhouette changes, and the requested skin surface. For a
photorealistic/hyperrealistic target, clear poreless, airbrushed, waxy, or
plastic-looking skin fails the panel. Hidden anatomy is `unobservable`, not
implicitly approved. A failed panel is a visible quality finding; recommend a
repair, and if the user elects to proceed with the candidate record the accepted
deviation. Run the modern `image-character`
evaluation with ordered aliases and `reference-coverage.subject-kind=character`
for a multi-view sheet, retaining the receipt with the reference asset.

After evaluator review and the user's chat decision, attach the selected sheet and persist the structured identity alongside it — one schema owns these fields for every surface. This sample shows a selected default sheet while other required variants may still be pending; record that readiness status accurately. Never attach a generated candidate before the user selects it.

```
studio_update_reference({
  projectId, referenceId,
  attachments: [{ url: approvedSheetUrl, label: "Turnaround", isPrimary: true }],
  characterDetails: {
    role: "protagonist",              // enum: protagonist|antagonist|supporting|background
    age: "24", build: "petite, 5'2\"", height: "5'2\"",
    skin: "olive complexion with natural tonal variation and realistic, softly textured skin", eyes: "dark brown",
    hair: "dark brown, shoulder-length, loose curls",
    distinctiveFeatures: "small scar left eyebrow; always wears the gold saint pendant",
    visualAnchor: "the gold saint pendant — visible in every shot she is in",
    wardrobeNotes: "default: red tee, dark jeans, bare feet indoors",
    personality: "deadpan, fast", speechStyle: "Brooklyn, dry, clipped",
    customAttributes: [{ key: "handedness", value: "right" }]
  },
  workflow: { status: "in_review" } // set approved only when every required pack is accepted
})
```

Full field set: `role` (enum), `age`, `personality`, `build`, `skin`, `hair`, `eyes`, `height`, `distinctiveFeatures`, `visualAnchor`, `bio`, `backstory`, `motivations`, `speechStyle`, `wardrobeNotes`, `relationshipsSummary`, `castingNotes`, `voiceProfile`, `voiceReference`, `voiceRegistrations`, `looks`, `customAttributes`. Legacy spellings are mapped on read (`dialogueStyle` → `speechStyle`, `visual_anchor` → `visualAnchor`, `age_range` → `age`, `custom_attributes` → `customAttributes`, and similar), so old data keeps working — but write the canonical name.

The three voice fields are structured, not strings: `voiceProfile` takes `{ provider?, voiceId?, voiceName?, language?, accent?, genderPresentation?, agePresentation?, tone?, deliveryStyle?, notes?, previewUrl? }`, `voiceReference` takes `{ sampleAudioMediaId?, sampleAudioUrl?, language?, notes?, label? }`, and `voiceRegistrations` is a provider-keyed record. `looks` is owned by the variant layer — write looks through `referenceVariants`, not by hand here.

For speaking characters, assign a stable Gemini TTS voice in `characterDetails.voiceProfile.voiceId`. Use the exact voice ID selected from the live `text-to-speech` schema/voice selector (for example, a supported prebuilt voice such as `Zephyr`); do not invent an ID. Keep that choice consistent across dialogue generations for the character. `voiceProfile` records the character-level assignment; `voiceReference` is for an audio sample when a workflow explicitly needs one.

`visualAnchor` is the single feature that makes the character recognizable across models — name it explicitly, and repeat it in shot prompts.

### Mint the mention tag with the sheet

The name you give a reference here becomes its `@tag` at generation time — `Tony` resolves `@tony`, a look variant resolves `@tony.casual`. That token is what binds this sheet's image to this character in a multi-reference prompt; without it the model receives several faces and guesses (see incident `b463831e-ac6f-4a40-a2b2-0ebde2527c92` in `mixio-generate`).

**Mandatory Invariant (Universal across all generations & models)**: Prompts MUST ALWAYS contain `@` mentions for all active assets/references (e.g. `@asset1`, `@tony`, `@scene1`). Any asset passed via `media` (`primary`, `references`, `character_ref`, `location_ref`, `style_ref`, `asset_ref`, `enhancer_context`, or another schema-declared slot) must be embedded in the prompt string where the subject acts across all image and video models.

So decide the tag **once, here**, and record it in pipeline state next to the reference id, so the breakdown, the audit and the generation step all emit the same vocabulary. Two rules that save a re-render:

- Keep the reference name short and unambiguous. `Tony` is a good tag; `Tony Russo (protagonist, ep1)` slugifies into something nobody will type consistently.
- Do not name two references so they collapse to the same slug. `TONY'S APARTMENT` and `Tonys Apartment` are one tag, and whichever image loses the race silently stops binding.
- In MCP generation payloads, bind each prompt tag to the exact media URL with `mentionMap` (for example `{ "@tony": "https://.../tony.png" }`). Do not send `slotTags` or a separate human label; the adapter derives internal bindings and labels. Keep URLs unique and include every tag in the prompt.

**Do not put per-shot state here.** Hair state, condition/damage, and carried props are properties of an *appearance*, not of the character, and belong on the `appears_in` relation's `appearanceState` — see `mixio-script-breakdown`. A soaked-hair value on the character is one global truth that is only correct in a few shots.

### Character age and clothing variants

The approved character sheet is the default image when a shot selects no variant. If the only supplied image is a portrait or single pose and no approved sheet exists, use it as identity guidance and include the default turnaround sheet in the confirmed inventory before deriving clothing/age variants. A script-required age or clothing combination is a **named character variant**, not a new character. Use the generic `referenceVariants` container (full replacement semantics; see `mixio-references`):

```
referenceVariants: [
  { name: "Default Look", kind: "primary", isDefault: true, images: [{ url: defaultSheet, isPrimary: true }] },
  { name: "adult-casual", kind: "look",    images: [{ url: adultCasualSheet, isPrimary: true }] },
  { name: "teen-formal",  kind: "look",    images: [{ url: teenFormalSheet, isPrimary: true }] }
]
```

`kind` is `primary` | `look` | `reference`. Under `variantPolicy: closed`, every name must come from `variantVocabulary.CHARACTER`; on an open project use a descriptive name. Create only combinations the screenplay uses, not every possible age × outfit pairing. Keep defining identity features stable across ages and outfits, and evaluate each required variant as an ordered `image-character` pack.

Shots then reference the variant by name in `character_ref`. Registering `TONY (gala)` as a second CHARACTER splits the identity and both halves drift.

That works, but binding the look once via `lookRef` on the shot's (or scene's) `appears_in` relation — see the appearance-state section below — is the durable path where the shot-scoped look cascade is live: generation then resolves it automatically instead of every shot needing the right `character_ref` passed by hand. Check whether your Studio has it: `get_production_context` returns a `lookBindings` key once it does.

Hair state (up/down/wet) and condition (bruised, soaked, dusty) are *not* costume changes and should not consume a wardrobe variant name. There is currently no field for them — see the state limitation below.

### Scale sheets

When relative height matters (adult/child, human/creature), render one `SCALING_SHEET` element with the cast side by side at true relative height against a gridded or plain background. Retrieve it with `studio_list_references({ projectId, type: "SCALING_SHEET" })` and feed it as a reference on any shot with both characters in frame.

Cheaper alternative for a single character: set `metadata.scalingLabel` on the reference (via `studio_update_element` — `update_reference` has no `metadata` param). Either mechanism causes scale constraints to be injected into generation prompts; neither one present means the model picks relative heights freshly in every shot.

## Location variant and camera-view packs

Text first, images second. Derive the location configurations from sluglines, action, blocking, and planned camera zones. The same canonical place may need variants such as `exterior`, `interior-living-room`, `interior-hallway`, or script-specific area configurations. The name is a production choice constrained by `variantPolicy`; do not force every project into the same location taxonomy.

Each location variant holds a set of **camera-view looks** as its labeled `images`. For example, `interior-living-room` may contain `entry-wide`, `sofa-to-dining`, `dining-to-balcony`, and `balcony-reverse`. These image labels are camera positions and views; the parent variant names the space/configuration. An initial single location image covers only the matching view row.

Text first, image second. Record the place-wide spatial truth in the location sheet fields below; index each view's orientation record by the exact image label. When a location configuration needs independent spatial details or reuse, use a separate LOCATION reference as described in [variant-view-matrix.md](references/variant-view-matrix.md).

```
LOCATION PACK — THE HOUSE / interior-living-room
Views: entry-wide ([Image 1]), sofa-to-dining ([Image 2]), dining-to-balcony (needed)

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

- **`Depth & axes` prevents crossing the line.** Name the long axis and which direction each reference image looks along it, and left/right stays stable between a wide and a reverse. Keep shared architecture, access points, landmarks, and palette consistent across variants unless the screenplay calls for a change.
- Add an orientation record for every attached view: `view`,
  `camera-position`, `facing-direction`, `screen-left-world`,
  `screen-right-world`, and visible `landmarks`. `world-left/right` stays
  fixed; camera-left/right changes when the camera reverses. A top, bottom,
  overhead, underslung, reverse, or detail view is conditional on the shot
  plan, not a mandatory checklist for every location.
- Derive `required-views` separately for every required location variant from planned camera zones and include an
  opposite-axis/reverse view whenever the episode crosses or approaches the
  established line. Pass this orientation record to `image-location` before
  approving the location.
- Every element named here in CAPS becomes a prop-continuity token for Step 02.
- Evaluate each required variant as its own `image-location` pack with at least two image views, a `location-reference` anchor, and explicit `reference-coverage` metadata. Map each evaluation alias to the exact variant and image label. Use an approved anchor from the same configuration when available; otherwise use a representative staged candidate only if the live evaluation contract accepts its URL as the evaluation-only `location-reference`. Never substitute another configuration's image for the anchor. Missing view/configuration coverage is blocking; do not substitute a different variant's image silently.
- No reference image → header gets `(TEXT-ONLY)`, unknown fields get `UNKNOWN`. Do not fill `Layout: UNKNOWN` with a plausible invention; the audit needs to know it is unverified.

### Location position guides

For every location variant/view used to stage people, make a position-guide copy before generating its scene anchor. Draw a differently colored bounding box for each character position and include a name/role legend. Use translucent fills (about 20–35% opacity), not solid fills, so the underlying layout remains visible. Preserve the unmarked location image as the clean appearance reference; use the marked copy as a spatial input for relative position and scale. The overlay is a guide, not set dressing.

If no location image exists, first select or generate the location view, then make the guide before anchor generation. Record the positions, axes, and entry points in the location sheet as well, so the spatial plan survives outside the image.

### Persisting the sheet

The sheet has real fields, not prose blobs — map the six sheet fields onto `locationDetails` (`spatialLayout`, `accessPoints`, `keyLandmarks`, `depthAxes`, `lightSources`, `surfaces`/`palette`, …). Write straight into `locationDetails`/`characterDetails`; the shared prompt-projection table reads them directly, no top-level `metadata` mirroring needed on a current Studio.

Full field-mapping table, a worked `studio_update_reference` call, and the older-Studio metadata-mirroring fallback: `references/location-fields.md`.

### Location variant selection

Location variants use the same generic storage mechanism as character looks, but their meaning differs: a location variant names the script-relevant space/configuration; its images are camera-view looks. Time, weather, or lighting can define another configuration when the screenplay requires it, with its own required view rows:

```
referenceVariants: [
  { name: "interior-living-room", kind: "primary", isDefault: true,
    images: [
      { url: entryWide, label: "entry-wide", isPrimary: true },
      { url: sofaReverse, label: "sofa-reverse" }
    ]
  },
  { name: "exterior-rain", kind: "look",
    images: [
      { url: frontWideRain, label: "front-establishing", isPrimary: true },
      { url: doorReverseRain, label: "door-reverse" }
    ]
  }
]
```

Names must sit in `variantVocabulary.LOCATION` when the project is `closed`. Build a required variant × view matrix before rendering anchors. Each shot must select its intended location configuration and camera view explicitly; in `mixio-generate`, pass the selected `variantId` or `variantName` with the location media reference and preserve its `@` mention pair. Do not rely on a location `lookRef` cascade unless `get_production_context` confirms `lookBindings` and the Studio relation contract supports that owner.

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

#### Mandatory cast and staging preflight

Before anchor generation, build a scene-by-scene cast ledger from the accepted shot plan and screenplay, then cross-check it against every planned shot and `appears_in` relation in the episode. Include each distinct character who appears later in the scene, including brief/special appearances, story-relevant background roles, entrances from off-screen, exits, and returns. Cross-check the full episode roster so every character is mapped to their scenes and later anchors are planned. Resolve aliases to canonical character references; if screenplay, accepted plan, and relations disagree, surface the exact discrepancy before rendering.

For each character, record whether they are present at scene opening or enter later, their first shot, any special entrance/appearance condition, opening position when present, and later position/entry route. Distinct characters get distinct character references and visibly distinct faces; reuse a face only when the screenplay explicitly calls for the same identity or an intentional duplicate role/double. Put each person in a differently colored, translucent box on the location position guide with a legend. Mark later entrants' reserved positions/entry routes as **later entry**; do not place them visibly in the opening anchor early.

Keep the ledger in the pipeline working record and persist it under `metadata.pipeline.reference_audit.anchor_cast_ledger`. Each scene row must list the canonical character/reference, source shot IDs or screenplay entrance cue, opening presence, first entrance and special condition, guide color/position, and whether the anchor/face check was visually reviewed. The reference auditor reconstructs this matrix from the accepted plan, screenplay, and relations if it is missing, and reports any disagreement rather than assuming the saved ledger is current.

The opening anchor must show every character present at scene opening, no character whose entrance is later, and no unscripted person. Check each face against its character sheet and against the other visible faces. After accepting the clean anchor, make a matching annotated anchor-guide copy with translucent boxes around the people actually visible and the same legend. Keep both: use the clean anchor for scene appearance and the annotated anchor guide as a spatial input for later multi-person shots.

- Render at `anchor_aspect_ratio` (wider than delivery — `16:9` when delivering `9:16`). The extra horizontal information is the point: shots crop *into* a known space instead of each inventing its own.
- Include: full set with the CAPS key elements visible, every character present at scene start in the accepted cast ledger's position/facing/posture, and the scene's light direction and shadow length.
- Exclude: dramatic framing, mid-scene action, anything that only happens later. An anchor is a reference, not a shot.
- Feed the marked location position guide, clean location image, and character sheets for the scene-opening cast into the anchor job. Later entrants' sheets may be used when preparing later coverage, but must not cause them to appear early in the opening anchor.
- A scene with a big lighting or staging shift mid-way (day→night, everyone relocates) needs a second anchor. Note the switch shot in the staging block: `Coverage: Shots 1–10 → Anchor 1; Shots 11–18 → Anchor 2`.

Persist the anchor candidate as an IMAGE or KEYFRAME element with a usable image URL. Frames View loads scene anchor candidates from elements related directly to the scene and classifies KEYFRAME/IMAGE items as reference frames when they have relation type `source_reference_for`, subtype `STORYBOARD_REFERENCE`, `frameRole: "storyboard_reference"`, `storyboardRole: "source_reference"`, or `isGenerated: false`. `metadata.kind: "anchor"` by itself is not a Frames View classifier. The canonical `scene.metadata.anchorRef` field has a separate purpose: it makes generation attach the selected anchor to shots in that scene. Do not assume setting `anchorRef` alone makes an unattached element visible in the scene lane.

The Frames UI’s approval flow attaches an approved scene anchor to each shot with a `source_reference_for` relation from the shot to the anchor, tagged with role and metadata source `scene_anchor`. For a candidate to appear in the scene Anchor lane, attach it directly to the scene using the supported scene relation mechanism and a recognized reference-frame marker, then read back the scene-related items. For generation, the UI approval/materialization flow sets `scene.metadata.anchorRef` and creates the tagged shot-to-anchor relations. Confirm the exact relation primitive and schema with `studio_describe_tools`; never guess a relation direction or role. In all cases, verify the persisted element, marker, relation owner/target, and `anchorRef` as applicable.

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

Bind each anchor mention in the public `mentionMap` to its exact URL in `input.media`. `slotReferences` can be omitted unless you need to override derived reference metadata or element links.

```json
{
  "mentionMap": {
    "@scene1": "https://studio.mixio.pro/api/media/file/scene1_anchor.png",
    "@tony": "https://studio.mixio.pro/api/media/file/tony_ref.png"
  }
}
```
And embed in the prompt:
`"@tony sits at the edge of the bed under @scene1 lighting and layout, looking up toward the doorway."`

Without the `@scene1` token in the prompt and URL-valued `mentionMap` binding, provider compilers cannot map the anchor to model tokens (`Image 2`, `@Element1`), causing the model to ignore the spatial truth and invent arbitrary room geometry.

## Workflow

```
1. read the accepted shot plan and source → characters, canonical places, required looks, location configurations/views, camera zones, and story-critical props; build a scene-by-scene cast ledger cross-checked against every planned shot and `appears_in` relation, including special appearances and entrance/exit conditions
2. studio_get_project({ projectId }) → reference policies and allowed variant names
3. studio_list_references({ projectId }) → existing entities, variants, and approved images
4. build the variant × view matrix; map supplied images to exact rows; show gaps and confirm the grouping/render round in chat (prior authorization for the same scope is enough)
5. register only policy-permitted canonical references; enrich character identity and place-wide location details
6. render missing candidates outside the active reference; evaluate each character/location pack and retain the receipt + feedback
7. apply the candidate review checkpoint in `mixio-references`; show candidates and request the user's chat decision
8. attach only user-selected images; read back the reference and verify rejected media is absent from active stores
9. present the separate scene-anchor render round; create a differently colored, translucent location position guide for each multi-person scene, then render per-scene anchors with the selected location configuration and only the scene-opening character variants on confirmation or prior authorization
10. check anchor cast, special/later entrances, and distinct faces against the ledger; make a matching annotated anchor-guide copy for later multi-person shots; show clean anchors and annotated guides as a checkpoint. If the user accepts incomplete packs/anchors, continue to Step 05 with limitations recorded when schema and project policy allow
```

Persist the confirmed matrix and each row's confirmation, media status, evaluation run IDs,
feedback, and human decision in the existing episode `metadata.pipeline.reference_pack_inventory`
free-form metadata. Step 04 checks the actual shot camera zones and required views against the same inventory; repeat the audit after any approved reference change.

## Notes

- Sheets are the cheapest place to fix a look. Re-rendering one sheet is one job; re-rendering the 12 shots that referenced a wrong sheet is twelve.
- Wrong images already attached? Remove rejected media from the active reference stores and rebuild `referenceVariants` from approved images only. `attachments` merges; `referenceVariants` replaces. Read back `referenceVariants`, legacy `characterDetails.looks`, flat `attachments`, and `thumbnailUrl`/`previewUrl` before continuing. See `mixio-references`.
- External URLs (Drive, Dropbox, third-party CDNs) frequently fail through `studio_upload_media_from_url` with `No files were uploaded`. Use the single [safe external-media recipe](../mixio-workspace/SKILL.md#ingest-external-media-urls-google-drive-cdns-third-party-hosts), then `upload_file({ path: asset_path, project_id, organization_id })` and update the reference/slot with `entry.publicUrl`.
- Set `workflow.status` honestly (`draft` → `in_review` → `approved`) from the user's chat decision and persisted readback; do not require a separate Studio approval action. Record incomplete or unselected variants/views as readiness findings, and continue on the user's accepted direction when technically and policy compatible.
