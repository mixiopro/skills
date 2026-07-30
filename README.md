# Mixio Skills

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](./VERSION)
[![Skills](https://img.shields.io/badge/skills-3-blueviolet.svg)](#skills)

AI agent skills for media generation, workspace management, and creative workflows via [Mixio Studio](https://mixio.pro). Works with Claude Code, Cursor, Codex, and other AI coding agents that load Markdown-based skills.

## Install

Pick one. Each method configures the Mixio MCP server and loads skills into your agent.

### `npx skills` — recommended, works with 70+ agents

Installs the skill docs (this repo) into whichever agents you have installed — Claude Code, Cursor, Codex, OpenCode, Antigravity, Kiro, and more:

```bash
npx skills add mixiopro/skills
```

Then configure the MCP server (see [Manual](#manual-any-agent) below).

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
    "mixio": {
      "command": "npx",
      "args": ["-y", "@mixio-pro/mcp"],
      "env": { "MIXIO_API_KEY": "your-key-here" }
    }
  }
}
```

Get your API key from [Mixio Studio](https://studio.mixio.pro) → Settings → API Keys.

## Skills

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-generate`](./skills/mixio-generate) | `/mixio:generate` | Image, video, and audio generation across 10+ models (Fal FLUX, Recraft, Gemini Imagen, GPT-Image, Sora, BytePlus, Fal Kling, ElevenLabs). Prompt engineering tips and batch workflows. |
| [`mixio-workspace`](./skills/mixio-workspace) | `/mixio:workspace` | Upload local files to Mixio Studio, get permanent public URLs, manage cached assets. SHA-256 deduplication, 500MB max. |
| [`mixio-eval`](./skills/mixio-eval) | `/mixio:eval` | Run visual continuity / consistency evaluation jobs on generated or uploaded media before delivery. |

## Typical Workflow

```
User prompt: "Create a product video for my app"

1. /mixio:generate  → Generate video with Sora
2. /mixio:workspace → Upload final video, get public URL
3. /mixio:eval      → Run a continuity/consistency evaluation before delivery
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
