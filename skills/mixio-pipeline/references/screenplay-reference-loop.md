# Screenplay ↔ Reference Loop

Step 01 does not end at the first `studio_upsert_screenplay`. It ends when every `#` token in the body resolves to a real Cast & World look. Between those two points is a loop with Step 02: **draft → extract → resolve → propose → register/render → re-mention → re-upsert**.

The loop exists because an unresolved mention is silent. A `#` token that resolves to nothing fails soft and stays literal text — the screenplay persists, breakdown proceeds, and nothing binds a reference. `upsert_screenplay` returns `{ elementId, version, deduped }` and no mention diagnostics, so the write looks identical whether every token bound or none did. Checking is on you.

## Two entry paths

| | **A — Asset-Ready** | **B — Raw Idea / Script** |
|---|---|---|
| You have | a draft already carrying `#name.variant` mentions | prose, a synopsis, or a script with no tokens |
| Pass 1 does | harvest the distinct `#` tokens already in the body | discover entities from sluglines, cues and CAPS |
| Usual outcome | most tokens resolve; the loop is about the few that don't | nothing resolves yet; the loop is the whole of Step 01 |
| Common trap | trusting a token because the author wrote it confidently | minting a second `Tony Russo` beside episode 1's `TONY` |

Both paths converge at Pass 2. Run the same passes either way — Scenario A is not "already done", it is Scenario B with a head start.

## Pass 1 — extract

**Scenario A.** Collect the distinct `#` tokens from the body. Grammar is `#` plus one to three dot-separated segments (see [screenplay grammar](../../mixio-episode/references/screenplay-grammar.md)); dedupe before resolving, since a token repeated twelve times is one question.

**Scenario B.** There are no tokens yet, so read the prose:

- **Locations** — every slugline's location field, plus any location named in a `[Location: ...]` annotation.
- **Characters** — every character cue above a dialogue block, plus every named person in action lines. A cue is the reliable signal; a name in prose may be someone who never appears.
- **Props** — CAPS tokens on first mention in action lines. Only the ones that carry story weight or change hands need a reference; set dressing belongs in the location sheet.
- **Looks** — a described state change ("she comes out of the rain soaked", "he arrives in the tuxedo") is a candidate variant on an existing character, not a new one.

Emit the candidate list as a table and stop. Nothing is written in Pass 1.

## Pass 2 — resolve, with the reason

Two ways, use both:

```
studio_list_references({ projectId, limit })
```
gives the whole valid catalog at once — the union of every `mentionableLooks[].mention` and `mentionableLooks[].views[].mention`. Diff your distinct tokens against it. Anything in the diff goes to:

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

- **`resolved: true` with no `variantId`.** A bare `#maya` matched the element and stopped. Fine for a walk-on; for anything generated against a specific look, upgrade it to the two-segment `#name.variant` form.
- **`resolved: true` on a view segment you invented.** View matching falls back — requested view → primary view → first view → primary attachment → first attachment — so a wrong third segment resolves to *some other angle* rather than failing. Only trust a third segment you copied from `mentionableLooks[].views[].mention`.

## Pass 3 — flag and ask, never mint

Report the whole set at once and ask once. Minting a near-duplicate to avoid a question is the failure this loop exists to prevent — a second `Maya` splits the identity and both halves drift for the rest of the episode.

```
Unmapped tokens — 3 of 14

  #maya.wet_look   Maya exists; look "wet_look" does not
  #harbor-office   no LOCATION named "harbor office"
  #tony            resolves to Tony, but binds no look (bare mention)

For #maya.wet_look:
  1. Generate a wet-look variant sheet now (one image job)
  2. You supply an image and I attach it as a variant
  3. It is per-shot state, not a costume — drop the mention, and I
     carry "soaked" as appearanceState.hairState at Step 03
```

Option 3 is the right answer more often than it looks. Hair state, wetness, dirt and injuries are properties of an *appearance*, not of the character, and a wardrobe variant spent on "wet" is a variant that cannot be reused — see the appearance-state contract in `mixio-script-breakdown` and the wardrobe-variant rules in `mixio-sheets`.

**Read the policy before offering the options.** `studio_get_project({ projectId })` → `settings.references` constrains which answers are even available:

- `createPolicy: link_only` — do not offer "create it". Report the unmapped token and link to an existing reference or leave it out.
- `createPolicy: propose` — surface the proposal for approval; do not write on a yes-by-default.
- `variantPolicy: closed` — the new look's name must come from `variantVocabulary[TYPE]`. Offer the vocabulary terms, not a name you invented.

Full policy contract: `mixio-references`.

## Pass 4 — register, then give it a look

```
studio_register_reference_entities({ projectId, references: [
  { type: "LOCATION", name: "Harbor Office", metadata: { aliases: ["the harbor office", "HARBOR OFFICE"] } }
]})
→ { registered: [{ id, type, name, action: "created" }] }
```

Upserts by `(project, type, normalized name)`, so a repeat call patches instead of duplicating and the batch is safe to resubmit after a timeout. Record aliases here — this is what stops episode 2 minting a second reference for the same character.

**Registering a name does not make it mentionable.** `mentionableLooks` is derived from the reference's variants; a reference with no variant, no attachment and no legacy look returns an empty array, and `#harbor-office.day` still will not resolve. That is the whole reason Step 01 loops through Step 02 instead of running before it.

So close the gap: render the turnaround or location sheet (`/mixio:sheets`) and attach it.

```
studio_update_reference({ referenceId,
  referenceVariants: [
    { name: "day",   kind: "primary", isDefault: true, images: [{ url: dayUrl, isPrimary: true }] },
    { name: "night", kind: "look",                     images: [{ url: nightUrl, isPrimary: true }] }
  ],
  locationDetails: { … } })
```

`referenceVariants` replaces the variant list; `attachments` merges into the default look. Pick one per call — the distinction is the sharpest edge in `mixio-references`, read it there. `studio_register_reference_entities`'s `imageUrl`/`imageUrls` take the merge path, so a single image can be attached at registration time in one call.

## Pass 5 — put the real tokens back in the body

Re-run `studio_list_references({ projectId, limit })` after the writes and copy the exact `mentionableLooks[].mention` strings into the screenplay. Substitute in place; do not rebuild the body from scratch, or the loop loses the dialogue and annotations that were already approved.

Copy the string even when it looks wrong. A multi-word name is one hyphenated root segment (`#alpha-carter.wedding`, never `#alpha.carter.wedding`), and a reference whose images arrived as flat attachments rather than named variants gets a variant named after the reference itself — its mention is the doubled-looking `#maya.maya`, and that is the correct token.

Then re-upsert the whole body:

```
studio_upsert_screenplay({ projectId, episodeId, body })
```

Idempotent against the same episode's screenplay element, so every pass of the loop writes the same element rather than accumulating drafts.

## Exit gate

The loop closes when **zero character or location tokens are unmapped**. Re-run Pass 2 against the final body and show the tally — a claim of zero that was not re-checked after the last edit is not a check.

```
Step 01 — Screenplay complete. 14 mentions, 14 resolved, 0 unmapped.
2 references created (Harbor Office, Dockside Alley), 1 variant added (Maya · wet).
Screenplay saved as a draft — approval is yours to make in Studio. Moving to Step 02.
```

Report it as a **draft**. `upsert_screenplay` only ever writes one; approval is a human action in Studio's Screenplay view.

Record the outcome so a resumed session does not re-run the loop blind:

```
studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  step_01: "complete",
  screenplay_loop: { mentions: 14, unmapped: 0, references_created: 2, variants_added: 1 }
}}}})
```

Props are deliberately outside the exit condition. A prop with no reference is a Step 02.5 finding, not a Step 01 blocker — a shot can be generated against a described prop, but not against a character or a space nobody has seen.

## What this loop is not

| Concern | Where it belongs |
|---|---|
| Are the references that exist complete, consistent, duplicate-free? | Step 02.5, `mixio-reference-audit` |
| Extracting entities into scenes and shot links | Step 03, `mixio-script-breakdown` |
| Per-shot wardrobe / hair / condition | `appearanceState`, written at Step 03 |
| Rendering the sheets and anchors themselves | Step 02, `mixio-sheets` |

This loop only answers one question: does every token in the screenplay point at something real?
