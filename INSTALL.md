# Installation

## Requirements

- Node.js 22+ (for MCP server)
- A Mixio Studio account and API key

## Method 1: MCP server (recommended)

Add `@mixio-pro/mcp` to your agent's MCP config (e.g. `~/.claude/claude_desktop_config.json`, `~/.cursor/mcp.json`, or a project-level `.mcp.json`):

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

No install step or setup wizard — `npx` fetches it on first run. It creates a local cache at `~/.mixio/mcp-cache.db` (SQLite) that maps local files to their uploaded Mixio URLs.

## Method 2: Clone skills only

If you already have an MCP server configured and just want the skill docs:

```bash
git clone --depth 1 https://github.com/mixiopro/skills.git ~/.mixio/skills
```

## Method 3: Agent-specific

### Claude Code
```
/plugin install mixiopro/skills
```

### Codex
```bash
codex plugin add mixiopro/skills
```

### Cursor
Clone this repo into your project, Cursor auto-discovers `.cursor-plugin/plugin.json`.

## Getting Your API Key

1. Go to [Mixio Studio](https://studio.mixio.pro)
2. Sign in or create an account
3. Navigate to Settings → API Keys
4. Click "Create Key"
5. Copy the key (starts with `sk-`)

## Verify Installation

In any MCP-compatible agent, once the server is configured:
```
Use the studio_ping tool to check the Mixio Studio MCP connection
```
