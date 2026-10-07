# Reference Pull List

Provenance: every column derives from live reads — `studio_get_production_context`
(`lookBindings`), `metadata.pipeline.reference_pack_inventory` (Step 02 approval state),
the persisted shot plan (selected variant/view per shot), and `studio_list_references` /
`studio_get_element` (exact image URLs). Live Studio schemas always override this file.

The Reference Pull List is the concrete, per-episode extraction of the Reference readiness
and Look-binding readiness checks: one row per (shot × media slot × entity selection) that
Step 06 must attach to a job. If a row is absent or unresolved, the shot does not go to
generation — that is what `REFERENCE_VARIANT_VIEW_NOT_READY` means in the audit report.

## Build procedure

1. Read the persisted plan (Step 05 output) for every shot's selected character
   `variantId`/`variantName`, location configuration + camera-view label, and prop/style
   selections.
2. Resolve each selection against `metadata.pipeline.reference_pack_inventory`: only
   `approved` rows qualify. `proposed`/`rejected` rows are not pullable.
3. Pull bindings once via `studio_get_production_context`'s `lookBindings`; do not
   re-query per shot.
4. For each approved row, fetch the concrete image URL with `studio_get_element` (or the
   inventory's recorded URL when it is still confirmed current).
5. Reserve the `@tag` the shot's prompt will use for that asset — the same tag that lands
   in `slotTags`/`mentionMap` (see `mixio-generate`'s prompt-mention-sheet.md).

## Row format

| shot | entity | kind | variant / view | approved image URL | elementId / mediaId | `@tag` | source |
|---|---|---|---|---|---|---|---|
| `7.1` | TONY | character look | `variant: tony.v2.suit` | `https://…/tony_suit_front.png` | `el_…` / `md_…` | `@tony` | lookBindings + inventory |
| `7.1` | KITCHEN | location view | `config: kitchen.renovated` / view `cam-a` | `https://…/kitchen_cam-a.png` | `el_…` | `@kitchen` | inventory (camera view) |
| `7.1` | WATCH | prop | `default` | `https://…/watch.png` | `el_…` | `@watch` | inventory |

Rules:

- **One row per selection the shot actually uses.** A MULTI_CUT shot lists the union of
  its cuts' participants; a selection used only in cut 3 still needs one row.
- **A location camera angle is resolved through the location's labeled view pack, never
  through a character-style `lookRef`.** If the shot's camera zone has no matching labeled
  view, the row is written with status `MISSING` and the shot stays blocked until Step 02
  generates and approves it.
- **URLs are per-variant, not per-entity.** The default look does not stand in for a
  required variant; a stale URL (element replaced since inventory write) is re-pulled from
  `studio_get_element`, not reused from memory.
- The list is regenerated after any Step 01 ↔ 02.5 ↔ 04 correction that changes a
  selection — persisted plans are stale the moment a variant mapping changes.

## Gate use

- Step 05's Reference readiness check consumes this list: any `MISSING`, unapproved, or
  ambiguous row is a blocking `REFERENCE_VARIANT_VIEW_NOT_READY` finding, and planning
  stops before Step 05's batch output is handed to Step 06.
- Step 06's pre-submit gate consumes it again: every asset in `input.media` must match a
  row (same URL/elementId), and every row's `@tag` must appear in the prompt with its
  paired `mentionMap` label.
