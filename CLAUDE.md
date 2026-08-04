# Mixio Skills

You have access to Mixio Studio tools via MCP. Use these skills to generate media, manage workspaces, and evaluate outputs.

## Available Skills

Mixio's data model: a **project** contains episodes and a Cast & World roster. An **episode** owns script/breakdown/scenes/shots. Cast & World (characters/locations/props) is **project**-scoped and feeds generation for consistency.

| Skill | Invoke | Use For |
|-------|--------|---------|
| `mixio-project` | `/mixio:project` | Project CRUD, whole-graph reads (`get_production_context`) |
| `mixio-references` | `/mixio:references` | Cast & World — characters, locations, props, reference images |
| `mixio-episode` | `/mixio:episode` | Episode CRUD, script, scene/shot breakdown, relations |
| `mixio-generate` | `/mixio:generate` | Image and video generation via Studio jobs (script breakdown, keyframes, image/video models) |
| `mixio-workspace` | `/mixio:workspace` | Upload files, get public URLs, manage cache |
| `mixio-eval` | `/mixio:eval` | Visual continuity/consistency evaluation before delivery |
| `mixio-pipeline` | `/mixio:pipeline` | **Start here for a full episode** — six gated steps, progress state, shared shot grammar |
| `mixio-sheets` | `/mixio:sheets` | Character turnarounds, location sheets, prop sheets, per-scene anchor frames |
| `mixio-script-breakdown` | `/mixio:script-breakdown` | Script → references/scenes/shots; canonical shot+scene schemas, camera enums, verbatim rules |
| `mixio-continuity` | `/mixio:continuity` | Four-pass text continuity audit before rendering |
| `mixio-chunking` | `/mixio:chunking` | Group shots into generation chunks + production summary for cost approval |

For a full episode, run `/mixio:pipeline` and let it gate the steps. The first six skills are MCP tool references; the last five encode the production procedure and can be invoked directly for a single step.

## Quick Start

```
# Generate media
studio_submit_studio_job(...)              → job id
studio_get_job_status({ jobId, projectId }) → wait for completed, get output URL

# Upload a local file
upload_file({ path: "/path/to/file.mp4" })  → public URL

# Evaluate an output
register_asset(...)                → @alias
run_evaluation(...)                → run_id (resp_...)
get_evaluation_result(run_id)      → status + results
```

`studio_*` tools are proxied from the Studio server — call `studio_tools_describe` for their current input schema, or `studio_tools_search` to discover more by keyword. `upload_file`, `register_asset`, `run_evaluation`, and `get_evaluation_result` are local to `@mixio-pro/mcp` itself (no `studio_` prefix, not covered by `studio_tools_describe`) — see the mixio-workspace/mixio-eval skills for their exact parameters.

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
