# Job Take Report

Provenance: fields come from the live `studio_submit_studio_job` response (job id,
tracking, `schemaWarnings`), `studio_get_job_status` (status values `PENDING`,
`RUNNING`, `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED` — status and
tracking only, no context echo), and `mixio-eval`'s `studio_evals_evaluate_media` /
`studio_evals_get_evaluation_result` (runId, verdict). The `generation_log` container is
a skills-side convention stored in episode `metadata.pipeline`, not a Studio schema
field. Live Studio schemas always override this file.

One **take** = one submitted job for one shot (or one multi-cut shot), from submission
through evaluation. The take report is what makes renders reviewable: which shot, which
model, which prompt, which references, what came back, what the evaluator said, and
whether it was selected.

## Take entry shape

Append one entry to episode `metadata.pipeline.generation_log.takes[]` when a poll
reaches a terminal status:

```json
{
  "take_id": "s12_h3_t1",
  "shot_id": "12",
  "scene_id": "3",
  "job_id": "…",
  "submitted_at": "2026-10-06T17:04:11Z",
  "terminal_at": "2026-10-06T17:06:02Z",
  "use_case_id": "multi-shot-video",
  "model": "hailuo_v3_reference_to_video",
  "status": "COMPLETED",
  "duration_requested": 12,
  "parameters": { "aspect_ratio": "16:9" },
  "slot_keys": ["primary", "references"],
  "media_refs": ["el_a", "el_b"],
  "prompt_chars": 1840,
  "prompt_sha": "…",
  "schema_warnings": [],
  "output_ref": "el_out_…",
  "eval": { "run_id": "…", "verdict": "pass", "worst_transition": null },
  "selected": false,
  "notes": "cut 2 blocking drift — rejected after eval"
}
```

Field rules:

- **`schema_warnings` is never omitted.** A non-empty array at terminal status means the
  job ran with parameters stripped (`mixio-generate` §4) — record it, then treat the take
  as failed and resubmit a clean one.
- **`prompt` itself is not stored in the entry** (episode metadata bloat); store
  `prompt_chars` + `prompt_sha` and keep the full text in the Prompt & Mention Sheet,
  which is the artifact that gets edited on a rewrite.
- **Failed/cancelled takes get entries too** with `status` and a `notes` reason — the
  report's value is the rejected takes, not just the kept one.
- `output_ref` is the element/media id of the produced asset when one is written under
  the shot; confirm via the shot's elements/relations, since `get_job_status` never
  echoes context.

## Bounds

- `takes[]` is append-only and capped at **200 entries** per episode. When exceeding,
  evict the oldest **unselected** terminal takes first (failed before completed);
  never evict a `selected: true` entry or one referenced by a shot's
  `selected_take`.
- One entry per job, not per attempt within a job (child-frame jobs from
  `orchestrate_frames` roll up under their parent's entry, with a `children` count if
  needed).

## Selected-take persistence

When the user (or the Step 06 gate) picks a take for delivery:

1. Flip the entry's `selected: true` and write `selected_take` on the shot's metadata
   (`pipeline: { selected_take: { take_id, job_id, output_ref } }`, snake_case per shot
   metadata convention).
2. A shot has at most one selected take; selecting another demotes the previous one
   rather than deleting it.
3. Delivery uploads (`upload_file`) and `mixio-eval` final runs reference the selected
   take's `output_ref`, so the report — not memory — is the join key between render,
   evaluation, and delivered file.
