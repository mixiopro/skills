---
name: mixio-chunking
description: "Group an audited shot breakdown into deterministic generation chunks under duration and count caps, flag over-length shots and rapid-pacing runs, and emit a production summary for cost approval before video generation."
version: 0.1.0
invoke: /mixio:chunking
---

# Mixio Chunking

Step 05 of `mixio-pipeline`. Video models produce a few seconds per job, so an episode is generated as **chunks** of consecutive shots. Chunking is the last free step: it converts the breakdown into a work plan with a runtime and a cost surface the user can approve before any credits are spent.

The rules are deterministic. Do not improvise them — a "reasonable-looking" grouping that isn't reproducible means a re-run produces different chunks and the shot→chunk mapping in metadata goes stale.

## Prerequisites

- An audited breakdown (Step 04) — chunk the **corrected** durations, never the pre-audit ones
- Every shot has a numeric `duration`

## The rules

Defaults: **max 15.0s per chunk, max 5 shots per chunk.** Confirm both with the user if the target model's limits differ.

1. Start a chunk with the first shot.
2. Keep adding the next **consecutive** shot as long as, after adding it, (a) the running total stays **at or under 15.0s** and (b) the chunk has **fewer than 5** shots.
3. The moment either limit would be exceeded, close the current chunk and start a new chunk **beginning with that shot** — do not skip it.
4. A shot whose own duration exceeds 15.0s becomes its own single-shot chunk **and must be flagged** — it cannot be generated in one pass and needs either a split into sub-shots or a shorter hold.
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

Emit this before asking for generation approval. It is the whole reason the step exists.

```
PRODUCTION SUMMARY
Total shots:                    13
Total chunks:                    4
Total runtime:               48.5s
Shots flagged over 15s:      Shot 9 (18.0s)
Rapid pacing sections:       chunks 2, 3
```

- **Shots flagged over 15s** — must be resolved before Step 06, not generated and hoped for.
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
- Prefer closing a chunk at a scripted cut over filling it to exactly 15.0s. A chunk that ends mid-gesture is harder to join than one that ends on a cut, and the caps are ceilings, not targets.
