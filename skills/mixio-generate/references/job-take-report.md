# Job Take Report

Optional template for teams that want a compact generation receipt. It does not require a
`generation_log` metadata write or introduce a selection/retention policy. Fields should be
filled from live submit/status/evaluation results; live Studio schemas always override this
example.

## Take entry shape

An optional report for one submitted job can use this shape:

```json
{
  "take_id": "<stable-take-id>",
  "shot_id": "<shot-element-id>",
  "scene_id": "<scene-element-id>",
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
  "notes": "cut 2 blocking drift — rejected after eval"
}
```

Field rules:

- Keep `schema_warnings` in the receipt. A non-empty array means parameters may have been
  filtered; inspect it under `mixio-generate` before treating the job as valid.
- The prompt itself is omitted to avoid duplicating the Prompt & Mention Sheet. Record a
  stable prompt reference/hash only if that is part of the team's own reporting convention.
- Confirm `output_ref` and shot association by reading the output element's relations; job
  status alone does not echo or prove the submitted context.
