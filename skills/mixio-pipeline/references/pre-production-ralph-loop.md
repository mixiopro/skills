# Pre-Production Token Ralph Loop

The autonomous quality gate across pre-production steps (**Step 01 Screenplay** ↔ **Step 02 Sheets** ↔ **Step 02.5 Reference Audit** ↔ **Step 03 Panel Breakdown** ↔ **Step 04 Continuity Audit**).

Generation (Step 06) is billable and non-deterministic. Text-only checks in Steps 01, 02.5, 03, and 04 cost tokens; Step 02 sheet and anchor rendering submits image jobs and can spend generation credits. Apply the normal rendering permission gate before those jobs. The Token Ralph Loop is the orchestrator's closed feedback loop that iterates on text schemas and graph metadata autonomously, correcting syntax, reference, and continuity errors until **zero blocking errors** remain, before requesting user sign-off for Step 05 shot planning and cost approval.

---

## Why a Ralph Loop?

Without an autonomous loop, each step halts on findings or passes flawed data downstream:
- A missing prop put-down action in Step 04 gets flagged, but without an auto-correction and re-audit loop, the agent either asks the user for permission on a trivial text fix or applies a single unverified edit that introduces a new eyeline break.
- A stale look binding (`STALE_LOOK_REF`) or missing character look in Step 02.5/04 fails soft and degrades silently to the default look during Step 06 video generation, wasting render credits.

The Token Ralph Loop makes pre-production **self-healing**:
```
01 Detailed Screenplay (draft)
  ↕ [Screenplay ↔ Reference loop: resolve #mentions, register missing entities/looks]
02 Sheets & Anchor Frames
  ↓
02.5 Reference Audit ──(blocking errors > 0)──→ auto-remediate refs/variants ──┐
  │ (0 blocking errors)                                                         │
  ↓                                                                             │
03 Panel Breakdown                                                              │
  ↓                                                                             │
04 Continuity Audit ───(blocking breaks > 0)───→ auto-correct shot specs/refs ──┘
  │                                              & immediately re-run audit
  │ (0 blocking breaks & 0 blocking ref errors)
  ↓
CONVERGENCE (Locked breakdown → GATE to Step 05 Shot Planning)
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

## The Four Loop Phases

### Phase 1: Screenplay & Entity Binding (01 ↔ 02)
- Normalize source text to standard screenplay grammar.
- Harvest `#name.variant` tokens and sweep prose for un-mentioned characters/locations.
- Resolve mentions with `studio_resolve_mention`. If unmapped, read `settings.references` and follow its policy before writing:
  - With `createPolicy: "allow"`, register the entity with `studio_register_reference_entities`.
  - With `createPolicy: "propose"`, record the proposed entity/look and pause for user approval.
  - With `createPolicy: "link_only"`, do not create anything; ask the user to identify an existing reference to link.
  - Only after the policy permits a write, add a variant/look sheet with `studio_update_reference` / `mixio-sheets`.
  - Put exact returned `mentionableLooks` tokens back into screenplay body and re-upsert via `studio_upsert_screenplay`.

### Phase 2: Reference Audit & Look-Binding Verification (02.5)
- Run `mixio-reference-audit` across all script entities against registered references.
- **Auto-remediation (policy-gated):** Read `studio_get_project({ projectId })` and its complete `settings.references` policy before each proposed write.
  - If `MISSING_REF` on a script entity: register it only with `createPolicy: "allow"`; with `"propose"`, create a proposal for approval; with `"link_only"`, stop and request an existing reference link.
  - If `STALE_LOOK_REF` or missing look variant: rebind to a valid name in `variantVocabulary`, or propose/register a variant only when `variantPolicy` and `createPolicy` permit it.
  - If HIGH-severity metadata gap (e.g. missing `visualAnchor` on core character or missing `lighting` on location): update the existing reference only after the policy check; otherwise surface the required proposal.
- **Re-check:** Re-run Step 02.5 until blocking errors reach `0`.

### Phase 3: Breakdown & State Linking (03)
- Break scenes and shots against canonical schemas (`shot_type`, `camera_movement`, `subject`, `action`, `context`, `style_ambiance`, `duration`).
- Link graph entities via `studio_upsert_scene_packages` / `studio_link_graph`.
- Populate initial per-shot `appearanceState` (`carriedProps`, `wardrobe`, `condition`, `lookRef`).

### Phase 4: Continuity Self-Healing & Verification (04)
- Run `mixio-continuity` (Pass 1 Blocking Map → Pass 2 Checks → Pass 3 Report).
- **Auto-Correction (Pass 4):**
  - **Prop continuity break (`PROP`):** Auto-inject the missing put-down or pick-up action in the exact shot where the state changes using `studio_revise_shot_specs`. Update `appears_in` relation `carriedProps` via `studio_link_graph`.
  - **Eyeline / 180° axis violation (`FACING`):** Adjust camera placement / subject orientation in shot spec text or clarify camera repositioning.
  - **Missing movement marker (`[Mn]`):** Re-sequence marker tags across dependent shots.
  - **Missing reference detected (`REF_MISSING` / `REF_NO_IMAGE`):** Route back to Phase 2 for policy-gated reference remediation, then rebind `lookRef`.
- **Immediate Re-Audit (The Verification Loop):**
  - Immediately re-run Pass 1–3 on the revised shot specs.
  - Confirm the previous finding is cleared and verify that the edit did not introduce new breaks.
  - Iterate until `0` continuity breaks remain.

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

1. **Check reference policy and complete state:** Read `projects.settings.references` (`createPolicy`, `variantPolicy`, `variantVocabulary`) and the full reference with `studio_get_element`. Collect variants from current `referenceVariants`, legacy `characterDetails.looks`, and flat `attachments` before any replacement write.
2. **Remediate variant:**
   - If variant exists under alternative name (e.g. `soaked`): update `lookRef: "soaked"` on `appears_in` relation.
   - If variant is missing and policy permits: append the new look to that complete set via `studio_update_reference` (its `referenceVariants` argument replaces the entire list):
     ```javascript
     studio_update_reference({
       referenceId: tonyRefId,
       referenceVariants: [
         ...existingVariants,
         { name: "wet_coat", kind: "look", images: [{ url: wetCoatImageUrl, isPrimary: true }] }
       ]
     })
     ```
   - If no variant image exists: keep the finding blocking and ask the user for an image/approved replacement. Only after explicit approval of a fidelity downgrade may you clear the stale `lookRef` and set `condition: "soaked clothing, wet hair"` on that character's `appears_in` relation metadata via `studio_link_graph`.
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

## Persisting Convergence State

When both audits pass with 0 blocking errors, lock the breakdown and persist the convergence proof to episode metadata:

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
          iterations: 2,
          reference_audit: { checked: 12, blocking: 0, advisory: 1 },
          continuity_audit: { total_shots: 14, breaks_auto_corrected: 2, remaining_breaks: 0 },
          locked_at: new Date().toISOString()
        }
      }
    }
  }
})
```

Announce convergence clearly to the user:
`Pre-Production Token Ralph Loop converged (0 blocking reference errors, 0 continuity breaks across 14 shots). Breakdown locked. Ready for Step 05 — Shot Planning & Cost Approval.`
