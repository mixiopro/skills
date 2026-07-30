---
name: mixio-project
description: "Create and manage Mixio Studio projects, and read the full production graph (cast/world + scenes + shots) for context before making changes."
version: 0.1.0
invoke: /mixio:project
---

# Mixio Project

A **project** is the top-level container in Mixio Studio. It holds episodes (script/breakdown/shots — see `mixio-episode`) and a Cast & World roster of characters/locations/props (see `mixio-references`). This skill covers the project container itself and whole-graph reads.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)

## MCP Tools

All proxied `studio_*` tools. Call `studio_tools_describe` for exact current schemas.

| Tool | Purpose |
|------|---------|
| `studio_create_project` | Create a project (`title` required; `logline`, `projectStatus`, `genre`, `teamId` optional) |
| `studio_get_project` | Get a project by `projectId` |
| `studio_update_project` | Update `title`/`logline`/`projectStatus`/`genre`/`settings` |
| `studio_delete_project` | Delete a project by `projectId` |
| `studio_list_projects` | List projects for the active organization (`limit`, `offset`) |
| `studio_get_production_context` | Read the full graph: canonical characters/locations/props plus scene/shot summaries, optionally scoped to one episode |

### `studio_get_production_context` — read this before writing

```
{ projectId, episodeId? }
→ { project, episode, canonical: { characters, locations, props }, scenes, shots }
```

**This routinely returns 100K+ characters on a real production** and will exceed your harness's inline token limit — expect the result to spill to a file with grep/paginate guidance, not fail. Don't call it expecting a small response; if you only need one entity, use a scoped read instead (`studio_get_element`, `studio_list_references`, `studio_list_episodes`) rather than the whole graph.

## Workflow

```
1. studio_list_projects() / studio_create_project({ title, ... })   → find or create the project
2. studio_get_production_context({ projectId })                     → understand what already exists
3. → mixio-references for cast/world (characters, locations, props)
4. → mixio-episode for episodes, script, scene/shot breakdown
```

## Notes

- `projectStatus` enum: `development`, `pre-production`, `production`, `post-production`, `released`. Defaults to `development` on create.
- `teamId` on create is optional and scopes the project to a team — the calling API key's user must already be a member; omit for an organization-wide project.
- Deletes are hard deletes (no soft-delete/trash for projects) — confirm before calling `studio_delete_project`.
