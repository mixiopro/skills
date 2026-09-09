---
name: mixio-eval
description: "Run visual continuity and consistency evaluations on generated media via Mixio Studio's evaluation pipeline before delivery."
version: 0.1.0
invoke: /mixio:eval
---

# Mixio Eval

Run visual continuity / consistency evaluation jobs through the hosted Studio MCP surface. Use as a quality gate before delivering outputs to clients.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)
- **Resolved scope — required.** You must be working against a project that the user has
  explicitly confirmed. If it is not established in this session, **fetch the list and show
  it, numbered, in the same message as the question** (`eval_list_projects` — the eval
  pipeline's own project listing) so the answer is one character. Asking "which project?"
  without the list is a failure — it hands the lookup back to the user. Resolve this *before*
  any expensive read; never guess an id, infer one from a title, or create something to avoid
  asking. See `mixio-project`.

## MCP Tool

Use the proxied hosted `studio_run_eval` tool. It requires the confirmed Studio `projectId`; read its current schema with `studio_get_contract({ target: "tool", toolName: "run_eval" })` before calling it.

| Param | Required | Notes |
|-------|----------|-------|
| `projectId` | yes | confirmed Studio project UUID |
| `capability` | yes | see enum below |
| `prompt` | yes | instructions, e.g. `"Verify the visual flow of @video"` |
| `imageUrls` | no | array, for checking keyframe images directly |
| `videoUrl` | no | for evaluating a video |
| `algorithm` | no | defaults to `gemini_review` |
| `threshold` | no | 0.0-1.0, defaults to `0.80` |
| `background` | no | defaults to `true` (async — returns a `runId` starting with `resp_`) |

`capability` enum: `identity_consistency`, `style_consistency`, `composition_consistency`, `color_consistency`, `background_consistency`, `lighting_consistency`, `temporal_consistency`, `wardrobe_consistency`, `scene_consistency`, `object_consistency`, `prompt_consistency`, `location_consistency`, `prop_consistency`, `voice_identity_consistency`, `audio_continuity`, `lip_sync_consistency`, `subtitle_alignment`, `timeline_diff`, `brand_consistency`, `story_continuity`.

### `eval_list_projects`

No params. Lists the eval pipeline's review projects — the eval surface's own project scope. This is a **different tool** from `studio_list_projects` (which lists Studio production projects): they hit different backends and return different data. When you need to resolve the project for an evaluation, list with `eval_list_projects`, never `studio_list_projects`.

## Workflow

```
1. eval_list_projects()                       → resolve the eval project (numbered list → ASK)
2. studio_get_contract({ target: "tool", toolName: "run_eval" }) → current hosted schema
3. studio_run_eval({ projectId, capability, prompt, videoUrl or imageUrls }) → runId (resp_...)
4. Read the hosted response or the Studio job surface for the evaluation result
```

## Tips

- Evaluate before delivering to clients — catches continuity/consistency issues early
- Pick the `capability` that matches what actually changed (e.g. `wardrobe_consistency` after a costume edit) rather than defaulting to `story_continuity` for everything
- `eval_list_projects` (the eval surface's project listing) is not the same tool as `studio_list_projects` (Studio production projects); they hit different backends and return different data — don't swap them. When in doubt, `search_tools`/`describe_tools` on your transport shows which one is actually exposed.
