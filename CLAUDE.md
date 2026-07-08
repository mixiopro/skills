# Mixio Skills

You have access to Mixio Studio tools via MCP. Use these skills to generate media, manage workspaces, and evaluate outputs.

## Available Skills

| Skill | Invoke | Use For |
|-------|--------|---------|
| `mixio-generate` | `/mixio:generate` | Image, video, audio generation with 10+ models |
| `mixio-workspace` | `/mixio:workspace` | Upload files, get public URLs, manage cache |
| `mixio-credits` | `/mixio:credits` | Check balance, usage history, pricing |
| `mixio-eval` | `/mixio:eval` | Score outputs, compare variants, quality gates |

## Quick Start

```
# Generate an image
generate(model: "fal/flux-pro", prompt: "...")  → job_id
generation_status(job_id)                        → wait for completed
generation_result(job_id)                        → output URLs

# Upload a local file
upload_file(path: "/path/to/file.mp4")          → public URL

# Check credits
credits_balance()                                → current balance
```

## MCP Server

These skills work with the Mixio MCP server. If not already configured:

```bash
npm install -g mixiocode
mixio setup
```

Or add manually to your MCP config:
```json
{
  "mcpServers": {
    "mixio-studio": {
      "command": "npx",
      "args": ["-y", "mixiocode", "--mcp"],
      "env": { "MIXIO_API_KEY": "your-key" }
    }
  }
}
```

## Conventions

- Always check `credits_balance` before large batch jobs
- Use `eval_score` before delivering outputs to clients
- Upload final outputs to workspace for permanent URLs
- Prefer BytePlus for draft video, Sora for final delivery
- Keep generation prompts concise for video models
