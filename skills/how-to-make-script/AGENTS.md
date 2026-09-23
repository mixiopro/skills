# AGENTS.md — How to Make Script

<!-- MANUAL: true -->
<!-- Parent: (root) -->

## Purpose

Agent skill monorepo providing durable, composable screenwriting knowledge infrastructure. Routes agent requests through intent/medium/stage/output classification into bounded knowledge bundles (protocol + rubric + reference atoms), generates structured artifacts, and self-checks before delivery.

## Key Files

| File | Role |
|------|------|
| `SKILL.md` | Root orchestration — entrypoint for all agent invocations |
| `pyproject.toml` | Python project metadata, dependencies, test config |
| `references/router-matrix.json` | Classification map: intent x medium x stage -> knowledge atoms |
| `references/routing-policy.md` | Decision rules for routing and bundle loading |
| `references/supported-outputs.md` | 30 output types with schemas |
| `examples/agent/fixtures.json` | 119 route fixtures for testing |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `skills/` | 29 composable sub-skills with individual SKILL.md files |
| `knowledge/` | 7-layer knowledge tree: 00-ontology, 10-foundations, 20-workflows, 30-craft, 40-media, 50-genre, 60-rubrics |
| `references/` | Router matrix, routing policy, output definitions, content model |
| `schemas/` | Machine-readable JSON schema definitions |
| `tests/` | 19 test modules for routing, schema, and contract validation |
| `scripts/` | 19 validation/consistency scripts |
| `examples/` | 10 golden flows + reference packs + quickstart fixtures |
| `docs/` | 17 pairs of bilingual (EN/ZH) documentation |

## For AI Agents

### Working Instructions
1. Entry point is `SKILL.md` — classify request by intent, medium, stage, output
2. Load `references/routing-policy.md` for routing rules
3. Use `references/router-matrix.json` for bundle lookup
4. Only load knowledge atoms the request requires — do not load all 189 files
5. Self-check output against rubric atoms in `knowledge/60-rubrics/`
6. When user pushes back, improve assets in `knowledge/` not the generated artifact

### Testing
```bash
python -m pytest tests/ -v
python scripts/validate_links.py
```

### Patterns
- Each skill in `skills/` has its own `SKILL.md` with trigger conditions
- Knowledge atoms are pure Markdown, routable by JSON matrix
- Golden examples in `examples/golden/` show complete request->artifact flows
- Python scripts validate structure, not writing quality

### Dependencies
- Python >= 3.9 (validation and scripting)
- No external Python packages required for core functionality
- Tests use `unittest` (stdlib)
