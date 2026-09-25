---
name: mixio-eval
description: "Run visual continuity and consistency evaluations on generated media through the hosted Studio evaluator gateway before delivery."
version: 0.3.0
invoke: /mixio:eval
---

# Mixio Eval

Evaluate rendered media before delivery. This skill uses the modern hosted
Studio evaluator gateway. For text-only, pre-render continuity audits, use
`mixio-continuity`.

## Boundary with `mixio-continuity`

Use `mixio-continuity` for the pre-render, text-and-shot-spec audit that can
correct screenplay or shot metadata before pixels are generated. Use this skill
only for rendered images/video and evaluator-backed visual evidence. When a
request is ambiguous, route it through `mixio-pipeline`; do not use a rendered
media evaluation as a substitute for the pre-render continuity audit.

## Scope and compatibility boundary

The canonical evaluation surface is:

| Hosted MCP name | Local stdio proxy | Mixio CLI command | Purpose |
| --- | --- | --- | --- |
| `evals_list_evaluation_catalog` | `studio_evals_list_evaluation_catalog` | `evals-list-evaluation-catalog` | Read the approved profile catalog for a confirmed project. |
| `evals_evaluate_media` | `studio_evals_evaluate_media` | `evals-evaluate-media` | Submit one background evaluation. |
| `evals_get_evaluation_result` | `studio_evals_get_evaluation_result` | `evals-get-evaluation-result` | Poll one existing evaluation run. |

`run_eval`, `run_evaluation`, and `get_evaluation_result` are deprecated
compatibility aliases only. Their stdio/CLI spellings are
`studio_run_eval`/`run-eval`, `studio_run_evaluation`/`run-evaluation`, and
`studio_get_evaluation_result`/`get-evaluation-result`. They exist for clients
that are pinned to an older hosted surface; they are not the pipeline contract.

The aliases accept the legacy `capability`, `videoUrl`, and `imageUrls` shape.
Legacy capability names are therefore an adapter concern, not canonical
profile or metric names. If a compatibility adapter is unavoidable, translate
the request once at that boundary, call one alias once, and poll the returned
run with the canonical result reader when the server permits it. Do not call an
alias and its replacement for the same run. If an alias cannot represent the
ordered keyframe, expected-state, or shot-plan context below, mark the strict
continuity gate unavailable rather than silently downgrading it.

## Prerequisites and scope

- Resolve and confirm the Studio `projectId` before evaluation. If it is not
  established, call `studio_list_projects`, show the numbered list in the same
  message as the question, and ask the user to choose. Never invent a project
  ID or create a project to avoid the choice.
- Evaluation submission is billable. Confirm the planned evaluation unless the
  session already authorizes it. Catalog and contract reads are non-billable;
  this skill's examples and checks must not submit a live evaluation.
- Local stdio clients use the `studio_` prefix. Direct hosted `/api/mcp`
  clients use the bare hosted names. The CLI exposes the same names in
  kebab-case.
- Upload local media through `mixio-workspace`, with the known project and
  organization scope, and pass permanent public URLs to the evaluator. Public
  `source-url` values must use HTTP(S) and must not target private or loopback
  hosts.

## Discover the live contract and catalog

Read the current contract before using an unfamiliar tool:

```text
studio_get_contract({ target: "tool", toolName: "evals_evaluate_media" })
studio_get_contract({ target: "tool", toolName: "evals_get_evaluation_result" })
studio_evals_list_evaluation_catalog({ projectId })
```

The contract currently exposes an open evaluator configuration surface for
`profile`, `metrics`, `skills`, `plan`, `shot-plan`, `keyframe-continuity`,
`shots`, `modifiers`, and `output-schema`. The live catalog owns the meaning and
availability of those values. Do not invent required metric identifiers, copy the old `capability`
enum into a modern request, or make a profile-specific metric mandatory unless
the catalog response says so.

## Canonical request contract

The modern evaluator request schema requires `project-id`, a non-empty ordered `inputs`
array, and a numeric `threshold` from `0` through `1`. This skill adds two
intentional strictness rules: always select an explicit catalog `profile`, and
always provide a non-empty `prompt`. Omitting either lets a server default hide
which quality gate was actually run.

The modern evaluator payload spells project scope `project-id`, as in the
example. A Studio MCP transport exposes the same scope as `projectId`; map it
at the transport adapter boundary and never send both spellings in one modern
request. For a local call, convert
`{ "project-id": wire["project-id"], ...wire }` to
`{ projectId: wire["project-id"], ...wireWithoutProjectId }` before calling
`studio_evals_evaluate_media`; the hosted/CLI adapter converts it back to the
wire spelling. Polling similarly maps `projectId`/`runId` at the tool boundary
to the wire request's `project-id`/`run-id`.

The canonical request uses `project-id`, an explicit catalog `profile`, ordered
`inputs`, a non-empty `prompt`, a threshold, and background execution. The
complete deterministic request is kept in the JSON example below.

Each input must have:

- a unique kebab-case `input-alias`;
- a live-contract `role` such as `candidate`, `reference`, `expected-state`,
  or `sequence`;
- a live-contract `type` such as `image`, `video`, `text`, `sequence`, or a
  canonical reference type; and
- exactly one source: `source-url`, `asset-id`, or `reference-id`.

Use `view` only when the source is a view the live contract accepts. The
pipeline treats `profile`, `prompt`, `threshold`, and `background: true` as
required, even where the wire schema leaves some of them optional. Keep
`execution-mode: "background"` and `stream: false` only when the current
contract or client requires the explicit forms; do not request streaming.

The complete deterministic request example is
[references/modern-evaluation-request.example.json](references/modern-evaluation-request.example.json).

## Reference-pack readiness

Use `image-character` for a character turnaround or wardrobe sheet. Treat face
identity, anatomy, hands/limbs, wardrobe/accessories, and generation artifacts
as required quality gates; a clean aggregate score must not hide a deformed
face, extra limb, fused hand, or unexplained costume change. For a multi-view
sheet, pass the views as ordered image inputs and include the
`reference-coverage` context.

Use `image-location` for a location reference pack. It requires at least two
image views, a `location-reference` anchor, and explicit coverage metadata.
Record each view's camera position, facing direction, visible landmarks, and
world-to-screen mapping. Add `shot-zones` when the shot plan needs a reverse,
overhead, underslung, top, bottom, or detail view. Do not generate every angle
by habit: required views come from the planned camera zones.

Keep these coordinate systems distinct: `world-left`/`world-right` are fixed
to the location; `camera-left`/`camera-right` may reverse; `character-left`/
`character-right` are anatomical; and `screen-left`/`screen-right` belong to
one shot. A reverse angle is not a defect by itself. A landmark crossing the
declared axis, or changing color/shape between adjacent views without an
intended change, is.

The coverage context is trusted evaluator input, not free-form prompt prose.
Missing required aliases, unbound views, or unsupported location geometry fail
the readiness gate rather than being filled in by model inference.
See [references/reference-readiness-request.example.json](references/reference-readiness-request.example.json)
for a complete location-pack request.

The example also requests an explicit `output-schema` wrapper for a structured
continuity extension: `review-verdict`, `worst-transition`,
`blocking-findings`, and per-transition `transitions` containing localized
`transition-findings`. The stable result already owns the reserved core
`verdict` field,
so an extension must use its own lower-kebab-case names and cannot redeclare
core properties. This asks the evaluator for a response shape; it does not
replace profile-owned semantics, and it never replaces client-side result
normalization and gate validation.
Use `{ mode, namespace, schema }` for an inline extension; the JSON Schema
document belongs under `schema`, not at the `output-schema` root.
Treat unsupported or omitted output-shape fields as contract uncertainty and
retain the raw `evaluation` payload.

## Ordered keyframe/video evidence

`inputs` is an evidence sequence, not an unordered attachment tray. Preserve
the production order in the array and make that order unambiguous in both
aliases and the prompt:

1. For every strict adjacent transition `shot-N → shot-N+1`, put the final
   keyframe for `shot-N` immediately before the first keyframe for `shot-N+1`,
   bind both through `role: "candidate"`, and describe their concrete
   `frame-index` or `time-ms` in the top-level `keyframe-continuity` context.
   Use `role: "sequence"` for the general `sequence-storyboard` lens.
2. Add the rendered candidate with `role: "candidate"` and `type: "video"`
   when judging a video. Keep its alias in the prompt, for example
   `@shot-02-video`.
3. If expected state is hosted as an evaluator-readable artifact, add one
   `role: "expected-state"`, `type: "text"` input using its public URL,
   `asset-id`, or `reference-id`. This is evidence/context, not a substitute
   for the ordered frames.
4. Use the optional `shots` array for stable shot IDs and descriptions, and
   the open `shot-plan` object for transition expectations. Keep shot IDs in
   the same order as the evidence and never rely on lexical alias sorting.
5. Mention every active input alias in the prompt as `@alias`. This binds the
   written review request to the evidence list without adding generation-only
   fields such as `slotTags` or `mentionMap` to the evaluator request.

The recommended `shot-plan` convention is skill-side context passed through
the live open object; it is not an invented required evaluator schema:

```json
{
  "sequence": ["shot-01", "shot-02"],
  "transitions": [
    {
      "id": "shot-01-to-shot-02",
      "from": "shot-01",
      "to": "shot-02",
      "expectedState": {
        "screenDirection": "Maya travels left-to-right; preserve the established axis",
        "spatialGeography": "door is background-left; table is foreground-right",
        "identity": "same Maya look and facial identity",
        "pose": "right hand remains raised toward the table",
        "wardrobe": "blue jacket and silver watch remain unchanged",
        "propState": "red cup remains in the right hand",
        "palette": "cool blue room with a warm red-cup accent",
        "lighting": "soft daylight from camera-left; exposure holds",
        "camera": "wide to right over-shoulder; preserve eyeline and geography",
        "temporalArtifacts": "no flicker, geometry warp, ghosting, or frame jump"
      },
      "intentionalChanges": [
        {
          "kind": "editorial-cut",
          "description": "wide shot cuts to an over-shoulder angle"
        }
      ]
    }
  ]
}
```

For cross-angle checks, describe the scene geography rather than only saying
“keep the subject consistent”: name the axis, screen direction, depth order,
landmarks, frame regions, eyeline, and any deliberate axis crossing. Record
identity, pose, wardrobe, and prop state separately from geography so a subject
can remain the same while a handoff or prop placement still fails.

## What the strict continuity review covers

The `keyframe-continuity` prompt and `shot-plan` should make these dimensions explicit for every
adjacent transition and for any cross-angle comparison:

- screen direction and spatial geography, including relative subject/prop
  position and the 180-degree axis;
- identity, pose, wardrobe, and prop state;
- palette and color relationships;
- lighting direction, quality, and exposure;
- camera continuity, including framing, lens impression, movement, eyeline,
  and intentional angle changes; and
- temporal artifacts such as flicker, geometry/identity morphing, ghosting,
  frame jumps, or other unstable motion.

Declare editorial cuts and state changes in `intentionalChanges` with the
affected transition and the exact change (for example, a wardrobe change,
prop pickup, time-of-day change, or deliberate axis crossing). A declared
change is exempt only for the named dimension; undeclared drift across the
same transition remains a failure. A hard cut does not excuse within-shot
flicker, temporal artifacts, or an unexplained state change.

## Profile routing

Use one explicit profile per request, selected from the live catalog. If a
production needs more than one quality lens, submit separate approved runs and
retain each receipt; do not put an invented profile list or metric enum into a
single request.

| Profile | Use as the primary lens for | Not a substitute for |
| --- | --- | --- |
| `image-character` | Character turnarounds and candidate sheets, including deformation, face, hands, wardrobe, and identity checks. | A rendered video-character or final delivery review. |
| `image-location` | Location packs with world-axis, landmark, orientation, lighting, palette, and artifact checks. | The shot-level keyframe continuity gate. |
| `keyframe-continuity` | Strict ordered keyframe evidence and adjacent-transition gating with expected state. | A general storyboard review or final delivery QC. |
| `sequence-storyboard` | General storyboard/keyframe visual review and sequence context. | The strict adjacent-transition gate or final delivery QC. |
| `video-multi-shot` | A rendered multi-shot candidate, cuts, and cross-angle geography. | Character-only review. |
| `video-character` | Identity, pose, wardrobe, and character-state continuity. | Full temporal/delivery review. |
| `video-general` | General visual artifacts and broad palette, lighting, camera, or motion review when the catalog exposes that coverage. | A transition-specific gate when no ordered evidence is supplied. |
| `delivery-qc` | Final candidate delivery/readiness review after continuity gates pass. | The strict adjacent-keyframe continuity gate. |

These are catalog profile identifiers, not a new capability enum. The catalog
may provide profile-specific skills or metrics; pass those only when the live
catalog contract returns them. A high aggregate or average result never
overrides a localized blocking transition finding.

## Submit and poll

Submit the canonical request once:

```text
const { ["project-id"]: projectId, ...wireWithoutProjectId } = wire;
studio_evals_evaluate_media({ projectId, ...wireWithoutProjectId });
```

Keep the returned opaque `runId`, then poll with:

```text
studio_evals_get_evaluation_result({ projectId, runId })
```

Poll until the outer `terminal` is `true`. The normalized lifecycle statuses
are `queued`, `in_progress`, `completed`, `failed`, and `cancelled`. A
successful tool call (`ok: true`) only means that submission or result lookup
succeeded; it does not mean the quality gate passed. Pending results may have
`threshold: null`; a terminal result must report the applied threshold. Do not
resubmit while a run is pending or after an uncertain receipt—reconcile the
existing run first.

## Result interpretation and gate

The result envelope is stable, but the nested `evaluation` object is
provider/profile-owned. Retain the raw `evaluation` object and normalize only
the fields the selected profile actually returns. For the pipeline decision,
each finding should be localized to a transition or shot and retain:

```text
transitionId · dimension · classification · blocking
```

This is a pipeline-side interpretation record, not an additional submission
schema. Use `classification: intended_change` for a declared cut/state change,
`accidental_drift` for an unexplained continuity break, `technical_artifact`
for temporal/render instability, and `unlocalized` when the evaluator does not
identify the affected shot or transition.

Approve only when all of the following hold:

1. the run is terminal and completed;
2. the provider/profile decision is acceptable at the requested threshold;
3. every required adjacent transition has localized evidence;
4. the worst transition is acceptable; and
5. no finding is blocking, accidental drift, technical artifact, or an
   unexplained/unlocalized failure.

The worst transition and any blocking finding win over the aggregate score. A
single severe position contradiction, identity/wardrobe/prop jump,
palette/color or lighting/exposure jump, camera-geography break, or temporal
artifact therefore blocks approval even when the overall average is high.
Declared intentional changes are not accidental failures, but they must still
be present in the shot plan and must not mask failures in other dimensions.

Retain the request JSON, ordered aliases and source IDs/URLs, prompt, selected
profile, threshold, `runId`, and terminal response with the production review
record. Redact credentials and avoid copying private media into public skill
examples.

## Tips / Pitfalls

- Keep `keyframe-continuity` for strict ordered-transition gates; `sequence-storyboard` is a general storyboard lens.
- Treat `project-id` versus a Studio tool's `projectId` as an explicit transport adapter boundary; do not mix them in one payload.
- Put custom JSON Schema under the `output-schema.schema` wrapper with a lower-kebab `namespace` and an allowed `mode`.
- A submitted run is not a passing gate: poll the same `runId`, inspect localized findings, and preserve the raw evaluator response.
