# Mixio Skills

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](./VERSION)
[![Skills](https://img.shields.io/badge/skills-6-blueviolet.svg)](#skills)

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

Mixio's data model: a **project** contains episodes and a Cast & World roster. An **episode** owns script/breakdown/scenes/shots. Cast & World (characters/locations/props) is **project**-scoped and feeds generation for consistency.

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-project`](./skills/mixio-project) | `/mixio:project` | Project CRUD and whole-graph reads (`get_production_context`). |
| [`mixio-references`](./skills/mixio-references) | `/mixio:references` | Cast & World — characters, locations, props, reference images and structured details for generation consistency. |
| [`mixio-episode`](./skills/mixio-episode) | `/mixio:episode` | Episode CRUD, script content, scene/shot breakdown, shot revision/approval, relations. |
| [`mixio-generate`](./skills/mixio-generate) | `/mixio:generate` | Image and video generation through Studio jobs — script breakdown, keyframe sequences, and image/video models with reference-image consistency. |
| [`mixio-workspace`](./skills/mixio-workspace) | `/mixio:workspace` | Upload local files to Mixio Studio, get permanent public URLs, manage cached assets. SHA-256 deduplication. |
| [`mixio-eval`](./skills/mixio-eval) | `/mixio:eval` | Run visual continuity / consistency evaluation jobs on generated or uploaded media before delivery. |

## Typical Workflow

```
User prompt: "Set up episode 3 and generate its opening shot"

1. /mixio:project    → find or create the project
2. /mixio:references → make sure the characters/locations in the shot have reference images
3. /mixio:episode    → create the episode, break the script into scenes/shots
4. /mixio:generate   → submit the shot as a generation job, pulling in reference images
5. /mixio:workspace  → upload any local renders, get public URLs
6. /mixio:eval       → run a continuity/consistency evaluation before delivery
```

## Models

Model IDs change as Studio adds providers — call `studio_list_generation_models` / `studio_list_use_cases` for the current catalog rather than relying on a static table. Known IDs as of writing:

| Media | Model IDs |
|-------|-----------|
| Image | `gpt_image_2`, `gemini_image`, `seedream_5_pro` |
| Video | `seedance_image_to_video_pro`, `seedance_text_to_video_pro`, `seedance_image_to_video_v2`, `veo_3_1`, `sora_2`, `kling_text_to_video_2_6_pro` |

There is no audio generation tool in the current MCP server.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

Apache-2.0 — see [LICENSE](./LICENSE).
