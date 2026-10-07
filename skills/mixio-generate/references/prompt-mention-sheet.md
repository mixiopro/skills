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

| assetKey (slot + index) | slot | `@tag` | mentionMap label | compiled token (routed model) | where the tag appears in the prompt |
|---|---|---|---|---|---|
| `primary` | primary | `@scene1` | Scene 1 kitchen wide / approved view cam-a | H3: semantic tag (compiler-mapped) | context + shot plan |
| `references[0]` | references | `@tony` | Tony / `tony.v2.suit` | H3: semantic tag | subject |
| `references[1]` | references | `@watch` | Tony's watch (prop) | H3: semantic tag | subject |

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
| H3 Ref2Vid `hailuo_v3_reference_to_video` (`multi-shot-video`) | semantic `@tag` | semantic tag, compiler-mapped per section | no Mixio prompt ceiling; media image ≤9, video ≤3, audio ≤3 |
| Seedance `seedance_reference_to_video_v2` | semantic `@tag` | `@Image{n}` / `@Video{n}` / `@Audio{n}` | 3–15s |
| Kling `kling_o3_standard_reference_to_video` / `_pro_` | semantic `@tag` | `@Element{n}` / `@Image{n}`; audio `<<<voice_{n}>>>` | ≤2 voice tokens; references cap 4 |
| Gemini `gemini_omni_multishot` | semantic `@tag` | `<IMAGE_REF_{n}>` / `@Image{n}` | ≤9 image refs; 3–10s; 16:9 / 9:16 only |
| Production keyframe/image jobs (`gemini_image`, `seedream_*`, …) | semantic `@tag` | compiler-mapped per route | read schema per model |

## Multi-cut cut-line grammar (H3 six-section composer)

For a `MULTI_CUT` shot, append one line per `cuts[]` member after the six sections:

```
[Shot {cut_index}] At MM:SS.mmm — {shot_type}: {action}
```

Timestamps are cumulative cut starts (cut 1 at `00:00.000`); action text is `cuts[].action`
(+ `blocking` when present), unabridged — the cuts were persisted for exactly this. Seedance,
Kling, and Gemini multi-cut prompts use the same cut lines as plain prose sections (no
bracket grammar), with tags compiled per the table above.

## Worked example (12s MULTI_CUT, H3)

```
slotTags   { "primary": "@scene1", "references[0]": "@tony", "references[1]": "@watch" }
mentionMap {
  "@scene1": "Scene 1 kitchen wide / approved view cam-a",
  "@tony":   "Tony / tony.v2.suit",
  "@watch":  "Tony's watch (prop)"
}

prompt (six sections + cut lines):
  Context: …  References: @scene1 …  Subject: @tony (MC, …) holds @watch …
  Shot plan:
    [Shot 1] At 00:00.000 — MS: Tony enters, @watch catching the window light.
    [Shot 2] At 00:06.500 — CU: @watch fills frame as the hand stops.
    [Shot 3] At 00:10.000 — WS: Tony turns, @scene1 visible behind.
  Style: …  Constraints: …
```

Before submitting, run the sheet through the same checks as
`mixio-shot-planning`'s mention validation: coverage both ways, tag occurrence in the
effective prompt, non-empty labels, no duplicate assignment. Any failure is a blocking
finding and the job is not submitted.
