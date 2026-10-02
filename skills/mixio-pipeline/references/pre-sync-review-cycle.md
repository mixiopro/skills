# Local pre-sync review cycle

Use this cycle to make a director’s plan complete before the user approves its Studio diff. It works on the local shot table in the agent’s current context. It does not persist draft state, rewrite the screenplay, repair Studio records, or generate assets.

## Cycle

1. **Plan:** `/mixio:script-breakdown` maps each source beat to a purposeful shot and labels direction `SCRIPTED`, `INFERRED`, or `OPEN DECISION`.
2. **Audit:** `/mixio:continuity` checks beat coverage, cause and effect, character/prop state, geography, staging, cuts, camera, and sound.
3. **Correct locally:** Fix the cause at the shot where the state changes; update any dependent rows and preserve screenplay text.
4. **Re-audit:** Repeat the affected checks. Keep story-changing ambiguity visible as a question with alternatives.
5. **Review:** Present the full table and exact proposed Studio diff. Match updates to confirmed element IDs and flag ambiguous or unmatched shots.
6. **Wait:** Make no breakdown write until the user approves that diff. If the plan changes, re-audit and present a revised diff.
7. **Sync and verify:** After approval, use existing Studio primitives and read the scene, shot, and relation records back against the approved diff.

## Decision rules

- Every material state change must be shown, called out as intentional off-screen action, or held as an open decision.
- A useful connective shot can be inferred, but the source does not change. Do not invent dialogue, motivations, or story facts to close a gap.
- Missing sheets, reference images, and anchors are generation-readiness gaps. They do not block local planning; resolve them before generation.
- A clear ID match can be updated. An uncertain match remains out of the write set until clarified. Never silently overwrite or delete an unmatched shot.
- Image generation and cost approval stay downstream of the accepted breakdown.

The local draft is ephemeral and uses no new Studio schema. After context loss, rebuild it from the current source and Studio graph; prior analysis is not approval.
