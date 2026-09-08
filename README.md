# Mixio Skills

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](./VERSION)
[![Skills](https://img.shields.io/badge/skills-12-blueviolet.svg)](#skills)

AI agent skills for media generation, workspace management, and creative workflows via [Mixio Studio](https://mixio.pro). Works with Claude Code, Cursor, Codex, and other AI coding agents that load Markdown-based skills.

## Install

Pick one. Each method configures the Mixio MCP server and loads skills into your agent.

### One-line installer (Recommended)

**macOS & Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/mixiopro/skills/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/mixiopro/skills/main/install.ps1 | iex
```

This single command sets up the global `~/.mixio` folder, installs all skills into `~/.agents/skills` and `~/.mixio/skills`, places `AGENTS.md`, and automatically registers them into all detected AI agents (Claude Code, Codex, Gemini/Antigravity, Kiro, Cursor, OpenCode, Copilot, Hermes, etc.).

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

Get your API key from [Mixio Studio Dashboard](https://studio.mixio.pro/dashboard/api-keys).

No MCP client available (agents, scripts)? Use [mixio-cli](https://github.com/mixiopro/mixio-cli) instead — see [AGENTS.md](./AGENTS.md#tool-names-across-transports) for how tool names differ across transports.

## Skills

Mixio's data model: a **project** contains episodes and a Cast & World roster. An **episode** has a raw Idea/Story fallback (`script`) plus an optional native **Screenplay** element, then breakdown/scenes/shots. A non-empty screenplay body—draft included—is the source the breakdown prefers; `script` is used only when no usable screenplay exists. Cast & World (characters/locations/props) is **project**-scoped and feeds generation for consistency.

**Tool skills** — what to call:

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-project`](./skills/mixio-project) | `/mixio:project` | Project CRUD and whole-graph reads (`get_production_context`). |
| [`mixio-references`](./skills/mixio-references) | `/mixio:references` | Cast & World — characters, locations, props, reference images and structured details for generation consistency. |
| [`mixio-episode`](./skills/mixio-episode) | `/mixio:episode` | Episode CRUD, script content, scene/shot breakdown, shot revision/approval, relations. |
| [`mixio-generate`](./skills/mixio-generate) | `/mixio:generate` | Image, video and audio generation through Studio jobs — which use cases and models exist, what each accepts, what it costs, and when a Studio production use case beats a Generate one. |
| [`mixio-workspace`](./skills/mixio-workspace) | `/mixio:workspace` | Upload local files to Mixio Studio, get permanent public URLs, manage cached assets. SHA-256 deduplication. |
| [`mixio-eval`](./skills/mixio-eval) | `/mixio:eval` | Run visual continuity / consistency evaluation jobs on generated or uploaded media before delivery. |

**Production skills** — what order, what schema, what gate:

| Skill | Invoke | Description |
|-------|--------|-------------|
| [`mixio-pipeline`](./skills/mixio-pipeline) | `/mixio:pipeline` | The orchestrator — screenplay → anchors → reference audit → breakdown → continuity → shot planning → video as gated steps, with resumable progress state. Uses the native [screenplay grammar](./skills/mixio-episode/references/screenplay-grammar.md) and the shared [shot grammar](./skills/mixio-pipeline/references/shot-grammar.md). |
| [`mixio-sheets`](./skills/mixio-sheets) | `/mixio:sheets` | Character turnaround sheets, six-field location sheets, prop sheets, and one wide anchor frame per scene — the reference layer every shot is generated against. |
| [`mixio-reference-audit`](./skills/mixio-reference-audit) | `/mixio:reference-audit` | Audit Cast & World for completeness, name/image consistency, duplicates, metadata quality, and policy compliance — catch reference problems before they cost re-renders. |
| [`mixio-script-breakdown`](./skills/mixio-script-breakdown) | `/mixio:script-breakdown` | Script → canonical scenes and shot specs with entity graph linking, appearanceState, and immediate relational audit. |
| [`mixio-continuity`](./skills/mixio-continuity) | `/mixio:continuity` | Four-pass text continuity audit before anything renders — blocking map, checks, report, corrected shots. |
| [`mixio-shot-planning`](./skills/mixio-shot-planning) | `/mixio:shot-planning` | Classify each shot into 5 structural archetypes (grid, sequence, master anchor multi-shot, single/dual frame, t2v), match to best model, audit execution feasibility, and group into generation batches with a credit-costed production summary. |

Tool skills are reference docs for the MCP surface and are safe to use standalone. Production skills encode the craft and the gating — start at `/mixio:pipeline` for a full episode.

## Typical Workflow

Running a full episode — `/mixio:pipeline` drives this, gating on user confirmation between steps:

```
Step 00  Preflight           → /mixio:pipeline — lock image/video model, delivery + anchor aspect_ratio,
                              resolution, visual style and reference policy into the project settings
Step 01  Detailed Screenplay → /mixio:episode discovers mentions and upserts the native screenplay draft
Step 02  Anchor Frames       → /mixio:sheets — character + location sheets, one anchor per scene
Step 02.5 Reference Audit    → /mixio:reference-audit — completeness, consistency, duplicates, metadata
Step 03  Panel Breakdown     → /mixio:script-breakdown — shot specs, canonical schemas, enums
Step 04  Continuity Audit    → /mixio:continuity — 4 text passes, corrected shots locked
Step 05  Shot Planning       → /mixio:shot-planning — method + model + feasibility + batches + PRODUCTION SUMMARY
Step 06  Video Generation    → /mixio:generate per batch, then /mixio:eval before delivery
```

Steps 01, 02.5, 03, 04 and 05 cost nothing but tokens. That is the point: a continuity break caught in Step 04 costs a paragraph, a missing reference caught in Step 02.5 costs one upload — the same problems caught in Step 06 cost re-renders.

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

Model IDs change as Studio adds providers — call `studio_list_use_cases({ outputType: "all" })` for the current set and read each use case's `supportedModels`, then `studio_get_use_case_input_schema({ useCaseId, modelId })` for that pair's real contract. Do **not** use `studio_list_generation_models` for discovery: its `mediaType` filter returns an empty list and its descriptive fields are always `undefined` (see [`mixio-generate`](./skills/mixio-generate) for why). Known IDs as of writing:

| Media | Model IDs |
|-------|-----------|
| Image | `gpt_image_2`, `gemini_image`, `nano_banana_2`, `seedream_5_pro`, `seedream_5_lite` |
| Video | `seedance_image_to_video_pro`, `seedance_text_to_video_pro`, `seedance_image_to_video_v2`, `veo_3_1`, `sora_2`, `kling_text_to_video_2_6_pro` |

There is no *dedicated* audio tool, but audio generation is reachable through the normal job path — the catalog exposes `text-to-speech` and `voice-change` as `outputType: AUDIO`. Note the discovery filter cannot express audio (`list_use_cases`' `outputType` is `IMAGE | VIDEO | all`), so call `studio_list_use_cases({ outputType: "all" })` to see them. Final assembly — stitching, mixing, export — is not part of the MCP surface at all.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

Apache-2.0 — see [LICENSE](./LICENSE).
