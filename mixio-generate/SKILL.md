---
name: mixio-generate
description: "Generate images, video, and audio with Mixio Studio. Supports 10+ models: Fal (FLUX, Recraft), Gemini Imagen, GPT-Image, Sora, BytePlus, ElevenLabs. Includes prompt enhancement and quality evaluation."
version: 0.1.0
invoke: /mixio:generate
---

# Mixio Generate

Generate images, video, and audio through Mixio Studio's unified generation API. All generation is metered via credits.

## Prerequisites

- Mixio CLI installed: `npm install -g mixiocode`
- Setup complete: `mixio setup` (configures API key + MCP)
- Or: MCP server configured in your agent (see INSTALL.md)

## Available Models

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

### `generate`

Start a generation job.

```json
{
  "tool": "generate",
  "arguments": {
    "model": "fal/flux-pro",
    "prompt": "A cinematic wide shot of a neon-lit Tokyo alley at night, rain reflections, 4K",
    "aspect_ratio": "16:9",
    "num_images": 1
  }
}
```

**Parameters:**
- `model` (required) — model ID from tables above
- `prompt` (required) — generation prompt
- `negative_prompt` — what to avoid
- `aspect_ratio` — `1:1`, `16:9`, `9:16`, `4:3`, `3:4`
- `num_images` — 1-4 (image models only)
- `duration` — seconds (video models, typically 4-16)
- `style` — model-specific style preset
- `seed` — reproducibility

### `generation_status`

Check job progress.

```json
{
  "tool": "generation_status",
  "arguments": {
    "job_id": "gen_abc123"
  }
}
```

Returns: `queued`, `processing`, `completed`, `failed`

### `generation_result`

Get completed output URLs.

```json
{
  "tool": "generation_result",
  "arguments": {
    "job_id": "gen_abc123"
  }
}
```

Returns: array of `{ url, content_type, width, height, duration }`

## Workflow

```
1. generate(model, prompt, ...)     → job_id
2. generation_status(job_id)        → wait for "completed"
3. generation_result(job_id)        → get output URLs
4. (optional) upload_file(local_path) → persist to workspace
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

## Credits

Each generation deducts credits based on model + parameters:
- Image: 1-5 credits depending on resolution and model
- Video: 5-20 credits depending on duration and model
- Audio: 1-3 credits per minute

Check balance: use `credits_balance` tool or Studio dashboard.

## References

See `references/` for:
- `model-comparison.md` — detailed model capabilities and pricing
- `prompt-engineering.md` — advanced prompting techniques per model
- `batch-generation.md` — generating multiple variants efficiently
