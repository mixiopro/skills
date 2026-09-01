# Mixio Skills

Agent guidance for this repository. You have access to Mixio Studio through the `@mixio-pro/mcp` MCP server; these skills document what to call, in what order, and what each step must produce.

## Resolve scope before doing anything (required)

Every Mixio tool is stateless — there is no "current project" on the server, so whatever id you pass *is* the scope. Most element-level write tools (`update_element`, `revise_shot_specs`, `update_shot_state`, `update_reference`, `bulk_update_elements`) take no `projectId` and verify no project scope, so a stale or invented id writes to the wrong production silently.

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
from its own local-only tools, which are never prefixed: `upload_file`,
`get_public_url`, `register_asset`, `run_evaluation`, `get_evaluation_result`.

On a different transport — a client talking to the hosted MCP endpoint directly, or
[mixio-cli](https://github.com/mixiopro/mixio-cli) — there is no `studio_` prefix:
`studio_list_projects` is `list_projects`. Same tool, same schema, same server, only
the name differs. When in doubt, `search_tools`/`describe_tools` (or
`mixio list-tools`/`mixio call <tool> --help`) always reflect what your current
transport actually exposes.

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
| `mixio-eval` | `/mixio:eval` | Visual continuity evaluation of rendered media |

**Production skills** — the procedure, the schemas and the gates.

| Skill | Invoke | Use for |
|-------|--------|---------|
| `mixio-pipeline` | `/mixio:pipeline` | **Start here for a full episode, and whenever it's unclear which production skill applies.** Six gated steps + resumable state |
| `mixio-sheets` | `/mixio:sheets` | Character turnarounds, location sheets, prop sheets, per-scene anchors |
| `mixio-reference-audit` | `/mixio:reference-audit` | Audit Cast & World for completeness, consistency, duplicates, metadata quality |
| `mixio-script-breakdown` | `/mixio:script-breakdown` | Script → references, scenes, shot specs against the canonical schemas |
| `mixio-continuity` | `/mixio:continuity` | Four-pass text continuity audit, before anything renders |
| `mixio-shot-planning` | `/mixio:shot-planning` | Generation method + model per shot, feasibility, batches, production summary for cost approval |

For a full episode run `/mixio:pipeline` and let it gate the steps. Invoke a production skill directly when you only need that one step — each one's description says which of its siblings it isn't, and falls back to `mixio-pipeline` when that's still unclear.

## Order matters

```
00  lock aspect_ratio (delivery) + anchor_aspect_ratio (wider, for anchors)
01  Screenplay        → `studio_upsert_screenplay` draft; source of truth when non-empty
02  Sheets + anchors  → /mixio:sheets      — references must exist before shots reference them
02.5 Reference audit  → /mixio:reference-audit — completeness, consistency, duplicates, metadata
03  Shot breakdown    → /mixio:script-breakdown
04  Continuity audit  → /mixio:continuity  — text only, free, catches logic
05  Shot planning     → /mixio:shot-planning — then get cost approval
06  Generation        → /mixio:generate per batch, then /mixio:eval before delivery
```

Steps 01, 02.5, 03, 04 and 05 cost only tokens. That is the point: a continuity break caught in step 04 costs a paragraph; the same break caught in step 06 costs a re-render.

Sheets come **before** the breakdown because the breakdown emits references as shallow stubs (`name`, `description`, `attributes`) and writes no `characterDetails` or `locationDetails`. Build the sheets first and the breakdown reuses their canonical names instead of minting near-duplicates.

## Conventions

- Call `studio_describe_tools` before using an unfamiliar tool, and `studio_get_use_case_input_schema` before submitting an unfamiliar generation use case. Don't guess parameters.
- Read `settings.references` on the project before creating references — `createPolicy` and `variantPolicy` can forbid writes this repo otherwise describes.
- Before authoring a screenplay, read `skills/mixio-episode/references/screenplay-grammar.md`, call `studio_list_references({ projectId, limit })`, and copy exact `mentionableLooks` values for `#name.variant[.view]`; never hand-build a mention. Preserve `~location.landmark[.placement]` locks and standalone `[Key: Value · Key: Value]` paragraphs through breakdown. `studio_upsert_screenplay` writes a draft only; approval remains a human Studio action.
- Shot metadata keys are `snake_case`; scene metadata keys are `camelCase`. Mixing them up is not rejected — the write boundary is permissive, so a mixed-up key is remapped or warned-and-passed-through, not thrown. It still lands in the wrong place (passthrough, unread by anything) and fails silently rather than loudly, which is worse: check by reading back what you wrote.
- Never write a placeholder (`TBD`, `unknown`, `n/a`) to satisfy a required field. Readers filter those, so the shot persists and renders blank.
- **Mandatory prompt `@` mentions & paired mention maps (Universal across all generations & models)**: Prompts MUST ALWAYS contain `@` mentions for all active media assets/references (e.g. `@asset1`, `@tony`, `@scene1`). This applies universally to all generation types (image, keyframe, video, storyboard) and all models (Hailuo, Kling, Seedance, Veo, Sora, Gemini, Wan, LTX, etc.). Any asset passed via `media` (`primary`, `references`, `character_ref`, `location_ref`, `enhancer_context`) must be embedded in the prompt string where the subject acts. Paired `slotTags` (`{ [assetKey]: '@tag' }`) AND `mentionMap` (`{ '@tag': 'Human Label / Description' }`) are MANDATORY whenever media references are provided. Without both paired maps and prompt `@` tokens, the prompt materializer and provider compilers cannot ground assets to model-specific tokens or resolve subject identity, causing models to guess identity and waste generation credits. Validate prompt `@` mentions and mention maps in Step 05 (`mixio-shot-planning`) and Step 06 (`mixio-generate`) preflight before submitting billable jobs.
- Upload final outputs with `upload_file` for permanent URLs, and run `run_evaluation` before delivering to a client.
- Generation is billable. Ask before video unless the user has said otherwise.

## MCP server

```json
{
  "mcpServers": {
    "mixio": {
      "command": "npx",
      "args": ["-y", "@mixio-pro/mcp"],
      "env": { "MIXIO_API_KEY": "your-key" }
    }
  }
}
```

`studio_*` tools are proxied from the Studio server. `upload_file`, `get_public_url`, `register_asset`, `run_evaluation` and `get_evaluation_result` are local to `@mixio-pro/mcp` and are **not** covered by `studio_describe_tools` — see `mixio-workspace` and `mixio-eval` for their parameters.

## Scope

Final assembly — stitching, mixing, export, timeline rendering — is not part of the MCP surface. The pipeline delivers approved per-batch video, not a finished cut.
