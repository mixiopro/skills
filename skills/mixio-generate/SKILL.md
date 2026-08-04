---
name: mixio-generate
description: "Generate images and video through Mixio Studio jobs — script breakdown, keyframe sequences, image and video generation with character/location reference consistency."
version: 0.1.0
invoke: /mixio:generate
---

# Mixio Generate

Submit and track Studio generation jobs (image, video, script breakdown, keyframe sequences) through the proxied `studio_*` MCP tools. Jobs are billable and run async by default.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)

## Models & Use Cases

Model and use-case IDs change as Studio adds providers — always confirm with `studio_list_generation_models` / `studio_list_use_cases` before hardcoding an ID. As a starting point:

| Media | Model IDs |
|-------|-----------|
| Image | `gpt_image_2`, `gemini_image`, `seedream_5_pro` |
| Video | `seedance_image_to_video_pro`, `seedance_text_to_video_pro`, `seedance_image_to_video_v2`, `veo_3_1`, `sora_2`, `kling_text_to_video_2_6_pro` |

Common `useCaseId` values: `image-hub` (general image gen with references), `production-generate-keyframes`, `image-edit` (requires a source image), `refine-character-image`, `production-generate-video`, `keyframe-sequence` (multi-frame continuity workflow), `script-preproduction`.

## MCP Tools

| Tool | Purpose |
|------|---------|
| `studio_submit_studio_job` | Submit one image/video/script-breakdown/keyframe-sequence job |
| `studio_batch_submit_studio_jobs` | Submit up to 50 jobs in one call (same job shape, wrapped in a `jobs` array) |
| `studio_get_job_status` | Poll a job by `jobId` **and** `projectId` — returns status + output URL when complete |
| `studio_list_generation_models` | List model IDs, optionally filtered by `useCaseId` or `mediaType` |
| `studio_list_use_cases` | List use-case IDs, optionally filtered by `outputType` |
| `studio_list_references` | List a project's CHARACTER/LOCATION/PROP elements — use to get reference image URLs |
| `studio_get_use_case_input_schema` | **Returns the exact input contract (media slots + parameters) for a use case.** Call this before submitting an unfamiliar use case instead of guessing at `input.media` / `input.parameters` |
| `studio_generation_catalog_get` | Bounded catalog read (newer discovery adapter, smaller result set than `list_generation_models`) |
| `studio_get_studio_job_api_schema` | Returns the underlying HTTP contract for `/api/studio-jobs/*` — rarely needed since the tools above cover submit/status directly |

Call `studio_tools_describe` on any of these for the exact current input schema.

### Audio — reachable, but not discoverable

There is no dedicated audio MCP tool, and both discovery filters omit audio:
`studio_list_use_cases`'s `outputType` enum is `IMAGE | VIDEO | all`, and
`studio_list_generation_models`'s `mediaType` is `image | video | all`.

Audio generation nevertheless **works through the normal job path** — the engine
has an `AUDIO` output type and use cases including `text-to-speech`,
`voiceover`, `voice-change`, and `audio-driven-performance`, and
`studio_submit_studio_job` accepts any `useCaseId` string:

```
studio_list_use_cases()                       // no filter — audio use cases appear here
studio_get_use_case_input_schema({ useCaseId: "text-to-speech" })   // exact contract
studio_submit_studio_job({ jobType: "audio", useCaseId: "text-to-speech",
                           prompt, input: { parameters }, context: { projectId } })
```

Call `studio_list_use_cases()` **without** `outputType` to see them — passing
`"IMAGE"` or `"VIDEO"` filters them out, and there is no `"AUDIO"` value to pass.
Confirm the current ids from that call rather than trusting the list above.

### Key gotchas (from the tool's own docs)

- **Reference images and aspect ratio must go through `input.media` / `input.parameters`.** Omitting them silently generates without reference consistency at a default `1:1` aspect ratio.
- **`input.media` slots take real URLs, not Payload media IDs.** The server rejects UUID-looking values. `studio_list_references` only returns a summary (`hasAttachments` boolean, no URLs) — get the actual attachment URLs from `studio_get_element`/`studio_get_production_context` (`referenceVariants[].attachments[].media.url`), or upload fresh with `upload_file`/`get_public_url`. See `mixio-references` for the full Cast & World reference workflow.
- Media slots: `primary`, `references`, `character_ref`, `location_ref`, `style_ref`, `asset_ref`, `endFrame` — each accepts `{ url }` or an array of them.
- `input.parameters`: `aspect_ratio` (`1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `21:9`), `quality`, `duration` (video, seconds), `style`, `output_format`, `keyframe_count` (4-12, for `keyframe-sequence`), `orchestrate_frames` (true for >12 frames — dispatches one child job per frame).
- `studio_get_job_status` requires **both** `jobId` and `projectId` — it's not a bare job lookup.
- There's no MCP cancel tool. Cancellation is HTTP-only (`POST /api/studio-jobs/{id}/cancel`), outside this tool set.
- Job status values: `PENDING`, `RUNNING`, `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED`.

## Workflow

```
1. studio_list_use_cases() / studio_list_generation_models()   → confirm useCaseId / model
2. studio_list_references(projectId) → studio_get_element(referenceId)   → get character/location reference image URLs, if needed
3. studio_submit_studio_job({ jobType, model, useCaseId, prompt, input: { media, parameters }, context: { projectId } })
                                                                  → job id + tracking
4. studio_get_job_status({ jobId, projectId })                  → poll until COMPLETED, read output.output_url
5. (optional) upload_file(local_path)                            → persist a local render to workspace
```

## Prompt Tips

### Images
- Be specific about composition: "wide shot", "close-up", "overhead"
- Specify lighting: "golden hour", "neon-lit", "soft diffused"
- Include medium: "photograph", "digital painting", "3D render"

### Video
- Describe motion: "slow pan left", "tracking shot", "zoom in"
- Keep prompts shorter than image prompts (models handle less complexity)
- Specify duration and a start frame (`input.media.primary`) when possible

## References

See `references/model-comparison.md` for how to pick a model/use case from the live catalog.
