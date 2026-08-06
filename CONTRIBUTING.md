# Contributing to Mixio Skills

## Adding a New Skill

1. Create a directory: `skills/my-skill-name/`
2. Add `SKILL.md` with frontmatter (name, description, version, invoke)
3. Optionally add `references/` for detailed docs
4. Update the skills table in `README.md`
5. Submit a PR

## Skill Format

```markdown
---
name: skill-name
description: "One-line description"
version: 0.1.0
invoke: /mixio:skill-name
---

# Skill Title

## Prerequisites
## MCP Tools
## Workflows
## Tips
```

## Guidelines

- Keep skills focused — one domain per skill
- Include concrete MCP tool examples with JSON
- Document all parameters
- Add workflow examples showing tool chaining
- Include tips/pitfalls section
- If a production skill overlaps another (both sound like "audit before render", etc.), say so in the description: what it isn't (`Not X — that's mixio-y`) and where to go when unclear (`Unclear which step you need → mixio-pipeline`). The description is what routes an agent — a table in this README isn't enough.
- Once `SKILL.md` passes ~300 lines, split lookup-only content (field tables, closed enums, worked examples) into `references/*.md`, with a one-line pointer left in its place. Keep procedural/decision logic (the steps themselves) inline — only pull out material a given call doesn't always need.
- Run `./scripts/check-skill-count.sh` before opening the PR — it fails if the skill count drifts between `skills/`, the README badge/tables, and `AGENTS.md`.

## When a Studio tool is renamed

Grep the **whole repo**, not just `skills/`, for the old literal name before merging. `AGENTS.md`, `README.md`, and `INSTALL_FOR_AGENTS.md` reference tool names too, and a rename PR scoped to the skill files that use a tool will miss them:

```
grep -rn "old_tool_name" --include="*.md" .
```

This is how a stale `tools_search`/`tools_describe` example survived a real rename once already (PR #9 vs #12) — the rename PR touched the skill files; the root docs mentioning the same tools were a separate, unrelated PR that had already been opened before the rename landed and didn't get re-checked against it.
