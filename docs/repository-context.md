# Repository context

- **Link project scope:** `skills` — pass `--project skills` to Link commands to include company/global context and this repository's scoped memories.
- **Owning Plane project:** `MIXSKILLS`
- **Repository:** `mixiopro/skills`
- **Purpose:** Public Mixio tool and production skills, contributor documentation, and skill distribution.
- **Entry points:**
  - [README.md](../README.md)
  - [CONTRIBUTING.md](../CONTRIBUTING.md)
  - [.claude-plugin/plugin.json](../.claude-plugin/plugin.json)
  - [.codex-plugin/plugin.json](../.codex-plugin/plugin.json)
  - [.cursor-plugin/plugin.json](../.cursor-plugin/plugin.json)
  - [install.sh](../install.sh)

> **Note:** Source entry points describe the maintained layout. If one is missing in an older or skeletal worktree, check that branch and the current source; do not invent files.

- **Boundaries:** The contributor operating skill lives under .agents/skills and carries the Skills CLI internal marker. Keep it outside the plugin production payload at skills/. Normal creative use follows production skills and needs no private Plane or shared Link access. Inspect the actual tool transport and schema before changing a documented contract.

## Local links

- [Repository instructions](../AGENTS.md)
- [Maintainer tracking protocol](tracking-protocol.md)
- [Contributor operating skill](../.agents/skills/mixio-maintainer/SKILL.md)
