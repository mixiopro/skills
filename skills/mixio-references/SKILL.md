---
name: mixio-references
description: "Manage a Mixio Studio project's Cast & World roster — characters, locations, and props, including reference images (Looks) and structured details used for generation consistency."
version: 0.2.0
invoke: /mixio:references
---

# Mixio References (Cast & World)

Characters, locations, and props are project-scoped reference elements. Their images and structured details (wardrobe, voice, setting, lighting, etc.) are what `mixio-generate` pulls into `character_ref`/`location_ref`/`style_ref` slots for consistent generation. This is the highest-traffic tool family in real usage, and its write semantics have a sharp edge — read the gotchas below before calling.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- **Resolved scope — required.** You must be working against a project that the user has
  explicitly confirmed. If it is not established in this session, **fetch the list and show
  it, numbered, in the same message as the question** (`studio_list_projects` /
  `studio_list_episodes`) so the answer is one character. Asking "which episode?" without
  the list is a failure — it hands the lookup back to the user. Resolve this *before* any
  expensive read; never guess an id, infer one from a title, or create something to avoid
  asking. See `mixio-project`.

## MCP Tools

All proxied `studio_*` tools.

| Tool | Purpose |
|------|---------|
| `studio_register_reference_entities` | Bulk create-or-update characters/locations/props by name (idempotent — matches on normalized name within the project) |
| `studio_update_reference` | Update one reference element's images and structured details |
| `studio_list_references` | List/search a project's CHARACTER/LOCATION/PROP/SCALING_SHEET elements, including ready-to-copy screenplay `mentionableLooks` |
| `studio_resolve_mention` | Resolve one known mention to its exact element/look/view; use for a specific lookup, not to construct general mention tokens |

## Project reference policy — read this before creating anything

A project can constrain how references and variants are created, at
`projects.settings.references`. Read it with `studio_get_project` **before** you
create a reference or invent a variant name:

| Setting | Values | Meaning |
|---|---|---|
| `createPolicy` | `allow` · `link_only` · `propose` | Whether a breakdown may create references it cannot match. `link_only` means link to existing only; `propose` means surface a proposal instead of writing |
| `aliasMatching` | `true` / `false` | Whether recorded aliases participate in name matching |
| `variantPolicy` | `open` · `closed` | Whether variant names are constrained to the vocabulary |
| `variantVocabulary` | `{ CHARACTER: [...], LOCATION: [...], PROP: [...] }` | Allowed variant ids per type. Absent or empty means unconstrained |

Defaults reproduce pre-configuration behaviour (`allow`, `aliasMatching: false`, `open`, `{}`), so an unset project behaves as it always did. But on a configured project, inventing `"Gala Dress"` under `variantPolicy: closed` with a vocabulary of `['casual','formal']` is off-contract, and creating a new CHARACTER under `createPolicy: link_only` is not yours to do. Studio's own breakdown workflow reads these settings and injects the vocabulary into its prompt — match that behaviour.

**Writing settings is a read-modify-write.** `studio_update_project`'s `updates.settings` is a **replacement** object, not a merge — fetch the current settings, merge your change, send the whole thing back, or you will silently drop every other setting on the project.

### Aliases — how a second episode avoids duplicate references

Matching is by normalized name, so `TONY`, `Tony Russo`, and `Antonia` are three
different references unless aliases are recorded. Aliases are read from any of
these metadata keys (all supported, de-duplicated):

```
aliases   alternateNames   altNames   referenceAliases   keywords   alias
customAttributes: [{ key: "alias"|..., value }]
```

`studio_update_reference` has **no `metadata` parameter** (its params are
`name`, `description`, `characterDetails`, `locationDetails`, `propDetails`,
`attachments`, `referenceVariants`, `tags`, `workflow`), so aliases go in
through the generic element tool, which merges metadata:

```
studio_update_element({ elementId: referenceId, updates: { metadata: {
  aliases: ["Tony Russo", "Antonia", "Ton"]
}}})
```

Or at creation time via `studio_register_reference_entities`, which does take
`metadata`. Aliases only affect matching when `aliasMatching: true`; record them
regardless, since the setting can be turned on later and the data will be there.

**Query filters must be native objects, not stringified JSON.** `studio_query_elements` (`tags`, `metadata`) and `studio_query_relations` (`metadata`) take real objects; the server iterates filters with `Object.entries()`, which walks a JSON string character-by-character and fails with `Tool execution failed: { is not allowed as a JSON query value`. Pass `tags: { episodeId: "..." }` / `metadata: { ... }` as objects, never `JSON.stringify(...)` output.

### `studio_update_reference` — the critical gotcha: `attachments` vs `referenceVariants`

Both parameters put images on a reference, but they are **not interchangeable**:

- **`attachments`** (array of `{ url, label?, isPrimary? }`) — **additive**. Merges new images into the existing default look. Use for adding more angles/images to what's already there.
- **`referenceVariants`** (array of `{ name, kind?, isDefault?, images: [{url, label?, isPrimary?}] }`) — **full replace** of the entire variant list. Use when images are wrong and you need to overwrite, or when you're defining multiple named looks (e.g. `"Default Look"` + `"Battle Armor"`).

`kind` is a closed set: **`primary`** (the identity reference — one per element), **`look`** (a costume/state variant), **`reference`** (a supporting image that is neither). Omitting it defaults to `look` on a variant and `primary` on the first entry. Variant `name` must sit inside `variantVocabulary` when the project sets `variantPolicy: closed` — see the policy section above.

**Variants are read from three historical locations**, so a reference created by an older surface may hold its looks somewhere you don't expect: `referenceVariants` (current), `characterDetails.looks` (legacy character path), and `attachments` (flat, pre-variant). When you need the full set of looks on an existing reference, check all three — writing only `referenceVariants` does not migrate the other two.

Internally, `attachments` is sugar that auto-builds/merges into a `"default"` `referenceVariants` entry — so mixing both in one call is redundant; pass one or the other. **Do not use `thumbnailUrl`** to set look images — it only changes the card preview, it does not create look variants the Cast & World UI reads.

```
// Add images (merges with whatever's already there)
studio_update_reference({
  referenceId, attachments: [{ url, label: "Front", isPrimary: true }, { url, label: "Back" }]
})

// Replace all images / define named looks (wrong images already attached → fix with this, not attachments)
studio_update_reference({
  referenceId,
  referenceVariants: [{ name: "Default Look", isDefault: true, images: [{ url, isPrimary: true }] }]
})
```

### Binding a look — how a shot or scene selects one

Defining looks here is half the contract; a shot or scene has to *select* one for generation to render it instead of the default. That's a relation write, not a reference write: set `lookRef` (aliases `look`, `look_ref`, `variant`) in the `metadata` of the shot's or scene's `appears_in`/`presence` relation, pointing at a `referenceVariants[].id` or `.name` on this reference. See `mixio-script-breakdown` for the appearance-state contract and `mixio-generate` for how a job declares or inherits the binding.

Resolution order at generation time is shot → scene → this reference's default variant, where the cascade is live — check for a `lookBindings` key in `get_production_context`'s response to confirm it is. A `lookRef` that no longer matches any variant — renamed, deleted — degrades silently to the default rather than erroring, so a rename here is a breaking change for anything that bound the old name.

Structured detail params (type-gated — sent fields are ignored if the element isn't that type, and are deep-merged, not replaced):
- `characterDetails` (CHARACTER only): `role`, `age`, `personality`, `build`, `skin`, `hair`, `distinctiveFeatures`, `visualAnchor`, `wardrobeNotes`, `bio`, `backstory`, `motivations`, `speechStyle`, `relationshipsSummary`, `castingNotes`, `voiceProfile`, `voiceReference`, `voiceRegistrations`
- `locationDetails` (LOCATION only): `setting`, `timePeriod`, `mood`, `lighting`, `palette`
- `propDetails` (PROP only): `category`, `material`, `significance`
- `workflow.status`: `draft` | `in_review` | `approved` | `rejected` | `archived`

### Relative scale

Two mechanisms, both read by prompt assembly (`buildScalingConstraintPrompt`):

- **`metadata.scalingLabel`** (or `metadata.attributes.scalingLabel`) — a short label on an individual reference, e.g. `"6'2\" adult male"`. Write via `studio_update_element`, since `update_reference` has no `metadata` param.
- **A `SCALING_SHEET` element** with `metadata.entities` — one image showing several references at true relative height. Retrieve with `studio_list_references({ projectId, type: "SCALING_SHEET" })`.

Either one present causes scale constraints to be injected into generation prompts. Without them, a model will render an adult and a child at whatever relative height it likes, differently in every shot.

Response is terse: `{ id, name, type, action: "updated" }` — not the full object, unlike most other `studio_update_*` tools.

### `studio_register_reference_entities`

Bulk upsert by name — matches an existing element by `project + type + normalizedName`; creates if none found.

```
{ projectId, references: [{ type: "CHARACTER"|"LOCATION"|"PROP"|"REFERENCE", name, subtype?, episodeId?, imageUrl?, imageUrls?, metadata?, tags? }] }
→ { registered: [{ id, type, name, action: "created"|"updated" }] }
```

`imageUrl`/`imageUrls` go through the same `referenceVariants`-merge path as `update_reference`'s `attachments` — additive, first image becomes primary.

### `studio_list_references`

```
{ projectId, type?: "CHARACTER"|"LOCATION"|"PROP"|"SCALING_SHEET", search?, limit? }
→ { references: [{ id, name, type, description, workflow, characterDetails|locationDetails|propDetails, hasImage, hasAttachments, hasReferenceVariants, mentionableLooks, thumbnailUrl, previewUrl, updatedAt }], total }
```

Use `mentionableLooks` as the authoritative screenplay-mention catalog. Each look exposes its ready-to-copy `mention` (`#name.variant`) and any distinct view mentions (`#name.variant.view`). Copy the returned string exactly rather than constructing or dot-joining a display name; multi-word names are normalized as one hyphenated root segment. An empty `views` array is normal for agent-authored looks—the two-segment look `mention` is then complete. Read the [native screenplay grammar](../mixio-episode/references/screenplay-grammar.md) for the full `#` contract, locks, and annotations; use `studio_resolve_mention` only when you need to resolve one existing token to its specific media.

Use this to **get real reference-image URLs** before calling `studio_submit_studio_job` — that tool rejects raw media IDs in `input.media` slots and requires actual URLs, which live in each reference's `referenceVariants[].attachments[].media.url` (not surfaced directly in this list response — call `studio_get_element`/`studio_get_production_context` for the full metadata if you need the raw variant/attachment URLs, not just this summary view).

**For image *presence* (does this reference have any image at all), trust `hasImage` — not `thumbnailUrl`/`previewUrl`.** `hasImage` is `hasAttachments || hasReferenceVariants`, computed live from `metadata.attachments`/`metadata.referenceVariants`, the actual Look data — check that field directly rather than OR-ing the two yourself. `thumbnailUrl`/`previewUrl` are a separate top-level card-preview column that nothing sets when you attach a Look — a reference with three real turnaround images can still show `thumbnailUrl: null`. Reading those two as a presence signal produces a false "no image" finding on a reference that has one. (`hasAttachments`/`hasReferenceVariants` are still returned individually if you need to know *which* mechanism holds the image — `attachments` is legacy, `referenceVariants` is where new writes land, see above.)

## Getting images onto a reference — the reliable path

**Don't rely on `studio_upload_media_from_url` for external URLs** (Google Drive, etc.) — in real usage it failed on every attempt (`Tool execution failed: No files were uploaded.`), likely SSRF/connectivity restrictions on the server side. The pattern that actually works:

```
1. curl <external-url> -o /tmp/asset.png              → local file
2. upload_file({ path: "/tmp/asset.png" })             → { entry: { url / publicUrl } }  (see mixio-workspace)
3. studio_update_reference({ referenceId, attachments: [{ url: entry.publicUrl, ... }] })
```

`studio_upload_media_from_url` may still work for URLs already on trusted/reachable domains — try it first for a single asset, but don't build a batch workflow around it without a local-download fallback.

## Workflow

```
1. studio_list_references({ projectId, type, limit }) → find existing references and collect exact `mentionableLooks` before authoring a screenplay
2. studio_register_reference_entities({ projectId, references: [...] })   → create/upsert by name
3. upload_file(local_path) → studio_update_reference({ referenceId, attachments/referenceVariants, characterDetails/locationDetails/propDetails })
   → populate images + structured details
4. → mixio-generate: pull reference URLs into character_ref/location_ref/style_ref for consistent generation
```
