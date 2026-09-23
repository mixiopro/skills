# Screenplay Development Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an editable, Mixio-owned `how-to-make-script` screenplay-development system and connect its story artifacts cleanly to the existing Mixio production pipeline.

**Architecture:** Vendor the complete upstream repository under `skills/how-to-make-script` so its router, protocols, rubrics, knowledge atoms, schemas, examples, and eight requested routes remain editable and installable through the existing Mixio package. Add one local `mixio-screenwriting` bridge that defines routing boundaries and the handoff contract, then update Mixio documentation and installers without changing Studio/MCP behavior.

**Tech Stack:** Vendored Markdown skills, Bash installer, PowerShell installer, shell integration checks, upstream provenance metadata.

**Spec:** `docs/superpowers/specs/2026-09-22-screenplay-development-integration-design.md`

## Global Constraints

- Keep the vendored screenplay system separate from Mixio production skills; do not copy only its eight entry files.
- Keep Mixio project/episode scope resolution and native screenplay grammar unchanged.
- Story development ends in a handoff package; Mixio Step 01 remains the source-of-truth persistence boundary.
- Do not submit Studio jobs, create projects, modify episodes, or spend generation credits.
- Preserve the existing 12-skill count guard and update all documented counts to 13 after adding `mixio-screenwriting`; count the vendored screenplay root separately.
- Preserve the upstream MIT license and record the source repository and reviewed commit in the vendored package.

---

### Task 1: Add the failing integration seam check

**Files:**
- Create: `scripts/check-screenplay-integration.sh`

**Interfaces:**
- Consumes: repository paths and text files in the current checkout.
- Produces: exit code 0 only when the local bridge, handoff reference, upstream source references, and installer/documentation hooks are present.

- [x] **Step 1: Write the failing check**

Create a shell check that uses `set -euo pipefail`, resolves the repository root from the script location, and asserts:

```bash
test -f "$root/skills/mixio-screenwriting/SKILL.md"
test -f "$root/skills/mixio-screenwriting/references/screenplay-handoff.md"
grep -q "how-to-make-script" "$root/skills/mixio-screenwriting/SKILL.md"
grep -q "screenplay-handoff" "$root/skills/mixio-screenwriting/SKILL.md"
grep -q "how-to-make-script" "$root/README.md"
grep -q "how-to-make-script" "$root/AGENTS.md"
grep -q "how-to-make-script" "$root/install.sh"
grep -q "how-to-make-script" "$root/install.ps1"
```

The check must print `OK: screenplay development integration is owned and documented` only after all assertions pass.

- [x] **Step 2: Run the check to verify it fails**

Run:

```bash
bash scripts/check-screenplay-integration.sh
```

Expected: FAIL because the bridge and its reference do not exist yet.

### Task 2: Add the local screenplay bridge and handoff contract

**Files:**
- Create: `skills/mixio-screenwriting/SKILL.md`
- Create: `skills/mixio-screenwriting/references/screenplay-handoff.md`

**Interfaces:**
- Consumes: the vendored root skill `how-to-make-script` and its eight requested routes.
- Produces: a local `/mixio:screenwriting` boundary that directs story work upstream and hands approved screenplay material to Mixio Step 00/01.

- [x] **Step 1: Write the bridge frontmatter and trigger boundary**

Use this frontmatter shape:

```yaml
---
name: mixio-screenwriting
description: "Use when developing a story before Studio production: idea discovery, logline, character/world, structure, scene writing, dialogue/subtext, story rewrites, or screenplay quality gates."
version: 0.1.0
invoke: /mixio:screenwriting
---
```

The body must state that the vendored `how-to-make-script` root skill is required, list the eight route names, and direct the agent to load only the matching route and dependencies rather than copying or paraphrasing the whole repository.

- [x] **Step 2: Add the boundary rules**

Document that:

- upstream owns premise, character pressure, structure, scene/dialogue craft, story-level diagnosis, and screenplay quality;
- Mixio owns native screenplay persistence, Cast & World references, sheets, anchors, shot breakdown, visual continuity, generation, and evaluation;
- `mixio-continuity` is not a substitute for `rewrite-doctor`, and `mixio-reference-audit` is not a substitute for `quality-gating`;
- no Studio scope lookup or billable job is needed for upstream-only writing work.

- [x] **Step 3: Write the handoff reference**

Define the required handoff fields as concrete keys: `medium`, `logline`, `premise`, `character_world`, `structure`, `screenplay`, `quality_gate`, and `constraints`. Explain that Mixio Step 01 normalizes source text into native screenplay grammar, retrieves exact reference mentions, and persists the draft; the upstream layer must not invent Studio IDs or `#` mention tokens.

- [x] **Step 4: Run the bridge check**

Run:

```bash
bash scripts/check-screenplay-integration.sh
```

Expected: PASS for the bridge and reference assertions, with documentation/install assertions still failing until Task 3.

### Task 3: Wire documentation and installer boundaries

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `INSTALL.md`
- Modify: `INSTALL_FOR_AGENTS.md`
- Modify: `install.sh`
- Modify: `install.ps1`

**Interfaces:**
- Consumes: `mixio-screenwriting` and the upstream GitHub repository.
- Produces: reproducible setup instructions and runtime guidance for the combined writing-to-production flow.

- [x] **Step 1: Update skill counts and tables**

Change the badge and installation text from 12 to 13. Add `mixio-screenwriting` to the local skill tables with the description “Story development bridge to the upstream screenplay-writing companion.” Keep the existing `scripts/check-skill-count.sh` patterns valid.

- [x] **Step 2: Add the AGENTS handoff section**

Before Mixio Step 00, add a story-development entry point that routes the eight named tasks to `how-to-make-script`, then states the handoff sequence:

```text
story development → screenplay handoff → Mixio Step 00/01
→ sheets → reference audit → breakdown → continuity → shot planning → generation/eval
```

State that edits after Step 03 invalidate downstream production planning and renders.

- [x] **Step 3: Document installation**

Document that the standard Mixio installation already includes the vendored screenplay system. The repository must retain the complete upstream dependency graph rather than downloading only eight route files at install time.

```bash
npx skills add mixiopro/skills -g -y
```

Explain that this copies the owned `how-to-make-script` root skill recursively, including the eight requested routes and their shared protocols, rubrics, knowledge atoms, schemas, and examples.

- [x] **Step 4: Extend the Unix installer**

Ensure the Unix installer registers both `mixio-*` skills and the vendored `how-to-make-script` root skill to each supported agent directory. Do not perform a second network clone of the upstream repository.

- [x] **Step 5: Extend the PowerShell installer**

Mirror the Unix behavior with the existing PowerShell conventions: register the vendored root skill alongside the Mixio skills, preserve its nested dependency tree, and avoid a second network clone.

- [x] **Step 6: Run documentation and skill-count checks**

Run:

```bash
bash scripts/check-skill-count.sh
bash scripts/check-screenplay-integration.sh
```

Expected: both PASS and report 13 local skills.

### Task 4: Vendor and verify the upstream screenplay system

**Files:**
- Create: `skills/how-to-make-script/` from the reviewed upstream repository.
- Create: `skills/how-to-make-script/UPSTREAM.md`
- Preserve: `skills/how-to-make-script/LICENSE`

**Interfaces:**
- Consumes: the reviewed public GitHub repository `XucroYuri/how-to-make-script` at commit `68d179210687172d6c77b84e7c7d8d29ca865139`.
- Produces: a complete Mixio-owned root skill with its router and all referenced assets, installable by the existing `npx skills add mixiopro/skills` flow.

- [x] **Step 1: Import the complete upstream tree**

Import the repository contents without its `.git` directory under `skills/how-to-make-script/`; preserve the upstream `LICENSE`, route directories, knowledge, references, schemas, examples, and tests.

- [x] **Step 2: Record provenance and ownership**

Add `UPSTREAM.md` naming the source repository, reviewed commit, import date, license, and the rule that future upstream updates must be reviewed before replacing the owned copy.

- [x] **Step 3: Verify the dependency graph is present**

Run the integration check against the vendored root, all eight requested route files, `knowledge/20-workflows`, `knowledge/60-rubrics`, `references`, `schemas`, and `LICENSE`.

- [x] **Step 4: Verify standard discovery**

Run `npx skills add . --list` and confirm that it discovers the Mixio skills plus the vendored `how-to-make-script` root skill. Run with `--full-depth` to confirm the nested upstream route files remain discoverable for development.


### Task 5: Validate the combined flow and perform final review

**Files:**
- Test: `scripts/check-skill-count.sh`
- Test: `scripts/check-screenplay-integration.sh`
- Review: all files changed in Tasks 2–4.

**Interfaces:**
- Consumes: local Mixio skills and the vendored screenplay system.
- Produces: verified documentation-only integration with no Studio-side mutations.

- [x] **Step 1: Run shell validation**

```bash
bash scripts/check-skill-count.sh
bash scripts/check-screenplay-integration.sh
```

- [x] **Step 2: Run a route-boundary inspection**

```bash
rg -n "idea-discovery|logline-premise|character-world|structure-beat|scene-writing|dialogue-subtext|rewrite-doctor|quality-gating|mixio-screenwriting|Step 01|Step 03" \
  README.md AGENTS.md INSTALL.md INSTALL_FOR_AGENTS.md skills/mixio-screenwriting
```

Confirm that story routes point upstream and production routes point to Mixio, with no instruction to call Studio for upstream-only work.

- [x] **Step 3: Review the diff for scope**

```bash
git diff --check
git status --short
```

Confirm there are no Studio API calls, credentials, generated media, or unrelated refactors.

- [x] **Step 4: Report the installed companion and verification results**

Report the upstream destination, the local bridge path, the two passing checks, and the fact that no Studio production data was changed.
