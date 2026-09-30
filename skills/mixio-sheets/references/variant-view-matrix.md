# Character and location variant/view matrix

`referenceVariants` is a generic container. Choose variant meaning from the entity and the script; do not apply character costume rules to locations.

## Character reference packs

- Keep one canonical CHARACTER reference for the person. Its approved character sheet is the default when a shot does not select a variant.
- If the user supplied only a portrait or single pose and no approved character sheet exists, map that image as identity guidance and add the default turnaround sheet to the inventory as a required pack before clothing/age variants.
- Add a named character variant for each script-required age or clothing combination. Generate only combinations used by the screenplay; do not expand an age-by-wardrobe Cartesian product.
- A one-off hair, injury, wetness, emotion, or carried-prop change remains per-appearance state unless the production needs an approved image variant to make that change visually reliable.
- Each needed character variant gets the turnaround views required for the production and is evaluated as an ordered pack with `image-character`.

## Location reference packs

For locations, a variant names a script-relevant spatial or environmental configuration, and its `images` are the camera-view looks for that configuration. Names are project-specific, subject to `variantPolicy` and `variantVocabulary`.

| Reference | Variant/configuration | Example image labels (camera looks) |
|---|---|---|
| `THE HOUSE` | `exterior` | `front-establishing`, `front-door-reverse` |
| `THE HOUSE` | `interior-living-room` | `entry-wide`, `sofa-to-dining`, `dining-to-balcony`, `balcony-reverse` |
| `THE HOUSE` | `interior-hallway` | `living-room-doorway`, `front-door-axis` |

Use one place reference with variants when the script treats configurations as parts or states of the same canonical place and each shot can select the relevant configuration. Use separate LOCATION references when places need independent identity, metadata, or reuse. Keep that grouping scenario-driven; a room, indoor/outdoor distinction, or named area is not automatically a separate reference or automatically a variant.

Each image label must map to one orientation record using the existing location-sheet vocabulary: camera position, facing direction, screen-left/right world landmarks, and visible landmarks. Keep world axes and stable landmarks consistent across views and variants; record intended changes in the inventory. `image-location` requires at least two image views per evaluated pack; if the script needs only one, add only the minimum second view required by that gate.

## Required-pack inventory

Before rendering, keep a reviewable matrix with one row per required variant/view pair:

| Entity | Variant/configuration | Required view | Existing image | Action |
|---|---|---|---|---|
| Character or location | Exact permitted variant name | Exact image/view label | Supplied or existing asset, otherwise none | Reuse, generate, or ask |

Derive initial rows from screenplay scenes, blocking, and stated camera directions. Map a supplied image to the row it actually covers; one image may cover multiple rows only when its framing proves that coverage. Ask about ambiguous ages, clothing combinations, spatial groupings, or geography instead of filling gaps by invention. Present the completed matrix and missing candidate list for confirmation before the first billable reference render.

For CHARACTER rows, record the screenplay cue and the exact `appearanceState.wardrobe` and/or age value that the approved variant represents, plus its affected scenes. If a prose cue cannot be mapped to one variant with confidence, ask the user to confirm the mapping. This explicit association is what breakdown uses to bind an appearance to a non-default variant; do not infer a `lookRef` from approximate string similarity. Add shot IDs to the row after Step 03 creates them.

Persist the confirmed matrix in the existing free-form episode
`metadata.pipeline.reference_pack_inventory`. Keep each row's reference and
variant identifiers, image label, camera orientation, applicable shot IDs,
character appearance mapping where applicable, source media URL/ID, status,
evaluator run IDs, feedback, and human decision.
Use the row statuses `proposed`, `confirmed`, `candidate`, `evaluated`,
`approved`, `rejected`, and `blocked`; return a retry row to `confirmed` only
after the user confirms that retry round. Update this same record on each
confirmed retry; do not store candidates in active reference images to make the
review resumable.

## Candidate approval and retry

Use the shared candidate approval and retry gate in `mixio-references`. Keep generated candidates outside active references until the applicable evaluator has run and the user approves them. Retain findings, evidence aliases, actionable repair feedback, and the human decision in the inventory row; evaluation is advisory and never approves a candidate on the user's behalf.

For a new location configuration with no approved image to anchor evaluation,
use a representative staged candidate as the temporary `location-reference`
only when the live evaluation contract accepts it; compare all candidate views
to the confirmed orientation records and landmarks. Do not use a different
configuration as an anchor. If no permitted anchor is available, keep the pack
blocked and request a suitable source image.

After approval, attach only accepted media and read the reference back. If a rejected candidate was already attached, remove it from every active look store and clear it from `thumbnailUrl`/`previewUrl` if it is still shown as the card image; see `mixio-references` for replacement and legacy-data checks. A failed readback blocks downstream shot generation.
