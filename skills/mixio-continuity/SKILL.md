---
name: mixio-continuity
description: "Audit a shot breakdown for continuity before anything is rendered — build a blocking map, run the checks, report findings against a fixed issue taxonomy, then emit corrected shots and lock them. Text and blocking logic only — Cast & World completeness is mixio-reference-audit. Unclear which step you need → mixio-pipeline."
version: 0.2.0
invoke: /mixio:continuity
---

# Mixio Continuity

Step 04 of `mixio-pipeline`. A **text** audit of the breakdown, run before a single pixel exists. It is the highest-value step in the pipeline for one reason: a continuity break caught here costs a paragraph, and the same break caught after generation costs a re-render of every shot downstream of it.

This is not `mixio-eval`. Two different gates:

| | `mixio-continuity` | `mixio-eval` |
|---|---|---|
| When | after breakdown, **before** generation | after generation, before delivery |
| Reads | shot spec text | rendered pixels |
| Catches | a phone that vanishes with no put-down action | a phone that the model drew in the wrong hand |

Run both. The text audit is free and catches logic; the pixel audit costs a job and catches execution.

Vocabulary and the issue taxonomy: `mixio-pipeline/references/shot-grammar.md`.

## Prerequisites

- A persisted breakdown (Step 03) with `duration`, camera, action, and staging fields on every shot
- Ideally an anchor frame per scene (`mixio-sheets`) — determines the mode below

## Mode

State the mode at the top of the audit. It changes what you can honestly conclude.

- **GROUNDED** — the scene has an anchor frame. Blocking can be checked against real pixels; `ANCHOR` findings are meaningful.
- **TEXT-ONLY** — no anchor. Everything is checked against script text. Say so, and never report "0 anchor mismatches" — there is nothing to mismatch against.

`Auditing 1 scene in GROUNDED mode (anchor available).`

## Pass 1 — Blocking Map

One row per **shot × character**, including characters who are not in the shot. The absent rows are not filler: they are how you catch a character who silently teleports back into frame.

```
Scene 01 — blocking map
| Shot | Character | Zone | Facing              | Posture              | Relative to                  | Action in shot                        |
|------|-----------|------|---------------------|----------------------|------------------------------|---------------------------------------|
| 1    | TONY      | MC   | three-quarter-left  | seated cross-legged  | on BED, beside BEDSIDE TABLE | scrolls phone, expression cycles      |
| 1    | POPPY     | —    | —                   | —                    | off-screen (hallway)         | not present                           |
| 2    | TONY      | —    | —                   | —                    | —                            | insert — phone screen only, thumb     |
| 2    | POPPY     | —    | —                   | —                    | off-screen                   | not present                           |
| 4    | POPPY     | FL   | three-quarter-left  | standing             | stepping through HALLWAY DRWY| [M1] enters, crosses to BED FRAME edge|
| 7    | TONY      | MC   | away (OTS)          | seated               | on BED, right shoulder to cam| [M2] reaches to take tablet           |
| 7    | POPPY     | BG   | toward-camera       | standing             | behind tablet, soft focus    | holds tablet, watches TONY            |
```

Rules:
- Carry state forward. If shot 5 doesn't restate posture, inherit shot 3's — and note the inheritance, because an inherited value that contradicts a later shot is a finding.
- `—` for a character genuinely not in frame; keep the `Relative to` cell filled (`off-screen (hallway)`) so their location is still tracked.
- An insert/screen-only shot has no character blocking. Say so rather than inventing zones.

Build the map before looking for problems. Most breaks are invisible in prose and obvious in a table.

**Half of this map is persistable.** `appearanceState` on each `appears_in` relation carries `wardrobe`, `hairState`, `condition`, `carriedProps`, `emotionalState`, `lookRef` and `continuityNotes` per character per shot — validated, and readable back. Write the map's wardrobe/condition/held-props columns there as you build it and the next session inherits them instead of re-deriving. `lookRef` is not just readable back: where the shot-scoped look cascade is live it *selects the variant generation actually renders* (shot → scene → reference default), so binding it here becomes the one column in this map that changes the output, not just the record — a wrong or missing `lookRef` degrades silently to the default look rather than erroring. Check whether your Studio has it: `get_production_context` returns a `lookBindings` key once it does.

**Zone, facing, posture and relative-to have no canonical field — durable-but-unchecked, not session-local.** `appearanceState` is appearance, not staging, and the shot's canonical `blocking` is one string for the whole frame, so there's no validated home for these four columns. Written as passthrough (inline in `action`/`blocking`, or as their own keys) they persist and survive re-entry — but nothing downstream reads or enforces them, so restate posture and facing in each shot's own text rather than trusting an inherited value is still correct.

## Pass 2 — Continuity Checks

Enumerated, each one traced shot by shot, each one closing with `FINDING:` or `✅`. Show the trace — a bare verdict can't be reviewed.

```
1. Prop/hand continuity — phone→tablet transition (Shots 5–8)
   • Shot 5: TONY holds phone in both hands
   • Shot 7: TONY reaches with right hand to take tablet from POPPY — but what
     happens to the phone? No action states her putting it down.
   • Shot 8: TONY holds the tablet — phone has vanished with no stated action.
   FINDING: phone disappears between Shots 5–7 with no stated put-down action.

2. Prop continuity — POPPY's tablet → arms crossed (Shots 7–9)
   • Shot 7: POPPY passes the tablet to TONY [M2]
   • Shot 9: POPPY's arms are crossed — tablet handed off at [M2]. ✅ This tracks.

3. POPPY's facing — Shot 6 vs Shot 5
   • Shot 5: POPPY facing three-quarter-right (toward TONY)
   • Shot 6: POPPY facing toward-camera (CU on her face)
   • No turn stated — but this is a camera reposition (CU on POPPY), not a character
     turn. The camera moved to face her; she stayed oriented toward TONY/BED. ✅
```

### The check list

Run all of these, every time:

1. **Prop/hand continuity** — for each story prop, trace who holds it across every shot. Every appearance, disappearance, and change of hands needs a stated action causing it. This is the single most common break.
2. **Presence** — a character may only be absent from a shot when the camera isn't framing them. Absent from a shot the camera *does* cover means they left, and leaving needs a beat.
3. **Facing** — a facing change needs a stated turn. **Unless the camera moved.** Always ask "did the subject turn, or did the lens?" before flagging: a CU that puts a character toward-camera when the previous wide had them three-quarter is a reposition, not a break. Miscalling these is the fastest way to make an audit useless.
4. **Posture** — a posture change needs a stated movement. Carried-forward postures count.
5. **Wardrobe** — clothing/accessories are fixed within a scene absent a costume beat. Check the character sheet's `visualAnchor` is not contradicted.
6. **Eyeline / axis** — two characters facing each other must not both face the same screen direction; check against the location sheet's `Depth & axes`.
7. **Lighting** — every shot states `as Anchor N` or justifies deviating. Time-of-day drift within a scene is a break.
8. **Anchor consistency** (GROUNDED only) — does the described staging match what the anchor image actually shows?
9. **Field completeness** — `GAP` for a missing field, `VAGUE` for a present-but-underspecified one (`seated`, `nearby`, `some light`).
10. **Marker integrity** — every `[Mn]` referenced by another shot exists, and the referencing shot comes after it.
11. **Reference readiness** — for each `character_links` / `location_links` / `prop_links` entry, confirm the reference element exists and (for characters/locations appearing in ≥2 shots) has at least one attached image. This is a cross-check against Step 02.5's audit — a reference that passed the audit but was later deleted or corrupted is caught here. Findings use code `REF_MISSING` (no element) or `REF_NO_IMAGE` (element exists, no media attached).

## Pass 3 — Report

Counts first, then one line per issue, then the clean list.

```
Scene 01 — 2 continuity breaks, 0 GAPs, 1 vague field, 0 anchor mismatches

Shot 7  | TONY  | PROP  — phone disappears with no stated put-down action
Shot 7  | TONY  | VAGUE — posture "seated" should be "seated cross-legged"
Shot 8  | POPPY | PROP  — "POPPY's arm holding the tablet" but the tablet was
                          passed to TONY at [M2] in Shot 7

Episode: 13 shots — 2 breaks, 0 GAPs, 1 vague, 0 anchor mismatches.
Clean shots: 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13.
```

Name the clean shots explicitly. It tells the user what is locked, and it forces you to have actually considered every shot rather than only the ones with problems.

## Pass 4 — Corrections

A change log, then the full corrected shots. Never a diff fragment — emit the whole shot so what's persisted is unambiguous.

```
Change log:
Shot 7 | TONY  | Action: added "TONY drops her phone onto the bedding beside her, then
                 reaches with her right hand to take the tablet" — resolves phone disappearance
Shot 7 | TONY  | Posture: "seated" → "seated cross-legged" — carried forward from Shot 5
Shot 8 | POPPY | Camera In-frame: "POPPY's arm holding the tablet entering bottom frame edge"
                 → "POPPY's hand resting on the BED FRAME edge entering bottom of frame"
                 — tablet already with TONY after [M2]

Corrected shots:
Shot 7 — 4.5s [M2] (CORRECTED)
  Camera:            ...full corrected spec...
```

Rules:
- **Fix the cause, not the symptom.** A prop that vanishes gets a put-down *action* added in the shot where it leaves her hand — not a note bolted onto the shot where its absence was noticed. Then check the sibling shots that carried the same wrong state; one fix at the source beats three patches downstream.
- Preserve duration unless the fix genuinely needs more screen time — a changed duration re-batches the episode (Step 05).
- Mark every corrected shot `(CORRECTED)`.

## Persisting the result

```
# content fixes
studio_revise_shot_specs({ shots: [{ shotId, metadata: { action, camera_movement, ... } }] })

# per-character appearance facts the corrections established
studio_link_graph({ projectId, relations: [{
  fromId: characterId, toId: shotId, relationType: "appears_in",
  metadata: { carriedProps: ["TABLET"], continuityNotes: "phone put down in this shot [M2]" }
}]})

# verdict + audit trail
studio_update_shot_state({ shots: [
  { shotId: cleanId,     state: "approved" },
  { shotId: correctedId, state: "in_review",
    continuity: { pass: 4, issues: ["PROP — phone disappeared; put-down action added"] } }
]})
```

`update_shot_state` takes `{ shotId, state?, feedback?, continuity?, review?, metadata?, tags? }`. `state`, `feedback`, `continuity`, and `review` are written to `metadata.state` / `.feedback` / `.continuity` / `.review`. `continuity` and `feedback` each accept **a string or an object** — prefer an object so the report is machine-readable on re-entry. `state` values: `approved`, `needs_revision`, `in_review`, `scripting`.

Prefer the relation write for facts about a *character in a shot* (they carry the tablet now) and `update_shot_state.continuity` for the *verdict* on the shot. Putting a per-character fact in the shot verdict loses which character it was about.

Keep them separate calls, in that order: `revise_shot_specs` for creative content, `update_shot_state` for workflow — that separation is why they're two tools. Note `revise_shot_specs` validates the spec partition against the canonical shot spec, but only for a *recognized* canonical field holding a malformed value — an unrecognized key is never rejected. Use canonical keys anyway (`camera_movement`, not `Camera:`): a casing variant gets silently remapped onto the canonical key, and a cross-spec key still writes to passthrough with only a console warning, not an error — so a typo doesn't fail the write, it just fails to mean anything, and that failure is silent. See `mixio-script-breakdown` for the full mapping. Then close the step:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: { step_04: "complete" } } } })
```

`Step 04 — Continuity Audit complete. Corrected breakdown locked.`

## Workflow

```
1. read breakdown + anchors; declare GROUNDED or TEXT-ONLY
2. Pass 1 — blocking map, every shot × every character
3. Pass 2 — the 10 checks, each traced, each closing FINDING or ✅
4. Pass 3 — counts + one line per issue + clean shot list
5. Pass 4 — change log + full corrected shots
6. studio_revise_shot_specs → studio_update_shot_state → GATE → Step 05 Shot Planning
```

## Notes

- Audit one scene at a time, then roll up to an episode total. Cross-scene checks are limited to props and wardrobe carried between scenes.
- Zero findings on a real 13-shot scene usually means the checks were run loosely. The vague-field check alone almost always catches something.
- Re-run the audit after any Step 03 edit. It is text-only, so re-running is free; assuming a stale audit still holds is not.
