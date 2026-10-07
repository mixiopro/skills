# Prompt & Mention Sheet

Provenance: pairing rules and universal invariants come from the AGENTS.md "Mandatory
prompt `@` mentions" contract and `mixio-shot-planning`'s Prompt mention validation;
per-route token grammars come from `studio_get_use_case_input_schema` route compilers and
the model catalogs as recorded in `model-comparison.md`. Live Studio schemas always
override this file.

The sheet is the pre-submit artifact for one job: one table pairing every media asset
with the `@tag` embedded in the prompt, the human label behind that tag, and the token
each routed provider will compile it to. Step 06's gate validates the **job** against
the **sheet** — if they disagree, fix the job, not the sheet, unless the plan changed.

## Pairing table

Fill one row per asset in `input.media` (every schema-declared slot: `primary`,
`endFrame`, `references`, `character_ref`, `location_ref`, `style_ref`, `asset_ref`,
`clothing_ref`, `image_urls`, `motionRef`, `audioRef`, `enhancer_context`, …):

| Studio reference identity key (`slotTags` key) | `input.media` source | `@tag` | mentionMap label | compiled token (routed model) | where the tag appears in the prompt |
|---|---|---|---|---|---|
| `sceneAnchorId` | `image_urls[0]` | `@scene1` | Scene 1 kitchen wide / approved view cam-a | H3: semantic tag (compiler-mapped) | context + shot plan |
| `tonyId` | `image_urls[1]` | `@tony` | Tony / `tony.v2.suit` | H3: semantic tag | subject |
| `watchId` | `image_urls[2]` | `@watch` | Tony's watch (prop) | H3: semantic tag | subject |

`slotTags` is keyed by Studio's reference identity key, not the `input.media` slot name or
array index. Use `selectedElements.identityKey` when one is supplied; for URL-only media with no
identity key, use the exact URL string as the key. `slotReferences` is keyed by media slot and
does not change the `slotTags` key format. Do not guess a key from `primary` or `references[0]`.

Rules (all blocking):

- **One-to-one coverage both ways.** Every asset has exactly one `slotTags` entry; every
  `@tag` key in `mentionMap` has a non-empty label; no tag maps to two assets; no
  `mentionMap` entry with no asset (orphan).
- **The tag must literally occur in the effective prompt** — zero occurrences fails
  `PROMPT_MENTION_MISSING`. A tag used only in `sequence_notes`/prose without the `@`
  form does not count.
- **Labels are human-readable and non-empty** — "Tony / tony.v2.suit", not "ref1".
- Never hand-author provider tokens (`Image 1`, `@Image1`, `<IMAGE_REF_1>`) in the
  authored prompt; those are compiler output. The compiled-token column records what
  the compiler will emit so the reviewer can check grounding without knowing the
  authoring rule per model.

## Route token table

| Route / model family | Tag form authored | Compiled to | Caps |
|---|---|---|---|
| H3 Ref2Vid `hailuo_v3_reference_to_video` (`multi-shot-video`) | semantic `@tag` | `<Picture N>` / `<Video N>` / `<Audio N>` by backend upload order | no Mixio prompt ceiling; media image ≤9, video ≤3, audio ≤3 |
| Seedance `seedance_reference_to_video_v2` | semantic `@tag` | `@Image{n}` / `@Video{n}` / `@Audio{n}` | 3–15s |
| Kling `kling_o3_standard_reference_to_video` / `_pro_` | semantic `@tag` | `@Element{n}` / `@Image{n}`; audio `<<<voice_{n}>>>` | ≤2 voice tokens; references cap 4 |
| Gemini `gemini_omni_multishot` | semantic `@tag` | `<IMAGE_REF_{n}>` / `@Image{n}` | ≤9 image refs; 3–10s; 16:9 / 9:16 only |
| Production keyframe/image jobs (`gemini_image`, `seedream_*`, …) | semantic `@tag` | compiler-mapped per route | read schema per model |

## Multi-cut cut-line grammar (H3 six-section composer)

For a `MULTI_CUT` shot, place one cut line per `cuts[]` member inside
`detailed_description`, in cut order. Preserve every populated field; do not reduce the saved
direction to just framing and action:

```
[Shot 1] {shot_type}; angle: {camera_angle}; lens: {lens}; camera: {camera_movement}; action: {action}; blocking: {blocking}; dialogue: {audio.dialogue}; SFX: {audio.sfx}; ambient: {audio.ambient}
[Shot {cut_index}] At MM:SS.mmm {shot_type}; angle: {camera_angle}; lens: {lens}; camera: {camera_movement}; action: {action}; blocking: {blocking}; dialogue: {audio.dialogue}; SFX: {audio.sfx}; ambient: {audio.ambient}
```

`[Shot 1]` has no timestamp. Every later header uses the cumulative start time from the sum of
preceding `cuts[].duration` values (`MM:SS.mmm`). Omit an optional label when that field is
absent; never omit or shorten a populated camera, blocking, action, or audio value. Keep all
`@tag`s in the effective prompt. Seedance, Kling, and Gemini multi-cut prompts express the same
complete cut details as plain prose rather than H3's bracketed shot headers.

## Worked example (12s MULTI_CUT, H3)

```
slotTags   { [sceneAnchorId]: "@scene1", [tonyId]: "@tony", [watchId]: "@watch" }
mentionMap {
  "@scene1": "Scene 1 kitchen wide / approved view cam-a",
  "@tony":   "Tony / tony.v2.suit",
  "@watch":  "Tony's watch (prop)"
}

prompt (six exact H3 sections; abbreviated example):
subject_definitions
<Subject 1> Tony, an adult man matching @tony; <Subject 2> a wristwatch matching @watch; <Subject 3> the kitchen matching @scene1.

summary
[reference generation] A 12-second, three-cut kitchen action with Tony and the watch.

retention_analysis
<Subject 1>: fully_preserved; <Subject 2>: fully_preserved; <Subject 3>: fully_preserved.

detailed_description
Keep the same Tony, watch, and kitchen identity. [Shot 1] MS; angle: eye-level; lens: 35mm; camera: slow lateral track; action: @tony enters and checks @watch; blocking: @tony in MG, counter in FG; dialogue: none; SFX: quiet footsteps; ambient: kitchen room tone. [Shot 2] At 00:06.500 CU; angle: top-down; lens: 50mm; camera: locked-off; action: @watch fills frame as @tony's hand stops; blocking: watch in FG; dialogue: none; SFX: strap click; ambient: kitchen room tone. [Shot 3] At 00:10.000 WS; angle: eye-level; lens: 35mm; camera: slow pull-back; action: @tony turns toward @scene1; blocking: @tony in MG, kitchen in BG; dialogue: none; SFX: none; ambient: kitchen room tone.

overall_soundscape
Quiet kitchen room tone, soft footsteps, one clear strap click.

non_diegetic_music
N/A.
```

Before submitting, run the sheet through the same checks as
`mixio-shot-planning`'s mention validation: coverage both ways, tag occurrence in the
effective prompt, non-empty labels, no duplicate assignment. Any failure is a blocking
finding and the job is not submitted.
