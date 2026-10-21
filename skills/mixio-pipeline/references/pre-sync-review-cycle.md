# Local pre-sync review cycle

Use this cycle to make a director’s shot plan complete before the user approves its Studio diff. It works on the local shot table in the agent’s current context. The screenplay must already have passed its separate development review and draft-upsert gate. This cycle does not rewrite the approved screenplay, repair Studio records, or generate assets.

## Cycle

1. **Plan:** `/mixio:script-breakdown` maps each approved screenplay beat to a purposeful shot and labels direction `SCRIPTED`, `INFERRED`, or `OPEN DECISION`.
2. **Continuity Checklist:** `/mixio:continuity` writes scene-, shot-, and cross-scene/shot checks for beat coverage, cause and effect, character/prop state, geography, staging, cuts, camera, sound, generation risks, and missing coverage.
3. **Correct locally:** Fix the cause at the shot where the state changes; update dependent rows and keep the approved screenplay as the baseline.
4. **Update checklist:** Recheck affected rows and revise the checklist after local corrections. Keep story-changing ambiguity visible as a question with alternatives.
5. **Review:** Present the full table and exact proposed Studio diff. Match updates to confirmed element IDs and flag ambiguous or unmatched shots.
6. **Wait:** Make no breakdown write until the user approves that diff. If the plan changes, update the checklist and present a revised diff.
7. **Sync and verify:** After approval, use existing Studio primitives and read the scene, shot, and relation records back against the approved diff.

## Decision rules

- Every material state change must be shown, called out as intentional off-screen action, or held as an open decision.
- The screenplay-development step may add useful connective visual direction as `INFERRED`; the raw script remains the story source. At shot planning, further inferred coverage is allowed. Do not invent dialogue, motivations, or story facts to close a gap.
- Missing sheets, reference images, and anchors are generation-readiness gaps. They do not block local planning; resolve them before generation.
- A clear ID match can be updated. An uncertain match remains out of the write set until clarified. Never silently overwrite or delete an unmatched shot.
- Image generation and generation authorization stay downstream of the accepted breakdown.

The local draft is ephemeral and uses no new Studio schema. After context loss, rebuild it from the current source and Studio graph; prior analysis is not approval.
