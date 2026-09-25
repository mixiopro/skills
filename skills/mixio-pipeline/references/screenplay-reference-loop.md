# Screenplay ↔ Reference Loop

Step 01 does not end at the first `studio_upsert_screenplay`. It ends when every authored `#` token resolves to a real Cast & World look, every actual character and story-critical prop in the prose has an approved reference/look, every actual location has either an approved reference/look or an explicit user-approved `TEXT-ONLY` disposition, and incidental set dressing has an explicit text-only disposition. Between those points is a pre-gate loop with Step 02: **draft → extract → resolve → propose → register/enrich → review/approve → re-mention → re-upsert**.

The loop exists because an unresolved mention is silent. A `#` token that resolves to nothing fails soft and stays literal text — the screenplay persists, breakdown proceeds, and nothing binds a reference. `upsert_screenplay` returns `{ elementId, version, deduped }` and no mention diagnostics, so the write looks identical whether every token bound or none did. Checking is on you.

## Two entry paths

| | **A — Asset-Ready** | **B — Raw Idea / Script** |
|---|---|---|
| You have | a draft already carrying `#name.variant` mentions | prose, a synopsis, or a script with no tokens |
| Pass 1 does | sweep the prose **and** harvest the tokens already there, then reconcile the two | discover entities from sluglines, cues and CAPS |
| Usual outcome | most tokens resolve; the loop is about the few that don't | nothing resolves yet; the loop is the whole of Step 01 |
| Common trap | reading the tokens and skipping the prose — an entity nobody mentioned is invisible to the exit gate | minting a second `Tony Russo` beside episode 1's `TONY` |

Both paths converge at Pass 2. Run the same passes either way — Scenario A is not "already done", it is Scenario B with a head start.

## Pass 1 — extract

Read the prose for entities. **Both paths do this** — see the reconciliation note below for why Scenario A does not get to skip it.

- **Locations** — every slugline's location field, plus any location named in a `[Location: ...]` annotation.
- **Characters** — every character cue above a dialogue block, plus every named person in action lines. A cue is the reliable signal; a name in prose may be someone who never appears.
- **Props** — every ALL-CAPS token on first mention in action lines. Extract all of them, then classify each as story-critical (needs a Cast & World reference/look) or incidental set dressing (needs an explicit text-only disposition); do not silently discard either class.
- **Looks** — a described state change ("she comes out of the rain soaked", "he arrives in the tuxedo") is a candidate variant on an existing character, not a new one.

On an Asset-Ready draft, also collect the distinct `#` tokens already in the body. Grammar is `#` plus one to three dot-separated segments (see [screenplay grammar](../../mixio-episode/references/screenplay-grammar.md)); dedupe before resolving, since a token repeated twelve times is one question.

**Then reconcile the two lists.** A token that resolves is not the same as an entity that is covered, and the gap between them is silent in both directions:

| | Has a `#` token | No token |
|---|---|---|
| **In the prose** | resolve it in Pass 2 | **un-mentioned entity** — the exit gate cannot see it |
| **Not in the prose** | orphan token — mentioned but never staged; confirm it belongs | nothing to do |

The bottom-left cell is the one that bites. `INT. HARBOR OFFICE — NIGHT` with no `#harbor-office` mention anywhere leaves the screenplay at zero unmapped tokens and the location bound to nothing — an unmentioned entity is not an unresolved token, so a token-only sweep reports success on a draft that references half its world. Carry every un-mentioned candidate into Pass 3 alongside the unresolved tokens: an actual character or story-critical prop gets an exact mention and approved look; an actual location gets an exact mention and approved look, or an explicit user-approved `TEXT-ONLY` disposition with no authored `#` token; incidental set dressing gets an explicit text-only disposition. Nothing reaches the gate silently.

Emit the candidate list as a table and stop. Nothing is written in Pass 1.

## Pass 2 — resolve, with the reason

Two ways, use both:

```
studio_list_references({ projectId, limit })
```
returns the valid catalog plus `total` — collect enough results to cover that total before declaring the catalog complete. Diff the distinct tokens against the union of every `mentionableLooks[].mention` and `mentionableLooks[].views[].mention`. Anything in the diff goes to:

```
studio_resolve_mention({ projectId, mention: "#maya.wet_look" })
```

`resolve_mention` never throws for an unresolved mention — a caller probing whether a reference exists yet is the expected use. It returns `{ resolved: false, reason }`, and the `reason` string is the diagnosis:

| `reason` | What it means | What to propose |
|---|---|---|
| `no element named "…" in this project` | the entity does not exist | a new CHARACTER / LOCATION / PROP |
| `no look named "wet_look" on element "Maya"` | the entity exists, the variant does not | a **variant on Maya** — never a second Maya |
| `ambiguous: 2 elements named "…" in this project` | two references collapse to one name | resolve the duplicate first; do not create a third |

Two results that look like success and are not:

- **`resolved: true` with no `variantId`.** A bare `#maya` matched the element and stopped, but it is not a complete Step 01 binding. Upgrade it to the exact two-segment `#name.variant` token returned by `mentionableLooks`, even for a walk-on.
- **`resolved: true` on a view segment you invented.** View matching falls back — requested view → primary view → first view → primary attachment → first attachment — so a wrong third segment resolves to *some other angle* rather than failing. Only trust a third segment you copied from `mentionableLooks[].views[].mention`.

## Pass 3 — flag and ask, never mint

Report the whole set at once and ask once. Minting a near-duplicate to avoid a question is the failure this loop exists to prevent — a second `Maya` splits the identity and both halves drift for the rest of the episode.

```
Unmapped tokens — 3 of 14 (characters, locations, props)

  #maya.wet_look   Maya exists; look "wet_look" does not
  #harbor-office   no LOCATION named "harbor office"
  #tony            resolves to Tony, but binds no look (bare mention)

Un-mentioned entities — 2

  DOCKSIDE ALLEY   slugline in scene 4, no mention anywhere in the body
  THE PILOT        speaks in scene 2, no mention anywhere in the body

For #maya.wet_look:
  1. Generate a wet-look variant sheet now (one image job)
  2. You supply an image and I attach it as a variant

For DOCKSIDE ALLEY, which has no reference:
  1. You supply an image or link an existing approved reference
  2. You explicitly approve a generated location sheet
  3. You explicitly designate it TEXT-ONLY; I keep it plain prose and do not author a # location token
```

If the author means wetness, dirt, or an injury as per-shot state rather than a reusable look, author it as ordinary prose without an authored `#...wet_look` token. Do not remove an authored unresolved token as a silent escape hatch; edit the screenplay explicitly, then restart the reconciliation pass.

**Read the policy before offering the options.** `studio_get_project({ projectId })` → `settings.references` constrains which answers are even available:

- `createPolicy: link_only` — do not offer "create it". For a missing authored token, ask for an existing reference link or supplied/approved look. Only an actual plain-prose LOCATION or an incidental PROP may take the explicit user-approved rewrite/TEXT-ONLY branch; a CHARACTER or story-critical PROP stays blocked until it has a real look or the user approves a body rewrite that removes or replaces the entity. Re-run extraction after any rewrite; otherwise keep the loop blocked.
- `createPolicy: propose` — surface the proposal for approval; do not write on a yes-by-default.
- `variantPolicy: closed` — the new look's name must come from `variantVocabulary[TYPE]`. Offer the vocabulary terms, not a name you invented.

Full policy contract: `mixio-references`.

Do not close the loop while a newly registered reference, variant, or sheet is still `draft` or `in_review`. Show it to the user and move it to `workflow.status: "approved"` before the Step 01 gate. The screenplay itself remains a draft; its human Studio approval is a separate action.

## Pass 4 — register, then give it a look

```
studio_register_reference_entities({ projectId, references: [
  { type: "LOCATION", name: "Harbor Office", metadata: { aliases: ["the harbor office", "HARBOR OFFICE"] } }
]})
→ { registered: [{ id, type, name, action: "created" }] }
```

Upserts by `(project, type, normalized name)`, so a repeat call patches instead of duplicating and the batch is safe to resubmit after a timeout. Record alias metadata in the canonical reference workflow regardless; alias matching is conditional on project settings, but the data must be available if that setting is enabled later. This loop only needs the resulting canonical element.

**Registering a name does not make it mentionable.** `mentionableLooks` is derived from the reference's variants; a reference with no variant, no attachment and no legacy look returns an empty array, and `#harbor-office.day` still will not resolve. That is the whole reason Step 01 loops through Step 02 instead of running before it.

So close the gap: render the appropriate character, location, or story-critical prop sheet (`/mixio:sheets`) and attach it. Incidental props and explicitly approved `TEXT-ONLY` locations do not get a sheet; persist their named dispositions instead.

```
studio_update_reference({ projectId, referenceId,
  referenceVariants: [
    { name: "day",   kind: "primary", isDefault: true, images: [{ url: dayUrl, isPrimary: true }] },
    { name: "night", kind: "look",                     images: [{ url: nightUrl, isPrimary: true }] }
  ],
  locationDetails: { … },
  workflow: { status: "in_review" } })
```

`referenceVariants` replaces the variant list; `attachments` merges into the default look. Pick one per call — the distinction is the sharpest edge in `mixio-references`, read it there. `studio_register_reference_entities`'s `imageUrl`/`imageUrls` take the merge path, so a single image can be attached at registration time in one call.

For a story-critical prop, use the same branch with `type: "PROP"`: register or match the canonical prop, generate a prop sheet only after the user confirms the image work or attach a supplied image, populate `propDetails`, set the reference to `in_review`, obtain approval, then re-list and copy the exact prop `mentionableLooks` token back into the screenplay. Do not silently turn a story-critical prop into incidental set dressing.

## Pass 5 — put the real tokens back in the body

Re-run `studio_list_references({ projectId, limit })` after the writes, verify the response covers its reported `total`, and copy the exact base or nested view string from `mentionableLooks[].mention` or `mentionableLooks[].views[].mention` into the screenplay. Preserve an authored view token unless the user explicitly changes it. For an existing authored token, substitute in place. For an un-mentioned reference-backed candidate, insert the copied token at the relevant slugline, character cue, or first prop use. For an explicitly approved `TEXT-ONLY` location, ensure the body contains no authored `#` location token and retain the plain prose. Do not rebuild the body from scratch, or the loop loses the dialogue and annotations that were already approved.

Copy the string even when it looks wrong. A multi-word name is one hyphenated root segment (`#alpha-carter.wedding`, never `#alpha.carter.wedding`), and a reference whose images arrived as flat attachments rather than named variants gets a variant named after the reference itself — its mention is the doubled-looking `#maya.maya`, and that is the correct token.

Then re-upsert the whole body:

```
studio_upsert_screenplay({ projectId, episodeId, body })
```

Idempotent against the same episode's screenplay element, so every pass of the loop writes the same element rather than accumulating drafts.

## Exit gate

The loop closes only when all of these are true:

- **Zero authored `#` tokens are unmapped** — character, location, and prop tokens alike.
- Every authored view segment equals an exact `mentionableLooks[].views[].mention` token, and every bare `#name` has been upgraded to the exact catalog look token.
- Every actual character and story-critical prop found by the prose sweep has an exact mention and an approved Cast & World reference/look.
- Every actual location found by the prose sweep is either bound by an exact mention and approved reference/look, or has an explicit user-approved `TEXT-ONLY` disposition with no authored `#` location token.
- Every incidental set-dressing prop has an explicit text-only disposition.
- Every newly created reference, variant, and sheet has `workflow.status: "approved"`; pending review keeps Step 01 open.
- Every text-only decision is persisted as a named, user-approved disposition with `type`, canonical `name`, `classification` (`LOCATION_TEXT_ONLY` for a LOCATION or `INCIDENTAL_SET_DRESSING` for a PROP), `mode: "TEXT_ONLY"`, `status: "approved"`, and a non-empty reason; counts alone do not close the loop.

Re-run Pass 1's reconciliation and Pass 2's resolution against the final body and show the tally — a claim of zero that was not re-checked after the last edit is not a check.

```
Step 01 — Screenplay complete. 16 mentions, 16 resolved, 0 unmapped.
Prose sweep: 6 characters, 4 locations, 8 props — all reference-backed entities referenced; 3 incidental props classified text-only; 1 location text-only.
1 reference created (Harbor Office), 1 variant added (Maya · wet), 3 reference/variant reviews approved.
Screenplay saved as a draft — approval is yours to make in Studio. Moving to Step 02.
```

Report it as a **draft**. `upsert_screenplay` only ever writes one; approval is a human action in Studio's Screenplay view.

Record the outcome so a resumed session does not re-run the loop blind:

```
studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  step_01: "complete",
  screenplay_loop: { mentions: 16, unmapped: 0, unmentioned: 0,
                     props_extracted: 8, props_pending: 0,
                     locations_text_only: 1, locations_pending: 0,
                     dispositions: [
                       { type: "LOCATION", name: "Dockside Alley", classification: "LOCATION_TEXT_ONLY",
                         mode: "TEXT_ONLY", status: "approved", reason: "no supplied or approved image" },
                       { type: "PROP", name: "WINDOW", classification: "INCIDENTAL_SET_DRESSING",
                         mode: "TEXT_ONLY", status: "approved", reason: "incidental set dressing" },
                       { type: "PROP", name: "CEILING FIXTURE", classification: "INCIDENTAL_SET_DRESSING",
                         mode: "TEXT_ONLY",
                         status: "approved", reason: "incidental set dressing" },
                       { type: "PROP", name: "CANDLE", classification: "INCIDENTAL_SET_DRESSING",
                         mode: "TEXT_ONLY",
                         status: "approved", reason: "incidental set dressing" }
                     ],
                     references_created: 2, variants_added: 1,
                     references_pending_approval: 0 }
}}}})
```

Props are part of the Step 01 inventory and authored-token gate. Story-critical props need an approved reference/look before Step 03; incidental set dressing may remain text-only only after explicit classification and remains visible to Step 02.5. An authored `#` prop token never bypasses resolution. The same rule applies to locations: `TEXT-ONLY` is an explicit disposition for a plain-prose location, never a way to bypass an authored `#` location token.

## What this loop is not

| Concern | Where it belongs |
|---|---|
| Are the references that exist complete, consistent, duplicate-free? | Step 02.5, `mixio-reference-audit` |
| Extracting entities into scenes and shot links | Step 03, `mixio-script-breakdown` |
| Per-shot wardrobe / hair / condition | `appearanceState`, written at Step 03 |
| Rendering the sheets and anchors themselves | Step 02, `mixio-sheets` |

This loop owns the Step 01 screenplay/reference contract: every authored token binds, every actual character and story-critical prop has an approved look, every location is either reference-backed or explicitly `TEXT-ONLY`, and every incidental prop is explicitly classified. It does not replace the reference-completeness audit, scene breakdown, continuity audit, or shot planning listed above.
