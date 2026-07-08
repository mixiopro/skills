# Mixio Skills

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](./VERSION)
[![Skills](https://img.shields.io/badge/skills-4-blueviolet.svg)](#skills)

AI agent skills for media generation, workspace management, and creative workflows via [Mixio Studio](https://mixio.pro). Works with Claude Code, Cursor, Codex, and other AI coding agents that load Markdown-based skills.

## Install

Pick one. Each method configures the Mixio MCP server and loads skills into your agent.

### `npx` — recommended, cross-agent

```bash
npx mixiocode setup
```

### Claude Code marketplace

Inside Claude Code:

```
/plugin install mixiopro/skills
```

### Codex plugin

```bash
codex plugin add mixiopro/skills
```

### Manual (any agent)

```bash
git clone --depth 1 https://github.com/mixiopro/skills.git ~/.mixio/skills
```

Then add the MCP server to your agent's config:
```json
{
  "mcpServers": {
    "mixio-studio": {
      "command": "npx",
      "args": ["-y", "mixiocode", "--mcp"],
      "env": { "MIXIO_API_KEY": "your-key-here" }
    }
  }
}
```

Get your API key from [Mixio Studio](https://studio.mixio.pro) → Settings → API Keys.

## Skills

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-generate`](./mixio-generate) | `/mixio:generate` | Image, video, and audio generation across 10+ models (Fal FLUX, Recraft, Gemini Imagen, GPT-Image, Sora, BytePlus, Fal Kling, ElevenLabs). Prompt engineering tips and batch workflows. |
| [`mixio-workspace`](./mixio-workspace) | `/mixio:workspace` | Upload local files to Mixio Studio, get permanent public URLs, manage cached assets. SHA-256 deduplication, 500MB max. |
| [`mixio-credits`](./mixio-credits) | `/mixio:credits` | Check credit balance, view usage history, understand per-model pricing, and top up. |
| [`mixio-eval`](./mixio-eval) | `/mixio:eval` | Score generated outputs on quality criteria (composition, lighting, motion, prompt adherence). Compare variants, enforce quality gates, run evaluation blueprints. |

## Typical Workflow

```
User prompt: "Create a product video for my app"

1. /mixio:generate  → Generate video with Sora
2. /mixio:eval      → Score the output (composition, motion quality)
3. /mixio:generate  → If score < 80, regenerate with refined prompt
4. /mixio:workspace → Upload final video, get public URL
5. /mixio:credits   → Check remaining balance
```

## Models

### Image
| Model | Speed | Quality | Best For |
|-------|-------|---------|----------|
| Fal FLUX Pro | Fast | High | Photorealistic |
| Fal Recraft v3 | Fast | High | Illustrations, design |
| Gemini Imagen 4 | Medium | High | Text in images |
| GPT Image | Medium | High | Versatile |

### Video
| Model | Speed | Quality | Best For |
|-------|-------|---------|----------|
| Sora | Slow | Highest | Cinematic narrative |
| BytePlus | Fast | Medium | Quick drafts |
| Fal Kling | Medium | High | Action, motion |
| Fal Minimax | Medium | High | Character animation |

### Audio
| Model | Speed | Quality | Best For |
|-------|-------|---------|----------|
| ElevenLabs TTS | Fast | High | Narration, dialogue |
| ElevenLabs SFX | Fast | High | Sound effects |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

Apache-2.0 — see [LICENSE](./LICENSE).
