---
name: mixio-references
description: "Manage a Mixio Studio project's Cast & World roster — characters, locations, and props, including reference images (Looks) and structured details used for generation consistency."
version: 0.1.0
invoke: /mixio:references
---

# Mixio References (Cast & World)

Characters, locations, and props are project-scoped reference elements. Their images and structured details (wardrobe, voice, setting, lighting, etc.) are what `mixio-generate` pulls into `character_ref`/`location_ref`/`style_ref` slots for consistent generation. This is the highest-traffic tool family in real usage, and its write semantics have a sharp edge — read the gotchas below before calling.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)

## MCP Tools

All proxied `studio_*` tools.

| Tool | Purpose |
|------|---------|
| `studio_register_reference_entities` | Bulk create-or-update characters/locations/props by name (idempotent — matches on normalized name within the project) |
| `studio_update_reference` | Update one reference element's images and structured details |
| `studio_list_references` | List/search a project's CHARACTER/LOCATION/PROP/SCALING_SHEET elements |

### `studio_update_reference` — the critical gotcha: `attachments` vs `referenceVariants`

Both parameters put images on a reference, but they are **not interchangeable**:

- **`attachments`** (array of `{ url, label?, isPrimary? }`) — **additive**. Merges new images into the existing default look. Use for adding more angles/images to what's already there.
- **`referenceVariants`** (array of `{ name, kind?, isDefault?, images: [{url, label?, isPrimary?}] }`) — **full replace** of the entire variant list. Use when images are wrong and you need to overwrite, or when you're defining multiple named looks (e.g. `"Default Look"` + `"Battle Armor"`).

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

Structured detail params (type-gated — sent fields are ignored if the element isn't that type, and are deep-merged, not replaced):
- `characterDetails` (CHARACTER only): `role`, `age`, `personality`, `build`, `skin`, `hair`, `distinctiveFeatures`, `visualAnchor`, `wardrobeNotes`, `bio`, `backstory`, `motivations`, `speechStyle`, `voiceProfile`, `voiceReference`, `voiceRegistrations`
- `locationDetails` (LOCATION only): `setting`, `timePeriod`, `mood`, `lighting`, `palette`
- `propDetails` (PROP only): `category`, `material`, `significance`
- `workflow.status`: `draft` | `in_review` | `approved` | `rejected` | `archived`

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
→ { references: [{ id, name, type, description, workflow, characterDetails|locationDetails|propDetails, hasAttachments, hasReferenceVariants, thumbnailUrl, previewUrl, updatedAt }], total }
```

Use this to **get real reference-image URLs** before calling `studio_submit_studio_job` — that tool rejects raw media IDs in `input.media` slots and requires actual URLs, which live in each reference's `referenceVariants[].attachments[].media.url` (not surfaced directly in this list response — call `studio_get_element`/`studio_get_production_context` for the full metadata if you need the raw variant/attachment URLs, not just this summary view).

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
1. studio_list_references({ projectId, type })        → find existing character/location/prop, or confirm it doesn't exist
2. studio_register_reference_entities({ projectId, references: [...] })   → create/upsert by name
3. upload_file(local_path) → studio_update_reference({ referenceId, attachments/referenceVariants, characterDetails/locationDetails/propDetails })
   → populate images + structured details
4. → mixio-generate: pull reference URLs into character_ref/location_ref/style_ref for consistent generation
```
