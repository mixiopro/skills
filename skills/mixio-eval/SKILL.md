---
name: mixio-eval
description: "Run visual continuity and consistency evaluations on generated media through the hosted Studio evaluator gateway before delivery."
version: 0.2.0
invoke: /mixio:eval
---

# Mixio Eval

Evaluate rendered media before delivery. This skill uses the hosted Studio
gateway and its Studio project scope. For text-only pre-render continuity audits,
use `mixio-continuity`.

## Prerequisites and transport

- Resolve the Studio project before evaluation. If none is established, call
  `studio_list_projects`, show the numbered list in the same message as the
  question, and ask the user to choose. With exactly one project, name it and
  continue. Never invent a project ID or create a project to avoid asking.
- Local stdio clients use `@mixio-pro/mcp@0.6.0`. This bridge prefixes hosted
  tools with `studio_`; direct hosted `/api/mcp` clients use bare names.
- Evaluation submission is billable. Confirm the planned evaluation unless the
  session already authorizes it; catalog and result reads do not submit work.
- Read the current contract before calling an unfamiliar tool. Examples below
  use stdio names; strip only the leading `studio_` for direct hosted calls.

| Direct hosted tool | Local stdio tool | Purpose |
| --- | --- | --- |
| `evals_list_evaluation_catalog` | `studio_evals_list_evaluation_catalog` | Read available evaluation profiles and configuration for a confirmed `projectId`. |
| `evals_evaluate_media` | `studio_evals_evaluate_media` | Submit one background evaluation. |
| `evals_get_evaluation_result` | `studio_evals_get_evaluation_result` | Read the existing run using `projectId` and `runId`. |

The bridge's five unprefixed tools are `upload_file`, `get_public_url`,
`list_cached_files`, `forget_path`, and `clear_cache`. Upload local media through
`mixio-workspace`, passing the known project and organization scope, then supply
the resulting permanent public URL to the hosted evaluator. Evaluation does not
have a separate local project listing or local execution tool.

## Discover the contract

```text
studio_get_contract({ target: "tool", toolName: "evals_evaluate_media" })
studio_get_contract({ target: "tool", toolName: "evals_get_evaluation_result" })
studio_evals_list_evaluation_catalog({ projectId })
```

`toolName` selects the bare hosted name even when `get_contract` itself is
prefixed. Choose profile, metrics, and skills from the live evaluation catalog;
do not reuse an old capability enum as the canonical request contract.

## Submit and poll

Canonical submission requires `projectId`, a nonempty `inputs` array, and an
explicit `threshold` from 0 to 1. Each input requires `input-alias`, `role`,
`type`, and exactly one source: `source-url`, `asset-id`, or `reference-id`.
Public media URLs must use HTTP(S) and must not target private or loopback hosts.
Read the live contract for accepted roles, media types, views, profiles, and
optional planning fields. Background mode is enforced by Studio.

Example video submission (replace project and URL with resolved production data):

```json
{
  "projectId": "confirmed-studio-project-id",
  "profile": "video-general",
  "inputs": [
    {
      "input-alias": "candidate",
      "role": "candidate",
      "type": "video",
      "source-url": "https://media.example.com/approved-shot.mp4"
    }
  ],
  "prompt": "Review @candidate for continuity and consistency against the approved shot intent.",
  "threshold": 0.8,
  "background": true
}
```

Send that object to `studio_evals_evaluate_media` once. Keep its returned `runId`
and poll `studio_evals_get_evaluation_result({ projectId, runId })` until
`terminal` is true. Do not resubmit while waiting or after an uncertain receipt;
reconcile the existing run first.

Successful submission and result calls share the envelope
`{ ok, runId, status, terminal, threshold, evaluation }`. Status is `queued`,
`in_progress`, `completed`, `failed`, or `cancelled`; the last three are terminal.
`ok: true` means the call succeeded, including a read of a failed run. It does
not mean the quality gate passed. Inspect the evaluator's decision under
`evaluation` before approving delivery. Native receipt fields remain in that
object. Pending result reads can have `threshold: null`; a terminal receipt
must report its applied threshold. Treat `runId` as opaque, with no assumed prefix.

## Compatibility aliases

Hosted `run_eval` and `run_evaluation` delegate to `evals_evaluate_media`;
`get_evaluation_result` delegates to `evals_get_evaluation_result`. Their stdio
names are `studio_run_eval`, `studio_run_evaluation`, and
`studio_get_evaluation_result`. They remain deprecated aliases through hosted
1.1.x, with removal scheduled for hosted 2.0.0. Discovery metadata names each
replacement and removal version. Every alias returns the same success envelope
and delegates once; never call both an alias and its replacement for one run.

Legacy submission input differs from canonical input: it requires `projectId`,
`capability`, and `prompt`, plus exactly one `videoUrl` or an `imageUrls` array
with at least two images. Read the alias contract for the supported capability
values. To migrate a video, use the candidate binding above. For comparison
images, use `profile: "image-general"`, first image as candidate, and subsequent
images as references. Supply the canonical threshold explicitly; legacy aliases
default it to 0.8. Poll with the same project and run IDs using the canonical tool.

## Contract ownership

Studio's `app/api/mcp/evaluation-mcp-proxy.ts` owns canonical request validation
and gateway forwarding. `evaluation-response.ts` owns the normalized envelope;
`evaluation-contract.ts` owns compatibility inputs. `get_contract` and
`tools/list` expose these published contracts, including safety and deprecation
metadata. Refresh discovery when changing transport or server version.
