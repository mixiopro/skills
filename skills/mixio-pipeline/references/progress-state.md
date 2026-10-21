# Pipeline Progress State

The director’s screenplay change map, shot plan/output ledger, and Continuity Checklist are review
artifacts in the agent’s current context. They use no new Studio schema. If context is lost before
screenplay upsert, rebuild the screenplay draft from the raw script, current screenplay, references,
and user decisions. If lost before shot sync, rebuild the plan, output ledger, and checklist from the confirmed screenplay, references/assets, and
Studio graph. After sync, read back the persisted graph, reconstruct the checklist against current direction/references, and resume from that state.

After a chat-confirmed sync, store only durable production state in existing project, episode, and
shot metadata. Preserve unrelated values when updating `metadata.pipeline`:

```javascript
const episode = await studio_get_episode({ episodeId })
const currentMetadata = episode.metadata ?? {}
studio_update_episode({ projectId, episodeId, updates: { metadata: {
  ...currentMetadata,
  pipeline: {
  ...currentMetadata.pipeline,
  aspect_ratio,
  anchor_aspect_ratio,
  shot_contract: { mode: "multi_cut", band: "10-15" },
  step_00: "complete",
  step_03: "complete",
  step_04: "complete",
  step_05: "not_started",
  step_06: "not_started",
  anchors: { "1": "<keyframe-element-id>" },
  reference_pack_inventory: {
    rows: [/* confirmed variant/view rows, source media, shot IDs, status,
             eval run IDs, feedback, human decision */]
  },
  reference_audit: { checked: 12, blocking: 0, advisory: 1 },
  breakdown_audit: { /* persisted scene/shot/relation readback */ }
}}}})
```

| Pipeline state | Where it lives in Mixio |
|---|---|
| Raw story/script source | Episode `script` / `metadata.fullScript` |
| Developed production screenplay | `SCREENPLAY.body` (the chat-confirmed read-back draft is the production baseline; Studio status may remain `draft`) |
| Current project settings and reference policy | project `settings.generation` / `settings.studio` / `settings.references` |
| Confirmed character/location variant-view matrix and review history | episode `metadata.pipeline.reference_pack_inventory` |
| Reference audit results | episode `metadata.pipeline.reference_audit` |
| Approved scene/shot direction and relations | scene/shot elements via the existing episode primitives |
| Breakdown sync audit | episode `metadata.pipeline.breakdown_audit` |
| Persisted step progress | episode `metadata.pipeline`; local plan/review steps stay in agent context |
| Shot method/model/batch | shot `metadata.generation_method` / `.generation_model` / `.batch_index` |
| Rendered assets and video | KEYFRAME / VIDEO elements + permanent upload URLs |

The exact sequence is in the main `mixio-pipeline` skill. Step 04 reference readiness and Step 05
shot planning follow the confirmed breakdown sync. The reference inventory is
maintained by `mixio-sheets`; the reference audit is defined in `mixio-reference-audit`.

On resume, read `studio_get_project` for current settings and `studio_get_episode` for persisted
pipeline state and inventory rows. Query the episode's `SCREENPLAY` element with
`studio_query_elements({ projectId, type: "SCREENPLAY", tags: { episodeId }, limit, offset,
includeFull: true })`; use a native object for `tags`, never `JSON.stringify(...)`. Do not
substitute stale `fullScript` when a non-empty screenplay body exists. Avoid
`studio_get_production_context` until graph detail is needed.

The breakdown audit schema and readback checks are in
`mixio-script-breakdown/references/persistence-and-audit.md`.
