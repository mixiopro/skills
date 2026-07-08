# Installation

## Requirements

- Node.js 22+ (for MCP server)
- A Mixio Studio account and API key

## Method 1: npm (recommended)

```bash
npm install -g mixiocode
mixio setup
```

This installs the CLI globally and runs the setup wizard which:
- Prompts for your API key
- Configures the MCP server in `~/.mastracode/mcp.json`
- Creates local state directory at `~/.mixio/`

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

After setup, test with:
```bash
mixio
# Then type: "Check my credit balance"
```

Or in any MCP-compatible agent:
```
Use the credits_balance tool to check my Mixio balance
```
