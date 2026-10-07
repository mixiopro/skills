# Reference Media Selection

This is a lookup guide for selecting approved reference media. The live tool and generation
contracts define the current slots and fields; follow them when they differ from this snapshot.

## Character looks

A CHARACTER shot may bind one of its approved looks (`referenceVariants`) via `lookRef` on its
`appears_in`/`presence` relation. When supported by Studio, generation resolves the look in
shot → scene → reference-default order. Check `studio_get_production_context` for a
`lookBindings` entry or `studio_query_relations` for relation `metadata.lookRef`; do not assume
the default image matches a non-default shot binding.

To pass the chosen look explicitly, use its exact approved attachment URL and include the
matching variant identifier/name on the schema-declared media or `slotReferences` entry. Pass
the matching graph reference in `selectedElements` when the server should resolve the bound
look. A URL-only reference with no graph identity cannot resolve a shot/scene binding. Values
are a snapshot when submitted; a later rebind does not alter a running job.

## Location views

Select the screenplay-confirmed location configuration and exact labeled camera-view image from
the Step 02 inventory. A location variant names a configuration such as exterior, living room,
or hallway; the image label identifies the view within that configuration. Character `lookRef`
bindings do not select a location camera angle. If the active contract cannot declare a location
variant, pass the exact approved view URL and retain the configuration/view in the shot plan.
Never infer a view from array order or submit a proposed/rejected candidate.

## URL resolution

Media slots accept real URLs, not Payload media IDs. Resolve them in this order:

1. `studio_list_references({ projectId })` returns names, types, and `hasAttachments`, but not URLs.
2. `studio_get_element({ elementId })` returns `referenceVariants[].attachments[].media.url`;
   use it for known references. `studio_get_production_context({ projectId, episodeId })` is
   the larger whole-graph alternative.
3. For local files, use `upload_file` or `get_public_url` to obtain a permanent URL.
4. For external URLs, use `mixio-workspace`'s validated download-and-upload fallback. Do not
   pass third-party URLs directly to generation slots.

If media is present, each selected asset still needs its exact reference identity key in
`slotTags`, a human-readable `mentionMap` label, and an authored `@tag` in the effective prompt.
The [Prompt & Mention Sheet](prompt-mention-sheet.md) defines the key and token pairing.
