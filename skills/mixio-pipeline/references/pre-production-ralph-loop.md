# Pre-Production Token Ralph Loop

The autonomous quality gate across **Step 01 Screenplay** ↔ **Step 02.5 Reference Audit** ↔ **Step 04 Continuity Audit**. Step 02 Sheets/Anchors and Step 03 Breakdown are prerequisites and revalidation points, not loop phases.

The loop only makes safe text and graph corrections. It never enters a generation use case, including sheets or anchors; those image jobs remain explicitly user-authorized. The loop corrects syntax, bindings, and continuity errors until **zero blocking errors** remain, then asks for user approval before Step 05 shot planning and cost approval.

---

## Why a Ralph Loop?

Without an autonomous loop, each step halts on findings or passes flawed data downstream:
- A missing prop put-down action in Step 04 gets flagged, but without an auto-correction and re-audit loop, the agent either asks the user for permission on a trivial text fix or applies a single unverified edit that introduces a new eyeline break.
- A stale look binding (`STALE_LOOK_REF`) or missing character look in Step 02.5/04 fails soft and degrades silently to the default look during Step 06 video generation, wasting render credits.

The Token Ralph Loop makes pre-production **self-healing** without silently spending credits:
```
02 Sheets & Anchor Frames (separately user-confirmed; never auto-entered)
  ↓
03 Panel Breakdown (required before continuity; re-audit after any changed relation/spec)
  ↓
01 Screenplay ←→ 02.5 Reference Audit ←→ 04 Continuity Audit
  │                    │                         │
  └── safe text / policy-safe graph correction ──┘
       persist each cycle, then re-check
  ↓
CONVERGENCE: 0 blocking findings → user approval → Step 05
```

---

## Convergence Invariants (Exit Criteria)

Pre-production does **not** lock or advance to Step 05 until the loop converges against two strict gates:

| Gate | Tool / Check | Required Score | Blocking Codes |
|---|---|---|---|
| **Reference Quality** | Step 02.5 (`mixio-reference-audit`) | **0 blocking errors** | `MISSING_REF` (entities in ≥2 shots), `MISSING_IMAGE_HIGH_USAGE`, `NO_PRIMARY_LOOK`, `STALE_LOOK_REF`, High-severity metadata gaps on core cast |
| **Continuity Quality** | Step 04 (`mixio-continuity`) | **0 blocking breaks** | `PROP` (vanishing/teleporting objects), `PRESENCE` (unaccounted absences), `FACING` (180° line violations), `POSTURE` (unexplained shifts), `GAP` (missing required fields), `REF_MISSING`, `REF_NO_IMAGE` |

Advisory findings (e.g. subtle description differences, non-blocking prop stubs) are recorded in metadata and surfaced in the final convergence summary for user visibility, but do not block progression.

---

## Boundaries, policy, and asset permission

At the start of every remediation cycle, read `studio_get_project({ projectId })` and retain its current `settings.references`. The Phase 2 runner may write a reference only when the relevant setting permits it:

| Finding | Automated action only when | Otherwise |
|---|---|---|
| `MISSING_REF` | `createPolicy: allow` permits creating the needed reference | Persist `blocked` with a proposal or request an existing reference link |
| `STALE_LOOK_REF` | An existing permitted variant can be rebound, or the policy permits the supplied variant name and user-supplied asset | Persist `blocked` with the valid variant choices or requested asset |
| Metadata gap | The policy permits the reference update | Persist `blocked` with the exact missing field |
| `MISSING_IMAGE_HIGH_USAGE` / `REF_NO_IMAGE` | A permitted existing uploaded asset is available to attach | Persist `blocked`; request a user upload or explicit image-generation permission |

`mixio-reference-audit` and `mixio-continuity` are audit skills. When invoked directly, they report the remediation plan and do not write references. The pipeline invokes the Phase 2 runner after the policy check.

No loop phase may call `/mixio:sheets` or submit a Studio job. An image may be attached when the user has already supplied it and policy allows; generating a new image requires explicit permission for that job type (or a persisted "Always allow" permission that covers images).

## Loop phases

### Phase 1: Screenplay & Entity Binding (01)
- Normalize source text to standard screenplay grammar.
- Harvest `#name.variant` tokens and sweep prose for un-mentioned characters/locations.
- Resolve mentions with `studio_resolve_mention`. If an entity or look is unmapped, pass it to Phase 2; do not create a sheet or render an image.
- Re-upsert the normalized screenplay only after Phase 2 has returned a valid mention. If it is blocked, preserve the source and persist the requested action.

### Phase 2: Reference Audit & Look-Binding Verification (02.5)
- Run `mixio-reference-audit` across all script entities against registered references.
- **Auto-remediation (policy-gated):**
  - If `MISSING_REF` on a script entity: register it only with `createPolicy: "allow"`; with `"propose"`, persist a proposal and block for approval; with `"link_only"`, request an existing reference link.
  - If `STALE_LOOK_REF` or a missing look variant: rebind to an existing permitted name, or update only with a user-supplied asset and an allowed variant name.
  - If a HIGH-severity metadata gap (e.g. missing `visualAnchor` on core character or missing `lighting` on location) is deterministic: populate the structured detail only after the policy gate permits it.
  - If `MISSING_IMAGE_HIGH_USAGE` is blocking: use an already supplied asset when allowed; otherwise set the loop to `blocked` and request an upload or explicit image-generation permission.
- **Re-check:** Re-run Step 02.5 until blocking errors reach `0`.

### Phase 3: Continuity Self-Healing & Verification (04)
- Run `mixio-continuity` (Pass 1 Blocking Map → Pass 2 Checks → Pass 3 Report).
- **Auto-Correction (Pass 4):**
  - **Prop continuity break (`PROP`):** Auto-inject the missing put-down or pick-up action in the exact shot where the state changes using `studio_revise_shot_specs`. Update `appears_in` relation `carriedProps` via `studio_link_graph`.
  - **Eyeline / 180° axis violation (`FACING`):** Adjust camera placement / subject orientation in shot spec text or clarify camera repositioning.
  - **Missing movement marker (`[Mn]`):** Re-sequence marker tags across dependent shots.
  - **Missing reference detected (`REF_MISSING` / `REF_NO_IMAGE`):** Route back to Phase 2; its policy and asset gates decide whether the loop can repair it or must block.
- **Immediate Re-Audit (The Verification Loop):**
  - Immediately re-run Pass 1–3 on the revised shot specs.
  - Confirm the previous finding is cleared and verify that the edit did not introduce new breaks.
  - Iterate until `0` continuity breaks remain.

After a screenplay, relation, or shot-spec correction, re-run the affected Step 03 relational checks before declaring convergence. Do not silently rebuild anchors or render images.

---

## Concrete Auto-Correction Recipes

### Recipe 1: Disappearing / Teleporting Prop (AC1)
*Scenario:* Shot 5 has Tony scrolling her `PHONE`. In Shot 7, Tony takes a `TABLET` from Poppy. In Shot 8, Tony holds the tablet with both hands; the phone vanished with no put-down action.

1. **Locate origin of break:** Shot 7 (the handoff beat).
2. **Apply shot spec fix via `studio_revise_shot_specs`:**
   ```javascript
   studio_revise_shot_specs({
     shots: [{
       shotId: "shot_7_id",
       metadata: {
         action: "TONY drops her PHONE onto the bedding beside her, then reaches with her right hand to take the TABLET from POPPY [M2]."
       }
     }]
   })
   ```
3. **Update graph state via `studio_link_graph`:**
   ```javascript
   studio_link_graph({
     projectId,
     relations: [{
       fromId: tonyCharacterId,
       toId: "shot_7_id",
       relationType: "appears_in",
       metadata: { carriedProps: ["TABLET"], continuityNotes: "phone placed on bedding at [M2]" }
     }]
   })
   ```
4. **Re-run continuity check:** Re-evaluate Shots 5–8 in Pass 2. Verify `FINDING` is cleared to `✅`.

---

### Recipe 2: Missing Look Variant / Stale Look Ref (AC2)
*Scenario:* Continuity audit finds Shot 4 specifies Tony in wet clothes after rain, but `lookRef` points to `wet_coat` which does not exist on `TONY` reference (`STALE_LOOK_REF` / `REF_MISSING`).

1. **Read before writing:** Call `studio_get_project({ projectId })` for `settings.references`, then `studio_list_references({ projectId })` and `studio_get_element({ elementId: tonyRefId })` before constructing an update. `referenceVariants` replaces the whole current list; legacy `characterDetails.looks` or flat `attachments` require a migration through `mixio-references`, not a replace-list write from this loop.
2. **Remediate variant:**
   - If a permitted existing variant has the right meaning (for example `soaked`), update `lookRef: "soaked"` on the `appears_in` relation.
   - If the user has supplied `wetCoatImageUrl`, `variantPolicy` permits `wet_coat`, and this is a current variant record, preserve the complete list in an update:
     ```javascript
     const project = await studio_get_project({ projectId })
     const reference = await studio_get_element({ elementId: tonyRefId })
     const { variantPolicy, variantVocabulary } = project.settings.references
     const currentVariants = reference.metadata.referenceVariants
     const legacyLooks = reference.metadata.characterDetails?.looks ?? []
     const legacyAttachments = reference.metadata.attachments ?? []
     const allowedNames = variantVocabulary[reference.type] ?? []

     if (!Array.isArray(currentVariants) || legacyLooks.length || legacyAttachments.length) {
       // Persist `blocked`; use mixio-references to migrate legacy look data safely.
     // Per mixio-references, an absent or empty vocabulary is unconstrained.
     } else if (variantPolicy === "closed" && allowedNames.length > 0 && !allowedNames.includes("wet_coat")) {
       // Persist `blocked`; ask for a permitted name instead of writing.
     } else {
     studio_update_reference({
       referenceId: tonyRefId,
       referenceVariants: [
         ...currentVariants,
         { name: "wet_coat", kind: "look", images: [{ url: wetCoatImageUrl, isPrimary: true }] }
       ]
     })
     }
     ```
   - If no supplied image exists: keep the finding blocking and ask the user for an image/approved replacement. Only after explicit approval of a fidelity downgrade may you clear the stale `lookRef` and set `condition: "soaked clothing, wet hair"` on that character's `appears_in` relation metadata via `studio_link_graph`.
3. **Re-run Reference Audit (02.5) & Continuity Check (04):** Verify look-binding resolves cleanly.

---

### Recipe 3: 180° Axis / Eyeline Jump
*Scenario:* Shot 3 has Poppy frame-left facing frame-right talking to Tony. Shot 4 cuts to close-up of Poppy facing frame-left with no camera reposition stated.

1. **Diagnose cause:** Determine whether Poppy turned or camera crossed the line.
2. **Apply fix:** Clarify camera placement and axis in `Camera` and `blocking` metadata (e.g. `OTS over Tony's left shoulder, looking FR toward Poppy`).
3. **Re-run continuity check:** Verify axis consistency across the cut.

---

## Loop Guardrails & Circuit Breaker

To prevent infinite loops during pre-production:
- **Maximum Iterations:** The Ralph Loop runs a maximum of **3 automated correction cycles** per scene.
- **Unresolvable Creative Conflicts:** If an error persists after 3 cycles (e.g. a script beat fundamentally requires a character to be in two places at once), pause the loop and present a focused, numbered choice to the user:
  ```
  Pre-Production Loop: Unresolved blocking break in Scene 2, Shot 4
  Issue: Tony cannot reach the harbor office in Shot 4 after being at the apartment in Shot 3 (continuous time).
  Options:
    1. Add an establishing transit shot (Shot 3b — 3.0s WS Exterior).
    2. Change Scene 2 timeOfDay from CONTINUOUS to LATER.
    3. Modify Shot 4 action.
  ```
- Once the user selects an option, apply the change and re-verify convergence.

---

## Persisting loop state

At the start and end of **every** cycle, write a resumable record to episode metadata. The fields below are the canonical `pre_production_loop` contract; the pipeline and audit skills link here rather than redefining it.

```javascript
studio_update_episode({
  episodeId,
  updates: { metadata: { pipeline: {
    pre_production_loop: {
      status: "running", // "running" | "blocked" | "converged"
      cycle: 2,
      scene_ids: [sceneId],
      last_phase: "reference_audit",
      last_findings: ["STALE_LOOK_REF:TONY:wet_coat"],
      pending_user_action: null
    }
  } } }
})
```

When a policy, asset, generation-permission, or creative decision prevents correction, write `status: "blocked"` with `pending_user_action` naming the exact action. Resume from `last_phase` after the user responds; do not reset the cycle count.

When both audits pass with 0 blocking errors, lock the breakdown and replace that record with the convergence proof:

```javascript
// 1. Lock shot states
studio_update_shot_state({
  shots: cleanShotIds.map(shotId => ({ shotId, state: "approved" }))
})

// 2. Persist Ralph loop convergence state
studio_update_episode({
  episodeId,
  updates: {
    metadata: {
      pipeline: {
        step_01: "complete",
        step_02: "complete",
        step_02_5: "complete",
        step_03: "complete",
        step_04: "complete",
        pre_production_loop: {
          status: "converged",
          cycle: 2,
          last_phase: "continuity_audit",
          reference_audit: { checked: 12, blocking: 0, advisory: 1 },
          continuity_audit: { total_shots: 14, breaks_auto_corrected: 2, remaining_breaks: 0 },
          pending_user_action: null,
          locked_at: new Date().toISOString()
        }
      }
    }
  }
})
```

Announce convergence clearly to the user:
`Pre-Production Token Ralph Loop converged (0 blocking reference errors, 0 continuity breaks across 14 shots). Breakdown locked. Ready for Step 05 — Shot Planning & Cost Approval.`
