# Mixio Skills

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](./VERSION)
[![Skills](https://img.shields.io/badge/skills-11-blueviolet.svg)](#skills)

AI agent skills for media generation, workspace management, and creative workflows via [Mixio Studio](https://mixio.pro). Works with Claude Code, Cursor, Codex, and other AI coding agents that load Markdown-based skills.

## Install

Pick one. Each method configures the Mixio MCP server and loads skills into your agent.

**Want your agent to do it?** Paste [INSTALL_FOR_AGENTS.md](./INSTALL_FOR_AGENTS.md) into any AI coding agent — it covers both steps, installing the skills and configuring the MCP server. Longer reference in [INSTALL.md](./INSTALL.md).

### `npx skills` — recommended, works with 70+ agents

Installs the skill docs (this repo) into whichever agents you have installed — Claude Code, Cursor, Codex, OpenCode, Antigravity, Kiro, and more:

```bash
npx skills add mixiopro/skills          # prompts for scope
npx skills add mixiopro/skills -y       # project-level if you're in a project, else global
npx skills add mixiopro/skills -g -y    # force global (user-level)
```

Useful flags: `-y` skips the scope prompt, `-g` forces a global install, `-a <agents>` targets specific agents (`*` for all), `-s <skills>` installs only named skills (`*` for all). Project-level installs land in `.agents/skills/` and are symlinked into each detected agent's own skills directory.

**To update, re-run `add`** — it overwrites in place and picks up skills added since your last install.

This copies **skill directories only** — each folder under `skills/` that contains a `SKILL.md`, along with its `references/` and any scripts. Repo-root files are not copied, so [`AGENTS.md`](./AGENTS.md) and the MCP config below do not come with it. Clone the repo (see [Manual](#manual-any-agent)) if you want the repo-level guidance too.

Then configure the MCP server (see [Manual](#manual-any-agent) below) — the skills are documentation and cannot call anything without it.

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

**Tool skills** — what to call:

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-project`](./skills/mixio-project) | `/mixio:project` | Project CRUD and whole-graph reads (`get_production_context`). |
| [`mixio-references`](./skills/mixio-references) | `/mixio:references` | Cast & World — characters, locations, props, reference images and structured details for generation consistency. |
| [`mixio-episode`](./skills/mixio-episode) | `/mixio:episode` | Episode CRUD, script content, scene/shot breakdown, shot revision/approval, relations. |
| [`mixio-generate`](./skills/mixio-generate) | `/mixio:generate` | Image and video generation through Studio jobs — script breakdown, keyframe sequences, and image/video models with reference-image consistency. |
| [`mixio-workspace`](./skills/mixio-workspace) | `/mixio:workspace` | Upload local files to Mixio Studio, get permanent public URLs, manage cached assets. SHA-256 deduplication. |
| [`mixio-eval`](./skills/mixio-eval) | `/mixio:eval` | Run visual continuity / consistency evaluation jobs on generated or uploaded media before delivery. |

**Production skills** — what order, what schema, what gate:

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-pipeline`](./skills/mixio-pipeline) | `/mixio:pipeline` | The orchestrator — script → anchors → breakdown → audit → chunking → video as six gated steps, with resumable progress state. Owns the shared [shot grammar](./skills/mixio-pipeline/references/shot-grammar.md). |
| [`mixio-sheets`](./skills/mixio-sheets) | `/mixio:sheets` | Character turnaround sheets, six-field location sheets, prop sheets, and one wide anchor frame per scene — the reference layer every shot is generated against. |
| [`mixio-script-breakdown`](./skills/mixio-script-breakdown) | `/mixio:script-breakdown` | Script → canonical references, scenes, and shot specs. Mirrors Studio's own breakdown workflow: same schemas, the two closed camera enums, verbatim-preservation rules, and the mapping from shot grammar onto persistable keys. |
| [`mixio-continuity`](./skills/mixio-continuity) | `/mixio:continuity` | Four-pass text continuity audit before anything renders — blocking map, checks, report, corrected shots. |
| [`mixio-chunking`](./skills/mixio-chunking) | `/mixio:chunking` | Deterministic grouping of shots into generation chunks under duration/count caps, plus the production summary for cost approval. Includes a runnable [`chunk.py`](./skills/mixio-chunking/chunk.py). |

Tool skills are reference docs for the MCP surface and are safe to use standalone. Production skills encode the craft and the gating — start at `/mixio:pipeline` for a full episode.

## Typical Workflow

Running a full episode — `/mixio:pipeline` drives this, gating on user confirmation between steps:

```
Step 00  lock aspect_ratio (delivery) + anchor_aspect_ratio (wider, for anchors)
Step 01  Detailed Script     → /mixio:episode persists it as the source of truth
Step 02  Anchor Frames       → /mixio:sheets — character + location sheets, one anchor per scene
Step 03  Panel Breakdown     → /mixio:script-breakdown — shot specs, canonical schemas, enums
Step 04  Continuity Audit    → /mixio:continuity — 4 text passes, corrected shots locked
Step 05  Chunking            → /mixio:chunking — chunks + PRODUCTION SUMMARY for cost approval
Step 06  Video Generation    → /mixio:generate per chunk, then /mixio:eval before delivery
```

Steps 01, 03, 04 and 05 cost nothing but tokens. That is the point: a continuity break caught in Step 04 costs a paragraph, the same break caught in Step 06 costs a re-render.

For one-off work, skip the pipeline:

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

There is no *dedicated* audio tool, but audio generation is reachable through the normal job path — the engine exposes `text-to-speech`, `voiceover`, `voice-change` and `audio-driven-performance` use cases. Note that both discovery filters omit audio (`list_use_cases`' `outputType` is `IMAGE | VIDEO | all`), so call `studio_list_use_cases()` unfiltered to see them. Final assembly — stitching, mixing, export — is not part of the MCP surface at all.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

Apache-2.0 — see [LICENSE](./LICENSE).
