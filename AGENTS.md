# Mixio Skills

Agent guidance for this repository. You have access to Mixio Studio through the `@mixio-pro/mcp` MCP server; these skills document what to call, in what order, and what each step must produce.

## Resolve scope before doing anything (required)

Every Mixio tool is stateless — there is no "current project" on the server. Every project-scoped mutation must receive the resolved `projectId` (in `context.projectId` for generation submissions). Hosted 1.1.0 preflights project access and target ownership before any mutation, including every target in a bulk call; a missing or foreign target rejects the call before writes begin. This includes `update_element`, `revise_shot_specs`, `update_shot_state`, `update_reference`, and `bulk_update_elements`. Never omit scope or substitute an unconfirmed project ID to bypass a rejection.

```
projectId unknown?  studio_list_projects()              → show numbered list → ASK
episodeId needed?   studio_list_episodes({ projectId })  → show numbered list → ASK
exactly one option? say which you're using, continue — no question needed
either empty?       say so, offer to create, confirm first
then                restate the resolved scope once so a wrong pick surfaces early
```

**Show the list in the same message as the question.** Asking "which episode are you working on?" without enumerating them is a failure — it hands the lookup back to the user. Resolve scope *before* any expensive read: `list_episodes` is cheap, `get_production_context` returns 100K+ characters.

Never guess an id, infer one from a title, or create a project or episode to avoid asking. Pass the **deepest** scope you know on every call — `submit_studio_job`'s `context` takes `{ projectId, episodeId?, sceneId?, shotId? }`, and a job without `shotId` cannot be displayed under that shot.

Note that `Shot 2.2` means scene 2, shot 2 *of some episode* — numbering restarts per scene and per episode, so that label exists in every episode and is under-specified until the episode is known. Only `mixio-workspace`'s upload tools are genuinely project-free *as a precondition* — you don't need to resolve/ask for project scope before calling them, unlike everything else in this section. That's not permission to omit `project_id`/`organization_id` when you already have them: those params are optional on the tool (uploading with no active project at all is a real, supported case), but leaving them off when a project *is* active in the session orphans the media — its `projectId` persists as `null` and nothing scopes it back to the production it was uploaded for. Pass what you know.

## Tool names across transports

These skills are written for the officially documented setup — `@mixio-pro/mcp` as
your MCP server. That proxy prefixes every tool it forwards from Studio with
`studio_` (`studio_list_projects`, `studio_get_element`, ...) to keep them apart
from its own local-only file tools, which are never prefixed: `upload_file`,
`get_public_url`, `list_cached_files`, `forget_path`, and `clear_cache`.

On a different transport — a client talking to the hosted MCP endpoint directly, or
[mixio-cli](https://github.com/mixiopro/mixio-cli) — there is no `studio_` prefix:
`studio_list_projects` is `list_projects`. Same tool, same schema, same server, only
the name differs. When in doubt, `search_tools`/`describe_tools` (or
`mixio list-tools`/`mixio call <tool> --help`) always reflect what your current
transport actually exposes.

Hosted evaluation uses `evals_list_evaluation_catalog`, `evals_evaluate_media`,
and `evals_get_evaluation_result`, all scoped to the confirmed Studio `projectId`.
The local bridge prefixes these names with `studio_`. Resolve scope using Studio
`list_projects` (or `studio_list_projects` over stdio). Read `mixio-eval` for the
canonical contract and aliases retained through hosted 1.1.x.

## Data model

A **project** holds episodes and a Cast & World roster. An **episode** owns a raw Idea/Story fallback (`script`), an optional native `SCREENPLAY` element, scenes and shots. A non-empty screenplay body (even draft) is the source breakdown prefers; raw `script`/`metadata.fullScript` is only the fallback. Cast & World (characters, locations, props) is **project**-scoped and feeds generation for consistency, so it outlives any one episode.

## Skills

**Tool skills** — the MCP surface. Safe to use standalone.

| Skill | Invoke | Use for |
|-------|--------|---------|
| `mixio-project` | `/mixio:project` | Project CRUD, whole-graph reads |
| `mixio-references` | `/mixio:references` | Cast & World, reference images, project reference policy |
| `mixio-episode` | `/mixio:episode` | Episode CRUD, script, scene/shot primitives, relations |
| `mixio-generate` | `/mixio:generate` | Image, video and audio jobs |
| `mixio-workspace` | `/mixio:workspace` | Upload local files, get permanent URLs |
| `mixio-eval` | `/mixio:eval` | Post-render media continuity; compare reference images only when the live catalog supports the required evidence |

**Screenplay development bridge** — use before production when the request is about story craft.

| Skill | Invoke | Use for |
|-------|--------|---------|
| `mixio-screenwriting` | `/mixio:screenwriting` | Route idea discovery, logline/premise, character/world, structure/beat, scene writing, dialogue/subtext, rewrite diagnosis, and screenplay quality gating to the complete Mixio-owned `how-to-make-script` system. |

The `how-to-make-script` root skill is vendored under `skills/how-to-make-script/` and is Mixio-owned for customization. Keep its shared protocols, rubrics, knowledge, schemas, examples, license, and `UPSTREAM.md` provenance intact when changing the eight route skills.

**Production skills** — the procedure, the schemas and the gates.

| Skill | Invoke | Use for |
|-------|--------|---------|
| `mixio-pipeline` | `/mixio:pipeline` | **Start here for a full episode, and whenever it's unclear which production skill applies.** Local director plan and Continuity Checklist, approved Studio sync, reference readiness, shot planning, and generation |
| `mixio-sheets` | `/mixio:sheets` | Build or enrich approved character defaults/variants, location configurations/views, prop sheets, and per-scene anchors after the breakdown is accepted |
| `mixio-reference-audit` | `/mixio:reference-audit` | Audit the accepted plan against reference looks/views, visual evidence, Cast & World consistency, duplicates, and metadata before generation |
| `mixio-script-breakdown` | `/mixio:script-breakdown` | Enrich a supplied/existing scene-and-shot breakdown, or create one from the script when absent; prepare an approval-gated Studio diff |
| `mixio-continuity` | `/mixio:continuity` | Director-led Continuity Checklist covering scene, shot, cross-scene/shot risks and missing coverage before Studio sync; pair `/mixio:eval` with rendered media |
| `mixio-shot-planning` | `/mixio:shot-planning` | 6 structural archetypes (incl. `MULTI_CUT` 10–15s) + model matching, execution audit, and batches |

For story work, start with `/mixio:screenwriting`; do not look up a Studio project or episode until the screenplay handoff is ready. For production work, use `/mixio:pipeline` to coordinate the gated steps. Invoke a production skill directly when you only need that one step — each one's description says which of its siblings it isn't, and falls back to `mixio-pipeline` when that's still unclear.

## Default production stance — the director’s lens

For Mixio production work, reason from audience intent and point of view through dramatic change, character/prop state, geography, coverage, shot-to-shot flow, expression, and feasibility. Bring in relevant craft perspectives—cinematography, production design, costume, props, script supervision, editing, sound, action, VFX, and production management—when the decision needs them. Apply the shared [director’s lens](skills/mixio-pipeline/references/directors-lens.md) during setup, reference work, breakdown, shot planning, generation, and evaluation. These are focused checks, not simulated approvals or authority to override the user: preserve screenplay facts and approved direction, label inferences, and surface story-changing, conflicting, or feasibility-driven choices for review. For mechanical tool work, carry accepted direction forward without reopening it.

For a full multi-step episode run, use the host’s native task/plan surface when available, and use a persistent goal only when the user asks for cross-turn continuation. Follow [agent-native tracking](skills/mixio-pipeline/references/agent-native-tracking.md); native progress is never a production record or approval.

## Order matters

```
PRE Story development + screenplay handoff → Mixio-owned `how-to-make-script` via `/mixio:screenwriting` when requested
00  Project + episode setup → resolve scope; read the current screenplay/script, references, shots, settings, and available images
01  Local shot plan         → /mixio:script-breakdown — enrich a supplied/existing breakdown, or create one if absent; preserve authored direction and plan generated video totaling at least 1.2× the final runtime with purposeful surplus coverage
02  Continuity Checklist   → /mixio:continuity — write scene, shot, and cross-scene checks; identify generation risks and missing coverage
03  Review + sync           → show exact Studio diff; wait for approval; sync and verify by readback
04  Reference readiness     → /mixio:reference-audit; build missing sheets/anchors with /mixio:sheets
05  Shot planning           → /mixio:shot-planning — select methods/models, validate feasibility, review the production plan
06  Generation              → /mixio:generate per approved batch, then /mixio:eval before delivery
```

The local plan is a review artifact in the agent’s working context. Preserve the source screenplay unchanged. Mark proposed shot direction as `SCRIPTED`, `INFERRED`, or `OPEN DECISION`; missing sheets and anchors are readiness gaps, not blockers to local planning. Corrections stay in the local draft.

Before any breakdown write, show the completed plan and exact Studio diff. Match updates to confirmed element IDs; flag ambiguous matches and unmatched existing shots, and never silently overwrite or delete them. Wait for explicit approval, then sync through existing primitives and read back persisted scenes, shots, and relations. Build missing sheets and anchors from the accepted plan before generation; image generation remains separately confirmed.

## Conventions

- Call `studio_describe_tools` before using an unfamiliar tool, and `studio_get_use_case_input_schema` before submitting an unfamiliar generation use case. Don't guess parameters.
- Read `settings.references` on the project before creating references — `createPolicy` and `variantPolicy` can forbid writes this repo otherwise describes.
- Before authoring a screenplay, read `skills/mixio-episode/references/screenplay-grammar.md`, call `studio_list_references({ projectId, limit })`, and copy exact `mentionableLooks` values for `#name.variant[.view]`; never hand-build a mention. Preserve `~location.landmark[.placement]` locks and standalone `[Key: Value · Key: Value]` paragraphs through breakdown. `studio_upsert_screenplay` writes a draft only; approval remains a human Studio action.
- The normal breakdown path reads the current screenplay (non-empty native `SCREENPLAY` body first, then raw `script`/`metadata.fullScript`) without rewriting it. Plan locally and obtain approval for the exact diff before any scene, shot, or relation mutation.
- Shot metadata keys are `snake_case`; scene metadata keys are `camelCase`. Mixing them up is not rejected — the write boundary is permissive, so a mixed-up key is remapped or warned-and-passed-through, not thrown. It still lands in the wrong place (passthrough, unread by anything) and fails silently rather than loudly, which is worse: check by reading back what you wrote.
- Never write a placeholder (`TBD`, `unknown`, `n/a`) to satisfy a required field. Readers filter those, so the shot persists and renders blank.
- **MCP generation reference binding**: Put images in the use-case schema’s `input.media` slots and bind prompt mentions with one public map: `{ "@tag": "exact URL from input.media" }`. Every map key must appear in the prompt; every mapped URL must match one media URL in this job; URLs must be unique. Reject missing, mismatched, duplicate, unused bindings and prompt tags without bindings. MCP callers must not send `slotTags` or a separate human-label map: the adapter derives Studio’s internal slot bindings and display labels from mention tags and reference metadata. `slotReferences` is normally derived from `input.media`; pass it only to override reference metadata or element links. Each batch job has its own `mentionMap`. Use the live use-case schema for model-specific media slots and parameters.
- Upload final outputs with `upload_file` for permanent URLs, and use `studio_evals_evaluate_media` plus `studio_evals_get_evaluation_result` before delivering to a client.
- Generation is billable. Ask before video unless the user has already authorized it; do not add a separate cost-review approval gate.

## MCP server

```json
{
  "mcpServers": {
    "mixio": {
      "command": "npx",
      "args": ["-y", "@mixio-pro/mcp@0.6.0"],
      "env": { "MIXIO_API_KEY": "your-key" }
    }
  }
}
```

`studio_*` tools are proxied from the Studio server. `upload_file`, `get_public_url`, `list_cached_files`, `forget_path`, and `clear_cache` are local to `@mixio-pro/mcp`; evaluation uses the hosted `evals_*` tools under the bridge's `studio_` prefix.

## Scope

Final assembly — stitching, mixing, export, timeline rendering — is not part of the MCP surface. The pipeline delivers approved per-batch video, not a finished cut.

<!-- BEGIN MIXIO TRACKING v2026-09-12.1 -->
## Maintainer tracking checkpoints

For Mixio contributor planning, implementation, review, or task recovery, read [.agents/skills/mixio-maintainer/SKILL.md](.agents/skills/mixio-maintainer/SKILL.md) and [docs/repository-context.md](docs/repository-context.md) before material work, after scope changes, and before handoff. Apply [docs/tracking-protocol.md](docs/tracking-protocol.md) for live Plane scope, explicit shared Link roots, and Paseo workspaces. Keep unresolved policy visible and report implemented, verified, merged, and deployed separately. This governs contributor changes: public skill users and normal creative production need no private tracking setup. Founder Office financial/commercial and Outline ownership remains intact.
<!-- END MIXIO TRACKING -->
