---
name: mixio-eval
description: "Run visual continuity and consistency evaluations on generated media via Mixio Studio's evaluation pipeline before delivery."
version: 0.1.0
invoke: /mixio:eval
---

# Mixio Eval

Run visual continuity / consistency evaluation jobs on generated or uploaded media via the Mixio MCP server. Use as a quality gate before delivering outputs to clients.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)

## MCP Tools

| Tool | Purpose |
|------|---------|
| `register_asset` | Register an uploaded asset under a project so it's referenceable in evaluations via an `@alias` |
| `run_evaluation` | Submit a visual continuity / consistency evaluation job |
| `get_evaluation_result` | Poll or retrieve the status and results of a background evaluation |

Call `studio_tools_describe` on any of these for the exact input schema before your first call — this skill doesn't hardcode parameters or scoring criteria since neither is documented outside the live tool definitions.

## Workflow

```
1. upload_file(local_path)              → public URL (see mixio-workspace)
2. register_asset(...)                  → @alias, referenceable in evaluations
3. run_evaluation(...)                  → evaluation job
4. get_evaluation_result(job_id)        → poll until complete, read results
```

## Tips

- Evaluate before delivering to clients — catches continuity/consistency issues early
- Use `studio_tools_search` if you're unsure which tool covers a given evaluation need
