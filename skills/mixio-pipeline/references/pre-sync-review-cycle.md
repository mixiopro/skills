# Local pre-sync review cycle

Use this cycle to make a director’s shot plan complete before the user reviews its Studio diff. It works on the local shot table in the agent’s current context. The screenplay development checkpoint and draft upsert are complete once the user confirms in chat or has already authorized that scope. This cycle does not rewrite the confirmed screenplay, repair Studio records, or generate assets.

## Cycle

1. **Plan:** `/mixio:script-breakdown` maps each confirmed screenplay beat to a purposeful shot and labels direction `SCRIPTED`, `INFERRED`, or `OPEN DECISION`.
2. **Continuity Checklist:** `/mixio:continuity` writes scene-, shot-, and cross-scene/shot checks for beat coverage, cause and effect, character/prop state, geography, staging, cuts, camera, sound, generation risks, and missing coverage.
3. **Correct locally:** Fix the cause at the shot where the state changes; update dependent rows and keep the confirmed screenplay as the baseline.
4. **Update checklist:** Recheck affected rows and revise the checklist after local corrections. Keep story-changing ambiguity visible as a question with alternatives.
5. **Review:** Present the full table and exact proposed Studio diff. Match updates to confirmed element IDs and flag ambiguous or unmatched shots.
6. **Checkpoint:** Present the exact diff. Chat “proceed” or prior authorization for that scope is enough to write; if the plan changes, update the checklist and show the changed portion.
7. **Sync and verify:** Use existing Studio primitives after confirmation and read the scene, shot, and relation records back against the confirmed diff.

## Decision rules

- Every material state change must be shown, called out as intentional off-screen action, or held as an open decision.
- The screenplay-development step may add useful connective visual direction as `INFERRED`; the raw script remains the story source. At shot planning, further inferred coverage is allowed. Do not invent dialogue, motivations, or story facts to close a gap.
- Missing sheets, reference images, and anchors are generation-readiness findings. They do not block local planning; surface their effect before generation and continue on the user's accepted limitation when the selected schema and project policy allow.
- A clear ID match can be updated. An uncertain match remains out of the write set until clarified. Never silently overwrite or delete an unmatched shot.
- Image generation and generation authorization stay downstream of the accepted breakdown.

The local draft is ephemeral and uses no new Studio schema. After context loss, rebuild it from the current source and Studio graph; prior analysis alone is not user authorization for a new write.
