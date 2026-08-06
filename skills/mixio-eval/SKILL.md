---
name: mixio-eval
description: "Run visual continuity and consistency evaluations on generated media via Mixio Studio's evaluation pipeline before delivery."
version: 0.1.0
invoke: /mixio:eval
---

# Mixio Eval

Run visual continuity / consistency evaluation jobs on generated or uploaded media via the Mixio MCP server. Use as a quality gate before delivering outputs to clients.

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

These are local tools implemented directly in `@mixio-pro/mcp` (no `studio_` prefix — they are not proxied from the Studio server, so `studio_describe_tools` won't find them).

### `register_asset`

Register an uploaded asset under a project so it can be referenced in evaluation prompts via `@alias`.

| Param | Required | Notes |
|-------|----------|-------|
| `project_id` | yes | |
| `alias` | yes | e.g. `"char1"` |
| `type` | yes | one of `video`, `character`, `location`, `script`, `image`, `prop` |
| `source_url` | yes | public/staged CDN URL — upload first with `upload_file`/`get_public_url` |
| `display_name` | no | |
| `thumbnail_url` | no | |
| `cdn_url` | no | fallback CDN URL |

### `run_evaluation`

Submit a visual continuity/consistency evaluation job.

| Param | Required | Notes |
|-------|----------|-------|
| `capability` | yes | see enum below |
| `prompt` | yes | instructions, e.g. `"Verify the visual flow of @video"` — reference registered assets with `@alias` |
| `image_urls` | no | array, for checking keyframe images directly |
| `video_url` | no | for evaluating a video |
| `algorithm` | no | defaults to `gemini_review` |
| `threshold` | no | 0.0-1.0, defaults to `0.80` |
| `background` | no | defaults to `true` (async — returns a `run_id` starting with `resp_` to poll) |

`capability` enum: `identity_consistency`, `style_consistency`, `composition_consistency`, `color_consistency`, `background_consistency`, `lighting_consistency`, `temporal_consistency`, `wardrobe_consistency`, `scene_consistency`, `object_consistency`, `prompt_consistency`, `location_consistency`, `prop_consistency`, `voice_identity_consistency`, `audio_continuity`, `lip_sync_consistency`, `subtitle_alignment`, `timeline_diff`, `brand_consistency`, `story_continuity`.

### `get_evaluation_result`

Poll or retrieve a background evaluation by `run_id` (the `resp_...` value from `run_evaluation`).

### `list_projects`

Lists production **review** projects (the eval pipeline's own project scope) — no params. This is a different tool from the proxied `studio_list_projects`, which lists Studio production projects. Don't confuse the two; they hit different backends and return different data.

## Workflow

```
1. upload_file(local_path)                      → public URL (see mixio-workspace)
2. register_asset({ project_id, alias, type, source_url })   → @alias, referenceable in evaluations
3. run_evaluation({ capability, prompt, video_url or image_urls })  → run_id (resp_...)
4. get_evaluation_result(run_id)                 → poll until complete, read results
```

## Tips

- Evaluate before delivering to clients — catches continuity/consistency issues early
- Pick the `capability` that matches what actually changed (e.g. `wardrobe_consistency` after a costume edit) rather than defaulting to `story_continuity` for everything
- `run_id` values start with `resp_` — don't confuse them with Studio `jobId`s from `mixio-generate`
