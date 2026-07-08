---
name: mixio-workspace
description: "Manage media workspaces in Mixio Studio — upload files, get public URLs, organize projects, and manage cached media assets."
version: 0.1.0
invoke: /mixio:workspace
---

# Mixio Workspace

Upload, organize, and retrieve media files in Mixio Studio workspaces. The MCP server handles local caching so repeated uploads are instant.

## Prerequisites

- Mixio CLI installed: `npm install -g mixiocode && mixio setup`
- Or: MCP server configured in your agent

## MCP Tools

### `upload_file`

Upload a local file to Mixio Studio and get a public URL.

```json
{
  "tool": "upload_file",
  "arguments": {
    "path": "/path/to/video.mp4",
    "project_id": "optional-project-id"
  }
}
```

The file is uploaded once; subsequent calls return the cached URL unless the file content changes (SHA-256 checked).

**Supported formats:** mp4, mov, webm, mp3, wav, png, jpg, webp, svg, pdf

### `get_public_url`

Get the public URL for a previously uploaded file.

```json
{
  "tool": "get_public_url",
  "arguments": {
    "path": "/path/to/file.png",
    "upload": true
  }
}
```

- `upload: true` — upload if not cached (default)
- `upload: false` — cache lookup only, returns null if not found

### `list_cached_files`

List all files that have been uploaded and cached locally.

```json
{
  "tool": "list_cached_files",
  "arguments": {}
}
```

Returns: array of `{ path, url, sha256, uploaded_at, size_bytes }`

### `forget_path`

Remove a file from the local cache (does not delete from Studio).

```json
{
  "tool": "forget_path",
  "arguments": {
    "path": "/path/to/old-file.mp4"
  }
}
```

### `clear_cache`

Drop all cached file mappings. Next upload of any file will re-upload.

```json
{
  "tool": "clear_cache",
  "arguments": {}
}
```

## Workflows

### Upload and share

```
1. upload_file("/renders/final-cut.mp4")
   → { url: "https://cdn.mixio.pro/media/abc123.mp4" }
2. Share the URL — it's permanent and publicly accessible
```

### Batch upload a directory

```
1. For each file in directory:
     upload_file(path)
2. list_cached_files() to verify all uploaded
```

### Re-upload after edits

```
1. Edit the local file
2. upload_file(same_path)
   → Detects content change (SHA-256), re-uploads, returns new URL
```

## Cache Location

Local cache is stored at `~/.mixio/cache.db` (SQLite). The cache maps:
- Local file path → public URL
- SHA-256 hash → deduplication

## Limits

- Max file size: 500MB (video), 50MB (image/audio)
- Rate limit: 100 uploads/hour per API key
- Storage: unlimited on paid plans, 5GB on free tier
