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
