# Install Mixio Skills (for AI agents)

Paste this into your AI coding agent to set up Mixio:

---

Install the Mixio CLI and configure MCP access:

```bash
npm install -g mixiocode
```

Then add this to your MCP configuration (typically `~/.mastracode/mcp.json` or equivalent):

```json
{
  "mcpServers": {
    "mixio-studio": {
      "command": "npx",
      "args": ["-y", "mixiocode", "--mcp"],
      "env": {
        "MIXIO_API_KEY": "REPLACE_WITH_YOUR_KEY",
        "MIXIO_BASE_URL": "https://studio.mixio.pro"
      }
    }
  }
}
```

After configuration, you have access to these tools:
- `generate` — create images, video, audio
- `generation_status` — check job progress
- `generation_result` — get output URLs
- `upload_file` — upload local files to Studio
- `get_public_url` — get CDN URL for a file
- `credits_balance` — check remaining credits
- `eval_score` — score generation quality

Read the skill docs in this repo for detailed usage of each tool.
