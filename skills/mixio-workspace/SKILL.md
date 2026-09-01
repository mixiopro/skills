---
name: mixio-workspace
description: "Manage media workspaces in Mixio Studio — upload files, get public URLs, organize projects, and manage cached media assets."
version: 0.2.0
invoke: /mixio:workspace
---

# Mixio Workspace

Upload, organize, and retrieve media files in Mixio Studio workspaces. The MCP server handles local caching so repeated uploads are instant.

## Prerequisites

- MCP server configured in your agent: `@mixio-pro/mcp` (see INSTALL.md)

## MCP Tools

These are local tools implemented directly in `@mixio-pro/mcp` (no `studio_` prefix).

### `upload_file`

Upload a local file to Mixio Studio media and cache the path → URL mapping. Re-uploads only when the file's SHA-256 has changed (unless `force: true`).

| Param | Required | Notes |
|-------|----------|-------|
| `path` | yes | absolute or `~`-expanded local path |
| `project_id` | optional, but pass it | scope the media to a Mixio project — see below |
| `organization_id` | optional, but pass it | see below |
| `alt` | no | alt text/description |
| `category` | no | media category tag |
| `force` | no | re-upload even if cached |

**Pass `project_id`/`organization_id` whenever you have them.** The tool doesn't require a project — you never need to resolve or ask for one before calling `upload_file` — but if a project *is* already active in the session and you omit it anyway, the uploaded media persists with `projectId: null`. Nothing scopes it back to that project afterward; it just sits in the org's media pool, findable only by search. Resolve `organizationId` from the active project's org where you have it (`studio_get_project`), not by guessing.

Returns `{ ok: true, entry }` where `entry` includes `path`, `sha256`, `size`, `mediaId`, `url`, `absoluteUrl`, `filename`, `organizationId`, `projectId`, `uploadedAt`, `publicUrl` (= `absoluteUrl ?? url`), `extra`. On failure returns `{ ok: false, error, message }` with `error` one of `not_found`, `permission_denied`, `filesystem_error`, `upload_failed`. Check `entry.projectId` isn't `null` when you expected a scoped upload — the call succeeds either way, so a missing scope won't surface as an error.

### `get_public_url`

Get the public URL for a local file, re-hashing to detect drift. On a fresh cache hit, returns the cached URL; otherwise uploads (unless `upload: false`).

| Param | Required | Notes |
|-------|----------|-------|
| `path` | yes | |
| `upload` | no | defaults to `true`; set `false` for cache-only lookup |
| `project_id`, `organization_id`, `alt`, `category` | optional, but pass project/org if known | used only when uploading on a cache miss — same orphaning risk as `upload_file` if omitted |

Returns `{ ok: true, found, source, public_url, entry }` — `source` is `"cache"`, `"cache_sha256"`, or `"uploaded"`. With `upload: false` and no cache hit, returns `{ ok: true, found: false, public_url: null, entry: null }` (not a bare null).

### `list_cached_files`

No params. Returns `{ ok: true, count, entries }` — same entry shape as `upload_file`.

### `forget_path`

Remove one path from the cache (does not delete the remote media). `{ path }` → `{ ok: true, removed: boolean }`.

### `clear_cache`

No params. Drops every cached mapping (does not delete remote media). Returns `{ ok: true, cleared: <count> }`.

## Workflows

### Upload and share

```
1. upload_file({ path: "/renders/final-cut.mp4", project_id, organization_id })
   → { ok: true, entry: { publicUrl: "https://studio.mixio.pro/api/media/file/..." } }
2. Share entry.publicUrl — it's permanent and publicly accessible
```

### Batch upload a directory

```
1. For each file in directory:
     upload_file({ path, project_id, organization_id })
2. list_cached_files() to verify all uploaded
```

### Ingest external media URLs (Google Drive, CDNs, third-party hosts)

`studio_upload_media_from_url` often fails on external URLs (Google Drive, third-party CDNs) with `No files were uploaded` due to server-side SSRF or network policy restrictions. Always use the standardized 3-step download fallback:

```
1. curl -sL "<external_url>" -o /tmp/asset.png
2. upload_file({ path: "/tmp/asset.png", project_id, organization_id })
   → { ok: true, entry: { publicUrl: "https://studio.mixio.pro/api/media/file/..." } }
3. Pass entry.publicUrl to studio_update_reference or generation media slots
4. rm /tmp/asset.png (clean up local temp file)
```

### Re-upload after edits

```
1. Edit the local file
2. upload_file({ path: same_path, project_id, organization_id })
   → Detects content change (SHA-256), re-uploads, returns new URL
```

`project_id`/`organization_id` above are whatever project is active in the session — omit only when there genuinely isn't one (see "Pass `project_id`/`organization_id` whenever you have them" above).

## Supported formats

Inferred from file extension: `png`, `jpg`/`jpeg`, `webp`, `gif`, `svg`, `mp4`, `mov`, `webm`, `mp3`, `wav`, `m4a`, `ogg`, `json`, `txt`, `pdf`. Anything else uploads as `application/octet-stream`.

## Cache Location

Local cache is stored at `~/.mixio/mcp-cache.db` (SQLite, WAL mode — safe across concurrent sessions/processes). The cache maps local file path ↔ SHA-256 hash ↔ Mixio URL.

Override the cache path with `MIXIO_FASTMCP_CACHE`, or the whole `~/.mixio` state dir with `MIXIO_HOME`.

## Limits

Not exposed by the MCP server — check your Studio plan/dashboard for current upload size and storage limits.
