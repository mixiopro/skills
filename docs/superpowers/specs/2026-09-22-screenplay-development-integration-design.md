# Screenplay Development Integration Design

**Status:** Approved for implementation; architecture revised to make screenplay development Mixio-owned and distributable.

## Problem

Mixio currently starts at a screenplay and specializes in production execution: references, scene and shot breakdown, continuity, model planning, generation, and evaluation. It does not provide a dedicated development loop for premise, character pressure, structure, scene writing, dialogue, or story-level rewrite diagnosis.

The upstream `XucroYuri/how-to-make-script` repository provides that missing writer-facing layer. Its eight requested skills are thin entry points into a larger set of protocols, rubrics, knowledge atoms, schemas, examples, and routing rules. Copying only the eight entry files would lose those dependencies.

## Goals

1. Make the complete upstream screenplay-development system available as Mixio-owned, editable assets.
2. Keep Mixio's production skills and MCP scope rules unchanged.
3. Make the handoff from story development to Mixio explicit and repeatable.
4. Prevent story diagnosis and visual-production audits from being confused with each other.
5. Keep the integration reproducible for future installations and updates.

## Non-goals

- Rewrite the upstream system from scratch or copy only its eight route entry files without their dependency graph.
- Modify Mixio Studio tools, schemas, generation behavior, or project data.
- Make the upstream repository responsible for shot generation or visual evaluation.
- Automatically approve or render a screenplay.

## Chosen architecture

### 1. Vendored upstream screenplay system

Vendor the complete upstream repository under `skills/how-to-make-script`, seeded from the reviewed `master` commit `68d179210687172d6c77b84e7c7d8d29ca865139`. Preserve its root router, route skills, workflow protocols, rubrics, knowledge atoms, schemas, examples, tests, and MIT license so the eight requested routes remain functional and editable in the Mixio repository.

The eight requested routes are upstream-derived but Mixio-owned after import:

`idea-discovery`, `logline-premise`, `character-world`, `structure-beat`, `scene-writing`, `dialogue-subtext`, `rewrite-doctor`, and `quality-gating`.

### 2. Local Mixio bridge

Add `skills/mixio-screenwriting/SKILL.md` as the local boundary skill. It will:

- identify story-development requests that should enter the vendored screenplay system;
- distinguish story-level quality work from Mixio's visual/reference/shot audits;
- require a handoff package before entering Mixio's pipeline;
- direct a completed handoff to Mixio Step 00/01, where the screenplay is persisted using the native grammar.

Add one focused reference file containing the handoff contract, artifact mapping, and re-entry rules.

### 3. Documentation and installation

Update the local README, AGENTS guidance, contributor guidance, and agent installer instructions so the combined flow is visible and reproducible. The existing skill-count guard will count the bridge as the thirteenth local skill.

The standard `npx skills add mixiopro/skills` path and the universal installers will install the vendored `how-to-make-script` root skill alongside the Mixio skills. The Mixio skill-count guard will continue counting only `mixio-*` skills, while a separate integration check validates the screenplay package and its provenance.

## Handoff contract

The upstream layer hands Mixio a small, explicit package:

- `medium`: feature film, episodic, short drama, animation, commercial, or another supported medium;
- `logline` and `premise`;
- `character_world`: pressure-oriented character and world notes;
- `structure`: beat sheet, outline, or treatment when applicable;
- `screenplay`: native-screenplay-ready scene blocks, or a scene draft that must be normalized in Mixio Step 01;
- `quality_gate`: hard failures, weighted weaknesses, correction status, and unresolved risks;
- `constraints`: tone, genre, audience, language, platform, duration, and IP/voice constraints.

Mixio owns conversion of that package into its native screenplay grammar, exact Cast & World mentions, scene/shot schemas, reference images, anchors, and generation jobs.

## Re-entry and invalidation

- A change to premise, character/world, structure, scene function, or dialogue that changes story intent requires re-running the upstream quality gate before Mixio Step 01 is considered locked.
- A change to the screenplay after Mixio Step 03 invalidates the downstream breakdown, continuity audit, shot plan, and any generated outputs that depend on it.
- A visual/reference problem discovered after handoff returns to the relevant Mixio step, not automatically to the upstream writing layer.

## Alternatives considered

### Copy only the eight upstream `SKILL.md` files

Rejected. The files reference upstream protocols, rubrics, knowledge atoms, and output contracts. This would create a superficially complete but functionally incomplete installation.

### Keep the upstream repository external only

Rejected after the ownership requirement was clarified. An external-only companion is not delivered by `npx skills add mixiopro/skills`, cannot be customized in the Mixio repository, and creates a second installation path. The vendored copy keeps the boundary explicit while making the writing system part of the distributable package.

### Replace Mixio's pipeline with the upstream router

Rejected. The upstream repository explicitly focuses on screenplay development and does not own Mixio's Studio scope resolution, reference persistence, shot schemas, billable generation, or visual evaluation.

## Success criteria

- `npx skills add mixiopro/skills` exposes `mixio-screenwriting` and the complete `how-to-make-script` root skill, including the eight requested routes and their dependencies.
- A request for a beat sheet, dialogue polish, rewrite diagnosis, or screenplay quality gate routes to the owned screenplay system.
- A request to create, normalize, persist, break down, generate, or visually evaluate a Studio production remains in Mixio.
- The handoff contract is documented and points to Mixio Step 01.
- Existing Mixio skill-count and documentation checks pass.
- No Mixio MCP tool or generation path changes.
