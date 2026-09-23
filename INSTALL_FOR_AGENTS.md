# Install Mixio Skills (for AI agents)

Paste everything between the rules into your AI coding agent.

---

Set up Mixio for me by running the universal installer:

**On macOS & Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/mixiopro/skills/main/install.sh | bash
```

**On Windows:**
```powershell
irm https://raw.githubusercontent.com/mixiopro/skills/main/install.ps1 | iex
```

This single command will:
1. Create `~/.mixio` and `~/.agents` global directories.
2. Install all 13 Mixio skills (`mixio-*`) and place `AGENTS.md`.
3. Install the Mixio-owned `how-to-make-script` screenplay system, including its eight requested routes, protocols, rubrics, knowledge atoms, schemas, examples, license, and provenance.
4. Auto-configure the `@mixio-pro/mcp` MCP server in my agent configuration.
5. Register the skills to all installed AI coding agents.

After running the script, verify the connection with `studio_ping` and list my available projects with `studio_list_projects`.

---

## What you get

**Tools** — `upload_file` / `get_public_url` (upload local files, get public URLs), `list_cached_files` / `forget_path` / `clear_cache` (local upload cache), and hosted `studio_*` tools proxied from Studio (projects, episodes, elements, references, jobs, generation, evaluation). Call `studio_search_tools` to discover them and `studio_describe_tools` for exact input schemas.

**Skills** — 13 `mixio-*` skills. Start story work at `/mixio:screenwriting`, then use `/mixio:pipeline` for a full episode; see [AGENTS.md](./AGENTS.md) for the map and conventions.

The screenplay system is installed as a separate root skill because the eight writing routes depend on shared protocols, rubrics, knowledge atoms, schemas, and examples. Its source is vendored under `skills/how-to-make-script/`, so it can be customized and distributed through the same Mixio installer and `npx skills add mixiopro/skills` path.

One rule worth knowing up front: every tool is stateless, so there is no "current project" on the server. Confirm which project (and episode) you are working in before reading or writing anything — the skills require this explicitly.
