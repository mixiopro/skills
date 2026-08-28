# Installation

## Quick Install (One-Line)

**macOS & Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/mixiopro/skills/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/mixiopro/skills/main/install.ps1 | iex
```

This single command:
1. Creates the global `~/.mixio` folder and `~/.agents` store.
2. Clones or updates the complete suite of Mixio skills and `AGENTS.md`.
3. Auto-discovers and registers skills across all installed AI agents (**Claude Code**, **Codex**, **Gemini / Antigravity**, **Kiro**, **Cursor**, **OpenCode**, **GitHub Copilot**, **Hermes Agent**).
4. Configures the `@mixio-pro/mcp` MCP server in each agent's configuration.

---

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
Interactively:
```
/plugin marketplace add mixiopro/skills
/plugin install mixio@mixiopro/skills
```
Scripted (no chat, no dotfile editing — the key is prompted for and stored securely, not written to settings.json):
```bash
claude plugin marketplace add mixiopro/skills
claude plugin install mixio@mixiopro/skills --config mixio_api_key=sk-your-key-here
```
Bundles the `mixio` MCP server (`.mcp.json`, auto-discovered).

### Codex
```bash
codex plugin add mixiopro/skills
```
Bundles the `mixio` MCP server too (`.codex-plugin/plugin.json` points at `.codex-plugin/mcp.json`). Codex has no install-time key prompt — export `MIXIO_API_KEY` in your environment before running Codex; the server inherits it.

### Cursor
Clone this repo into your project, Cursor auto-discovers `.cursor-plugin/plugin.json`. MCP server config is not bundled for this method — use Method 1.

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
