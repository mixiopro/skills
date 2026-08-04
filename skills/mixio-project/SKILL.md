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

## Context preflight — required before any read or write

**Never operate on a guessed project or episode.** Every Mixio tool is stateless: there is no "current project" on the server, so whatever id you pass *is* the scope. An id carried over from an earlier task, inferred from a name, or invented will silently read and write the wrong production — and most element-level write tools do not verify project scope, so nothing will stop you.

At the start of a session, and again whenever the target is unclear:

```
1. projectId not known?
     studio_list_projects()  → present a numbered list (title, status, id)
     → ASK the user to choose. Do not pick for them. Do not create a new project
       to avoid asking.
2. episodeId needed and not known?
     studio_list_episodes({ projectId })  → present a numbered list
     → ASK the user to choose.
3. Either list empty?
     Say so and offer to create one, with explicit confirmation before creating.
4. Restate the resolved scope once, so the user can catch a wrong pick early:
     "Working in <project title> (<id>), episode <n> — <title> (<id>)."
```

Hold the resolved ids for the rest of the session and pass them on every call. Re-confirm if the user switches subject, mentions a different title, or returns after a long gap.

**Scope depth matters as much as correctness.** When you know the scene and shot, pass them too — `submit_studio_job`'s `context` takes `{ projectId, episodeId?, sceneId?, shotId? }`, and a job that omits `shotId` cannot be shown under that shot. Same for the `tags.episodeId` that scopes element queries.

Only `mixio-workspace`'s `upload_file` family is genuinely project-free. Everything else needs at least a project.

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
