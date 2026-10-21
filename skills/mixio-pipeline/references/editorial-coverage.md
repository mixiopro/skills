# Editorial coverage and generation duration

The requested runtime is the intended final cut after post-production. Plan at least **20% more generated video**, with useful angles, emotional takes, reactions, listening shots, inserts, and connecting coverage that give the editor choices.

## Calculate the reserve

Let `T` be the final runtime and `G` the sum of the durations of distinct planned video outputs:

```text
minimum G = 1.2 × T
reserve seconds = G − T
reserve percent = (G / T − 1) × 100
```

| Intended final cut | Minimum generated video | Extra footage |
|---|---|---|
| 1 minute | 72 seconds | 12 seconds |
| 90 minutes | 108 minutes | 18 minutes |

The 20% reserve is a floor. Plan more when the screenplay, performance, action, or edit needs it. First make sure a coherent edit can cover every required beat; then add purposeful alternatives. Extra seconds alone do not resolve a missing cause, reaction, or transition.

Count each planned candidate clip once, including alternatives that replace rather than extend another shot. Count a `MULTI_CUT` output by its whole clip duration; its internal cuts are part of that same output. Count separate clips used in a sequence individually. Reusing a clip in the edit does not create another generated output. Still keyframes, reference sheets, dialogue audio, and failed or rejected attempts do not contribute video seconds to the reserve. Track retries separately from selected candidate coverage; the reserve does not authorize additional generation.

Use approximate durations during breakdown. Recalculate with the live model's supported durations during shot planning and round the plan upward as needed. A duration or coverage change to approved direction returns to the applicable plan/diff for review. Keep any unknown final runtime as an open decision until it is resolved; do not invent a target.

## Keep an output ledger

Alongside the local shot table, list every candidate output:

| Output label | Owning scene/shot | Role and purpose | Intended relationship | Planned video seconds | Continuity checklist items |
|---|---|---|---|---|---|
| A stable local label | Confirmed shot ID after sync | Main take, alternate angle/emotion, reaction/listener, insert, or bridge; explain why | Replaces a named output or adds a named beat | Whole generated clip duration | Applicable checklist IDs |

These are review-artifact columns, not new Studio API fields. Added coverage shots enter the exact Studio diff; alternate takes may share their owning shot's confirmed ID and each use an existing generation submission. Preserve source numbering and do not invent IDs for local additions. At shot planning, include every output in model assignments, job counts, and batch work. Distinguish video outputs from image/TTS jobs and orchestration parent/child submissions.

Report `T`, `G`, the reserve seconds/percent, and any coverage gaps together. After rendering, compare usable accepted footage with this plan and identify remaining editorial gaps before proposing more generation. This pipeline prepares production material; final assembly remains a separate post-production task.
