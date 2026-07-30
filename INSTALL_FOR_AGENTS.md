# Install Mixio Skills (for AI agents)

Paste this into your AI coding agent to set up Mixio:

---

Add this to your MCP configuration (typically `~/.claude/claude_desktop_config.json`, `~/.cursor/mcp.json`, a project-level `.mcp.json`, or equivalent):

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

After configuration, you have access to these tools:
- `upload_file` / `get_public_url` — upload local files to Studio, get public URLs
- `list_cached_files` / `forget_path` / `clear_cache` — manage the local upload cache
- `register_asset` — register an uploaded asset for evaluation
- `run_evaluation` / `get_evaluation_result` — visual continuity/consistency evaluation
- `list_projects` — list production review projects
- `studio_*` — 40+ tools proxied from the Studio MCP server (projects, episodes, elements, jobs, generation). Call `studio_tools_search` to discover them and `studio_tools_describe` for exact input schemas.

Read the skill docs in this repo for detailed usage of each tool.
