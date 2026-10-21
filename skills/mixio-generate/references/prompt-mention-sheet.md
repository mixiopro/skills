# Prompt & Mention Sheet

Provenance: the public MCP binding contract is defined by `AGENTS.md` and the live generation
MCP tool descriptions. Model-specific media slots and provider token grammars come from the live
use-case schema and route catalog; those live sources override this sheet.

Use this as the pre-submit worksheet for one job. It helps verify that each prompt mention is
bound to the right image URL and that the tag appears in the effective prompt. The public MCP
payload has one binding map: `mentionMap` maps `@tag` to the exact URL in that job’s
`input.media`. The MCP adapter derives Studio’s internal `slotTags` and labels. Callers must not
send those internal fields or a separate label map.

## Per-job reference worksheet

Record one row for every reference that the prompt identifies by a mention. The `input.media`
slot and cardinality come from the selected model’s live use-case schema. Use distinct URLs for
distinct references, even if the images depict the same entity.

| Reference / local provenance | `input.media` slot | Exact media URL | `@tag` / `mentionMap` key | Compiled token (routed model) | Where tag appears in prompt |
|---|---|---|---|---|---|
| Scene 1 kitchen wide / approved view cam-a | `image_urls[0]` | `https://.../scene1.png` | `@scene1` | H3: semantic tag (compiler-mapped) | context + shot plan |
| Tony / `tony.v2.suit` | `image_urls[1]` | `https://.../tony.png` | `@tony` | H3: semantic tag | subject |
| Tony’s watch (prop) | `image_urls[2]` | `https://.../watch.png` | `@watch` | H3: semantic tag | subject |

Rules (blocking):

- Every `mentionMap` value must exactly match a URL in this job’s `input.media`.
- URLs must be unique within the job; one URL cannot disambiguate two references.
- Every `mentionMap` key must appear as the exact `@tag` in the effective prompt.
- Reject missing bindings, URL mismatches, duplicate URLs, unused map entries, and prompt tags
  that have no map entry.
- Never send `slotTags` or a human-label map from an MCP caller. The adapter derives internal
  bindings and labels from the URL-valued map, media, and reference metadata.
- Never hand-author provider tokens (`Image 1`, `@Image1`, `<IMAGE_REF_1>`) in the authored
  prompt; those are compiler output. The compiled-token column is for review only.

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
input.media {
  image_urls: [
    { url: "https://.../scene1.png" },
    { url: "https://.../tony.png" },
    { url: "https://.../watch.png" }
  ]
}
mentionMap {
  "@scene1": "https://.../scene1.png",
  "@tony":   "https://.../tony.png",
  "@watch":  "https://.../watch.png"
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

Before submitting, run the worksheet through `mixio-shot-planning`’s MCP mention validation:
URL matches, URL uniqueness, exact tag occurrence in the effective prompt, no unused maps, and no
prompt tags without bindings. Any failure is blocking and the job is not submitted.
