---
name: mixio-chunking
description: "Deterministic batching of shots into generation chunks under duration and count caps — one batch profile within the broader mixio-shot-planning step."
version: 0.2.0
invoke: /mixio:chunking
---

# Mixio Chunking

The **deterministic grouping algorithm** used by `mixio-shot-planning` (Step 05 of `mixio-pipeline`). Video models produce a few seconds per job, so an episode is generated as batches of consecutive shots. This skill implements **one batch profile** — the fixed-ceiling algorithm used when all shots target the same model and method.

For multi-model projects or shots requiring different generation methods (SINGLE, DUAL_FRAME, MULTI_KF, etc.), `mixio-shot-planning` classifies and assigns first, then calls this algorithm per model-group with that model's specific ceilings. On a single-model project, shot planning degrades to this skill directly.

The rules are deterministic. Do not improvise them — a "reasonable-looking" grouping that isn't reproducible means a re-run produces different chunks and the shot→chunk mapping in metadata goes stale.

## Prerequisites

- **Resolved scope — required.** You must be working against a project and an episode that the user has
  explicitly confirmed. If it is not established in this session, **fetch the list and show
  it, numbered, in the same message as the question** (`studio_list_projects` /
  `studio_list_episodes`) so the answer is one character. Asking "which episode?" without
  the list is a failure — it hands the lookup back to the user. Resolve this *before* any
  expensive read; never guess an id, infer one from a title, or create something to avoid
  asking. See `mixio-project`.
- An audited breakdown (Step 04) — chunk the **corrected** durations, never the pre-audit ones
- Every shot has a numeric `duration`
- For multi-model projects: method and model assignments from `mixio-shot-planning` — this skill receives a filtered shot list (one model-group at a time) with the model's ceiling values

## The rules

Defaults: **max 15.0s per chunk, max 5 shots per chunk.** These are the Seedance profile values. When called by `mixio-shot-planning`, the ceilings come from the model's capabilities:

| Model family | Duration ceiling | Shot ceiling |
|-------------|-----------------|--------------|
| Seedance v2 / Pro | 10–15s | 5 |
| Veo 3.1 | 8s | 3 |
| Sora 2 | 20s | 4 |
| Kling 2.6 Pro | 10s | 5 |

Query the live catalog for current values. The algorithm is the same regardless of ceiling.

1. Start a chunk with the first shot.
2. Keep adding the next **consecutive** shot as long as, after adding it, (a) the running total stays **at or under 15.0s** and (b) the chunk has **fewer than 5** shots.
3. The moment either limit would be exceeded, close the current chunk and start a new chunk **beginning with that shot** — do not skip it.
4. A shot whose own duration exceeds the ceiling becomes its own single-shot chunk **and must be flagged** — it cannot be generated in one pass and needs either a split into sub-shots or a shorter hold.
5. Never reorder. Chunks are contiguous ranges of the shot sequence.

Worked example — durations `4.5, 3.0, 9.0, 3.5, 3.0`:

| Shot | Duration | Running | Chunk |
|------|----------|---------|-------|
| 1 | 4.5s | 4.5s | 1 |
| 2 | 3.0s | 7.5s | 1 |
| 3 | 9.0s | 16.5s ✗ | — |

Shot 3 would take chunk 1 to 16.5s, so chunk 1 closes at shots 1–2 (7.5s) and shot 3 opens chunk 2.

| Shot | Duration | Running | Chunk |
|------|----------|---------|-------|
| 3 | 9.0s | 9.0s | 2 |
| 4 | 3.5s | 12.5s | 2 |
| 5 | 3.0s | 15.5s ✗ | — |

Chunk 2 closes at shots 3–4 (12.5s). Shot 5 opens chunk 3.

`chunk.py` in this directory implements exactly this and self-checks the edge cases (`python3 chunk.py`). Run it rather than doing the arithmetic by hand on a 40-shot episode.

## Production summary

Emit this before asking for generation approval (single-model projects) or as a sub-report within `mixio-shot-planning`'s full production summary (multi-model projects).

```
BATCH SUMMARY (seedance_image_to_video_v2)
Total shots:                    13
Total chunks:                    4
Total runtime:               48.5s
Shots flagged over ceiling:  Shot 9 (18.0s > 10.0s max)
Rapid pacing sections:       chunks 2, 3
```

- **Shots flagged over ceiling** — must be resolved before Step 06, not generated and hoped for. The ceiling is model-specific (10s for Seedance v2, 8s for Veo, 20s for Sora, etc.).
- **Rapid pacing sections** — any chunk containing 3+ consecutive shots marked `RAPID` or `PUNCHY` (see the `Pacing` field in `mixio-pipeline/references/shot-grammar.md`). Not an error; a note. Three rapid cuts in a row read as intentional urgency, but a whole episode of them reads as noise. Surface it so the user can decide.
- Add a cost line when the model's per-job cost is known — chunks × cost is the number the user is actually approving.

## Persisting chunks

Cheapest correct place is the shot itself; no new element type, and the mapping travels with the shot:

```
studio_revise_shot_specs({ shots: [
  { shotId: s1, metadata: { chunk_index: 1, chunk_position: 1, chunk_duration: 7.5 } },
  { shotId: s2, metadata: { chunk_index: 1, chunk_position: 2 } },
  { shotId: s3, metadata: { chunk_index: 2, chunk_position: 1, chunk_duration: 12.5 } }
]})
```

Shot metadata is merged, not replaced, so this doesn't disturb the audited camera/action fields. Step 06 then reads `chunk_index` to batch its jobs, and `studio_query_elements({ projectId, type: "SHOT", metadata: { chunk_index: 2 } })` retrieves one chunk — pass `metadata` as a real object, not a JSON string (see `mixio-episode`).

Then close the step and ask for spend approval:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: { step_05: "complete" } } } })
```

## Workflow

```
1. read corrected durations from the audited breakdown (Step 04)
2. python3 chunk.py  (or apply the rules)  → chunk assignments + flags
3. emit PRODUCTION SUMMARY
4. resolve any shot flagged over 15s (split it, or shorten the hold) → re-chunk
5. studio_revise_shot_specs({ chunk_index, chunk_position })
6. GATE — user approves runtime and cost → Step 06 Video Generation
```

## Notes

- **Chunk the durations that were actually persisted.** Since Studio PR #502 duration is a continuous float 1–60 on both the managed and composed paths, so short-form panels at 2.5–4.5s survive and give 4–5 shots per chunk. On a pre-#502 Studio the managed breakdown snapped to `5/8/10/12/15`, which with a 15s cap means at most 3 shots per chunk and a lone 15s shot filling one by itself. Read the stored value rather than the authored one.
- Re-chunk after **any** duration change. Chunk boundaries cascade: one shot getting 0.5s longer can shift every chunk after it.
- Chunk boundaries are generation boundaries, so they're where continuity is most fragile. Feed the last frame of chunk N as `input.media.endFrame`/`primary` continuity into chunk N+1 where the model supports it (see `mixio-generate`).
- Prefer closing a chunk at a scripted cut over filling it to exactly the ceiling. A chunk that ends mid-gesture is harder to join than one that ends on a cut, and the caps are ceilings, not targets.
- **This skill is called by `mixio-shot-planning`, not directly by the pipeline.** On a single-model project, shot-planning invokes this once with the default model's ceilings. On a multi-model project, it's invoked once per model-group. The pipeline step is still "Step 05" but the orchestrator is `mixio-shot-planning`.
