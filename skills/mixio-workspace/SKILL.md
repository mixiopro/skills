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

`studio_upload_media_from_url` often fails on external URLs (Google Drive, third-party CDNs) with `No files were uploaded` due to server-side SSRF or network policy restrictions. Do **not** move that SSRF risk to the agent: this canonical Bash recipe (with `external_url` set to the user-provided URL) accepts only public `https` hosts, validates each redirect target before connecting, pins curl to the validated DNS answers, and bounds the download to 100 MiB. Use a unique temporary directory and clean up only that directory:

```sh
set -euo pipefail
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mixio-download.XXXXXX")"
download_path="$tmp_dir/source"
trap 'rm -rf -- "$tmp_dir"' EXIT
max_bytes=104857600 # 100 MiB

# Prints one curl --resolve rule, or fails. Literal-IP URLs, private/reserved addresses,
# credentials, non-HTTPS schemes, and non-default ports are deliberately rejected.
public_https_resolve() {
  node --input-type=module - "$1" <<'NODE'
import { lookup } from 'node:dns/promises';
import net from 'node:net';

const fail = message => { console.error(message); process.exit(1) };
const url = new URL(process.argv[2]);
if (url.protocol !== 'https:' || url.username || url.password || (url.port && url.port !== '443')) {
  fail('external URL must be credential-free https on port 443');
}
if (net.isIP(url.hostname)) fail('literal-IP external URLs are not allowed');
const records = await lookup(url.hostname, { all: true, verbatim: true });
if (!records.length) fail('external host resolved to no addresses');
const blocked = address => {
  if (net.isIP(address) === 4) {
    const [a, b, c] = address.split('.').map(Number);
    return a === 0 || a === 10 || a === 127 || a >= 224 ||
      (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && (b === 0 || b === 168)) ||
      (a === 192 && b === 0 && (c === 0 || c === 2)) || (a === 192 && b === 88 && c === 99) ||
      (a === 198 && (b === 18 || b === 19)) || (a === 198 && b === 51 && c === 100) ||
      (a === 203 && b === 0 && c === 113);
  }
  const value = address.toLowerCase();
  return value === '::' || value === '::1' || value.startsWith('fc') || value.startsWith('fd') ||
    /^fe[89ab]/.test(value) || value.startsWith('ff') || value.startsWith('2001:db8') ||
    value.startsWith('::ffff:');
};
if (records.some(({ address }) => blocked(address))) fail('external host resolved to a private or reserved address');
console.log(`${url.hostname}:443:${records.map(({ address }) => address).join(',')}`);
NODE
}

# Follow no more than five redirects manually so each next URL is checked and pinned.
next_url="$external_url"
for hop in 0 1 2 3 4; do
  resolve_rule="$(public_https_resolve "$next_url")"
  header_path="$tmp_dir/headers.$hop"
  curl --fail --silent --show-error --head --proto '=https' --proto-redir '=https' \
    --connect-timeout 10 --max-time 20 --resolve "$resolve_rule" \
    --dump-header "$header_path" --output /dev/null -- "$next_url"
  status="$(awk '/^HTTP\// { status=$2 } END { print status }' "$header_path")"
  location="$(awk 'tolower($0) ~ /^location:/ { sub(/^[^:]*:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit }' "$header_path")"
  if [ -z "$location" ]; then
    [ "$status" = 200 ] || { echo "unexpected response status: $status" >&2; exit 1; }
    break
  fi
  [ "$hop" -lt 4 ] || { echo 'too many redirects' >&2; exit 1; }
  next_url="$(node --input-type=module - "$next_url" "$location" <<'NODE'
console.log(new URL(process.argv[3], process.argv[2]).href)
NODE
)"
done

# `--location --max-redirs 0` fails closed if the GET changes into a redirect after validation.
resolve_rule="$(public_https_resolve "$next_url")"
(
  ulimit -f 204800 # 100 MiB in 512-byte blocks; caps chunked responses too
  curl --fail --silent --show-error --location --max-redirs 0 --proto '=https' --proto-redir '=https' \
    --connect-timeout 10 --max-time 120 --max-filesize "$max_bytes" --resolve "$resolve_rule" \
    --output "$download_path" -- "$next_url"
)

test -s "$download_path" || { echo "download was empty" >&2; exit 1; }
mime_type="$(file --brief --mime-type "$download_path")"
case "$mime_type" in
  image/jpeg) ext=jpg ;; image/png) ext=png ;; image/webp) ext=webp ;;
  image/gif) ext=gif ;; image/svg+xml) ext=svg ;; video/mp4) ext=mp4 ;;
  video/quicktime) ext=mov ;; video/webm) ext=webm ;; audio/mpeg) ext=mp3 ;;
  audio/wav|audio/x-wav) ext=wav ;; audio/mp4) ext=m4a ;; audio/ogg) ext=ogg ;;
  application/pdf) ext=pdf ;; application/json) ext=json ;; text/plain) ext=txt ;;
  *) echo "unsupported downloaded media type: $mime_type" >&2; exit 1 ;;
esac
asset_path="$tmp_dir/asset.$ext"
mv "$download_path" "$asset_path"
```

Then upload the MIME-validated file and pass its permanent URL onward:

```
upload_file({ path: asset_path, project_id, organization_id })
  → { ok: true, entry: { publicUrl: "https://studio.mixio.pro/api/media/file/..." } }
Pass entry.publicUrl to studio_update_reference or generation media slots
```

The `trap` removes only this run's temporary directory on success or failure. `--fail` prevents
HTTP error pages or login HTML from being uploaded as media, and the MIME-derived extension keeps
the upload format intact. Do not copy or weaken this recipe in another skill; link here so its
network restrictions stay consistent.

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
