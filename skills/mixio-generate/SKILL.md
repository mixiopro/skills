---
name: mixio-generate
description: "Generate images, video, and audio with Mixio Studio. Supports 10+ models: Fal (FLUX, Recraft), Gemini Imagen, GPT-Image, Sora, BytePlus, ElevenLabs. Includes prompt enhancement and quality evaluation."
version: 0.1.0
invoke: /mixio:generate
---

# Mixio Generate

Generate images, video, and audio through Mixio Studio's unified generation API. All generation is metered via credits.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)

## Available Models

Call `studio_generation_catalog_get` for the current, authoritative model/workflow catalog. The table below is a quick reference — confirm model IDs against the catalog before use.

### Image Generation

| Model | ID | Best For |
|-------|-----|----------|
| Fal FLUX Pro | `fal/flux-pro` | Photorealistic images, high detail |
| Fal Recraft v3 | `fal/recraft-v3` | Stylized illustrations, design assets |
| Gemini Imagen 4 | `gemini/imagen-4` | Creative compositions, text in images |
| GPT Image | `gpt-image-1` | Versatile, instruction-following |

### Video Generation

| Model | ID | Best For |
|-------|-----|----------|
| Sora | `sora/v1` | Cinematic, narrative video |
| BytePlus | `byteplus/video` | Fast, cost-effective clips |
| Fal Kling | `fal/kling-video` | Motion, action sequences |
| Fal Minimax | `fal/minimax-video` | Character animation |

### Audio Generation

| Model | ID | Best For |
|-------|-----|----------|
| ElevenLabs TTS | `elevenlabs/tts` | Voice narration, dialogue |
| ElevenLabs SFX | `elevenlabs/sfx` | Sound effects |

## MCP Tools

| Tool | Purpose |
|------|---------|
| `studio_submit_studio_job` | Submit a single image/video/keyframe generation job |
| `studio_batch_submit_studio_jobs` | Submit up to 50 generation jobs in one call, with reference slots |
| `studio_get_job_status` | Check real-time status and output URLs of a job by ID |
| `studio_jobs_get` | Read bounded production jobs in current scope |
| `studio_generation_catalog_get` | Get available generator models and workflow catalogs |
| `studio_get_studio_job_api_schema` | Get the internal job API schema definitions |

Call `studio_tools_describe` on any of these for the exact input schema before your first call — parameters aren't hardcoded here since they come from the live tool definition.

## Workflow

```
1. studio_generation_catalog_get()          → confirm model/workflow IDs
2. studio_submit_studio_job(...)            → job_id
3. studio_get_job_status(job_id)            → poll until completed, get output URLs
4. (optional) upload_file(local_path)       → persist a local render to workspace
```

## Prompt Tips

### Images
- Be specific about composition: "wide shot", "close-up", "overhead"
- Specify lighting: "golden hour", "neon-lit", "soft diffused"
- Include medium: "photograph", "digital painting", "3D render"
- Add quality cues: "4K", "high detail", "professional"

### Video
- Describe motion: "slow pan left", "tracking shot", "zoom in"
- Keep prompts shorter than image prompts (models handle less complexity)
- Specify duration when possible
- Describe start and end states for best results

### Audio (TTS)
- Specify voice characteristics: "warm male narrator", "energetic female"
- Include pacing cues: pauses with `...`, emphasis with CAPS
- Keep segments under 2 minutes for best quality

## References

See `references/` for:
- `model-comparison.md` — detailed model capabilities and pricing
- `prompt-engineering.md` — advanced prompting techniques per model
- `batch-generation.md` — generating multiple variants efficiently
