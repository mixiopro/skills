# Install Mixio Skills (for AI agents)

Paste everything between the rules into your AI coding agent.

---

Set up Mixio for me, in two steps.

**Step 1 — install the skill docs.** Run exactly this (the package is `skills`, not a scoped one, and the source is `owner/repo` with no `github:` prefix):

```bash
npx skills add mixiopro/skills -y
```

Add `-g` to install globally (user-level) instead of into this project. To update later, re-run the same command — it overwrites in place. This installs 11 skills named `mixio-*`; tell me how many were installed so I know it worked.

**Step 2 — configure the MCP server.** The skills are documentation and cannot call anything on their own. Add this to my MCP configuration (typically `~/.claude/claude_desktop_config.json`, `~/.cursor/mcp.json`, `.kiro/settings/mcp.json`, a project-level `.mcp.json`, or equivalent):

```json
{
  "mcpServers": {
    "mixio": {
      "command": "npx",
      "args": ["-y", "@mixio-pro/mcp"],
      "env": {
        "MIXIO_API_KEY": "REPLACE_WITH_YOUR_KEY",
        "MIXIO_BASE_URL": "https://studio.mixio.pro"
      }
    }
  }
}
```

No global install needed — `npx` fetches `@mixio-pro/mcp` on first run.

Then verify with `studio_ping`, and list my projects with `studio_list_projects` so I can confirm which one to work in.

---

## What you get

**Tools** — `upload_file` / `get_public_url` (upload local files, get public URLs), `list_cached_files` / `forget_path` / `clear_cache` (local upload cache), `register_asset`, `run_evaluation` / `get_evaluation_result` (visual continuity evaluation), `list_projects`, and 40+ `studio_*` tools proxied from Studio (projects, episodes, elements, references, jobs, generation). Call `studio_tools_search` to discover them and `studio_tools_describe` for exact input schemas.

**Skills** — 11 `mixio-*` skills. Start at `/mixio:pipeline` for a full episode; see [AGENTS.md](./AGENTS.md) for the map and the conventions.

One rule worth knowing up front: every tool is stateless, so there is no "current project" on the server. Confirm which project (and episode) you are working in before reading or writing anything — the skills require this explicitly.
