# Mixio Skills

You have access to Mixio Studio tools via MCP. Use these skills to generate media, manage workspaces, and evaluate outputs.

## Available Skills

| Skill | Invoke | Use For |
|-------|--------|---------|
| `mixio-generate` | `/mixio:generate` | Image, video, audio generation with 10+ models |
| `mixio-workspace` | `/mixio:workspace` | Upload files, get public URLs, manage cache |
| `mixio-eval` | `/mixio:eval` | Score outputs, compare variants, quality gates |

## Quick Start

```
# Generate media
studio_submit_studio_job(...)      → job_id
studio_get_job_status(job_id)      → wait for completed, get output URLs

# Upload a local file
upload_file(path: "/path/to/file.mp4")  → public URL

# Evaluate an output
register_asset(...)                → @alias
run_evaluation(...)                → evaluation job
get_evaluation_result(...)         → status + results
```

Exact parameters aren't hardcoded here — call `studio_tools_describe` to get the current input schema for any tool, or `studio_tools_search` to discover tools by keyword.

## MCP Server

These skills work with the Mixio MCP server (`@mixio-pro/mcp`, npm). Add it to your agent's MCP config:

```json
{
  "mcpServers": {
    "mixio": {
      "command": "npx",
      "args": ["-y", "@mixio-pro/mcp"],
      "env": { "MIXIO_API_KEY": "your-key" }
    }
  }
}
```

## Conventions

- Use `studio_tools_describe` before calling an unfamiliar tool for the first time — don't guess at parameters
- Upload final outputs to workspace (`upload_file`) for permanent URLs
- Run `run_evaluation` before delivering outputs to clients
- Keep generation prompts concise for video models
