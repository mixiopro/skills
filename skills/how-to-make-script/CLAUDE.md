# CLAUDE.md — How to Make Script

## Project Identity
- **Name**: how-to-make-script
- **Type**: Agent skill monorepo for screenplay creation knowledge
- **Stack**: Python 3.9+ (validation/scripts) + Markdown knowledge base + Agent Skill orchestration
- **Remote**: `origin` = https://github.com/XucroYuri/how-to-make-script

## Quick Reference

```bash
python --version          # Python >= 3.9
pip install -e ".[dev]"   # Install with dev dependencies
python -m pytest tests/   # Run tests
python scripts/validate_links.py  # Validate internal link integrity
```

Alternatively, just read the `.venv/` for a pre-configured virtualenv.

## What This Is

A research-first open source agent skill monorepo for screenplay creation knowledge. It classifies requests by intent, medium, stage, and desired output, then loads only the relevant knowledge (protocol, rubric, and reference atoms) to produce structured artifacts.

**Not** a prompt dump, single-method gospel, or UI-first product.

### Key Numbers
- 29 sub-skills in `skills/`
- 30 output types
- 114 knowledge atoms across 189 .md files
- 33 workflow protocols in `knowledge/20-workflows/`
- 31 evaluation rubrics in `knowledge/60-rubrics/`
- 19 test modules + 19 validation scripts
- 10 golden example flows

## Architecture

```
Request in
  → SKILL.md (root orchestration, classification)
    → skills/<sub-skill>/SKILL.md (domain-specific skill execution)
      → knowledge/ (routable atoms: ontology, foundations, workflows, craft, media, genre, rubrics)
        → references/ (router matrix, routing policy, supported outputs, content model)
```

### Directory Map

| Directory | Purpose |
|-----------|---------|
| `skills/` | 29 sub-skills (structure-beat, rewrite-doctor, quality-gating, etc.) |
| `knowledge/` | 7-layer knowledge tree: ontology, foundations, workflows, craft, media, genre, rubrics |
| `references/` | Router matrix, routing policy, supported outputs, content model |
| `schemas/` | Machine-readable schema definitions |
| `tests/` | 19 test modules validating routing, schemas, and skill behavior |
| `scripts/` | 19 validation scripts for link integrity, consistency checks |
| `examples/` | Golden flows, reference packs, quickstart fixtures |
| `docs/` | Bilingual documentation (17 pairs EN/ZH) |

## Working With This Repo

1. **SKILL.md is the entrypoint** — all agent invocation starts here
2. **Knowledge is routable** — `references/router-matrix.json` maps intent x medium x stage to knowledge atoms
3. **Skills are composable** — sub-skills in `skills/` chain together, each with their own SKILL.md
4. **Tests validate routing, not writing quality** — tests check that classification and bundle loading work correctly
5. **Python is glue** — the real content is Markdown; Python validates structure and contracts

## Agent Working Instructions

- When invoked as a skill, follow `SKILL.md` — classify first, then route
- Read `references/routing-policy.md` before making routing decisions
- Use `references/router-matrix.json` to look up correct knowledge bundles
- Load only what the request needs — do not load all 189 knowledge files
- Self-check output against rubric atoms from `knowledge/60-rubrics/`
- Do not modify `knowledge/` atoms directly unless a test validates the change

## Development Rules

1. **No speculative additions** — every new knowledge atom needs a test or fixture
2. **Test before changing routing** — routing changes need fixture updates
3. **Keep Markdown valid** — all .md files must pass `scripts/validate_links.py`
4. **Bilingual parity** — Chinese and English docs should stay in sync
5. **Commit format**: `docs:`, `feat:`, `fix:`, `test:` with bilingual descriptions

## Avoid

- Adding AI-generated content to `knowledge/` without human review
- Hardcoding specific LLM behaviors in skill definitions
- Removing validation scripts without replacement
- Mixing knowledge layers (e.g., putting craft-level atoms in rubric layer)
