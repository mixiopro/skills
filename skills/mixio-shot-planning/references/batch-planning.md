# Batch planning controls

Lookup reference for `mixio-shot-planning`. Read the live planner tool contract and the selected
model/use-case schema before using these defaults; the generation schema is authoritative for
what a model can render.

## Planner controls

`studio_plan_shot_batch` accepts:

| Control | Range | Default | Effect |
|---|---:|---:|---|
| `maxBatchDuration` | 1–60 seconds | 15 seconds | Maximum combined planned duration in a batch |
| `maxBatchShots` | 1–50 shots | 5 shots | Maximum shot count in a batch |
| `targetModel` | supported model ID | none | Groups and evaluates work for a selected model |

The planner limits organize submissions; they do not expand a model's duration, media, or
parameter contract. A `MULTI_CUT` shot in the 10–15s band can consume the default 15-second
batch duration by itself. Group only shots that share the same model, use case, and input
contract, and preserve shot order.
