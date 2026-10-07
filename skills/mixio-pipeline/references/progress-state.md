# Pipeline Progress State

Pipeline state has no dedicated shared-memory store; persist it in existing project/episode/shot
metadata. The main pipeline skill owns the order and gates. This reference holds the metadata
shape and resume reads.

At every step close, update episode `metadata.pipeline` with the current contract and progress:

```javascript
studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  aspect_ratio,
  anchor_aspect_ratio,
  shot_contract: { mode: "multi_cut", band: "10-15" },
  step_00: "complete", step_01: "complete", step_02: "complete", step_02_5: "complete",
  step_03: "complete", step_04: "complete",
  step_05: "not_started", step_06: "not_started",
  anchors: { "1": "<keyframe-element-id>" },
  reference_pack_inventory: {
    rows: [/* confirmed variant/view rows, source media, shot IDs, status,
             eval run IDs, feedback, human decision */]
  },
  reference_audit: { checked: 12, blocking: 0, advisory: 1 }
  // Add breakdown_audit and pre_production_loop using their owning references.
}}}})
```

| Pipeline state | Where it lives in Mixio |
|---|---|
| Locked models, resolution, style, reference policy | project `settings.generation` / `settings.studio` / `settings.references` |
| Source (screenplay, synopsis, aspect ratios) | SCREENPLAY `body` (or episode `script` only as fallback), episode `summary`, `metadata.pipeline` |
| Locations | LOCATION references + `locationDetails` (`mixio-references`) |
| Confirmed character/location variant-view matrix and review history | episode `metadata.pipeline.reference_pack_inventory` (free-form metadata; no new API or typed schema) |
| Reference audit results | episode `metadata.pipeline.reference_audit` |
| Relational breakdown audit results | episode `metadata.pipeline.breakdown_audit` |
| Pre-production Ralph loop state | episode `metadata.pipeline.pre_production_loop` — `running`, `blocked`, or `converged`, with last phase, cycle, findings, and pending user action |
| Scenes and direction | scene elements via `studio_upsert_scene_packages` |
| Step progress | episode `metadata.pipeline` |
| Shot plan (method/model/batch) | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| Rendered assets and video | KEYFRAME / VIDEO elements + `upload_file` URLs |

On resume, read `studio_get_project` for locked settings and `studio_get_episode` for pipeline
state, including reference inventory rows, evaluation IDs, feedback, and human decisions. Query
the episode's `SCREENPLAY` element (`studio_query_elements` with `type: "SCREENPLAY"` and native
object `tags: { episodeId }`, never `JSON.stringify(...)`) before reusing source text. Do not
substitute a stale `fullScript` when a non-empty screenplay body exists; avoid
`studio_get_production_context` until graph detail is needed.

The breakdown audit schema is in `mixio-script-breakdown`'s persistence reference. Persist the
pre-production loop exactly as defined in
[`pre-production-ralph-loop.md#persisting-loop-state`](pre-production-ralph-loop.md#persisting-loop-state).
