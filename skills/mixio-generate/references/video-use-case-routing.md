# Video use-case routing

Use the normal catalog use case that matches the requested video operation. This keeps the
model-specific prompt, media slots, parameters, and controls visible to the skill. The tool
contract accepts production context separately from `useCaseId`, so normal use cases can be
submitted as shot-scoped jobs.

## Choose by operation

| Requested operation | Use case | Skill-built input |
|---|---|---|
| One authored multi-cut clip with shared references and cut-by-cut direction | `multi-shot-video` | Serialize every `cuts[]` field into the model prompt and pass supported references in the model's declared slots. |
| Ordinary image-to-video (`SINGLE`, `DUAL_FRAME`, `MASTER_ANCHOR_MULTI_SHOT`) | `cinematic-video` | Choose a model whose schema accepts the planned start/end frames; prepare those frames, references, prompt, and parameters. |
| Prompt-only text-to-video (`T2V`) | `cinematic-video` | Choose a T2V model whose schema does not require an image slot; pass a delivery `aspect_ratio` only when its schema exposes it. |
| Copy camera movement from a motion-reference clip | `camera-motion` | Supply the source motion video and optional frame anchors in the chosen model's declared slots. |
| Transfer body or character movement from a source clip onto a still/reference | `motion-transfer` | Supply the target image and motion source in the declared slots. |
| Synchronize a supplied voice/audio track to an image or video, including dubbing/lip-sync | `lip-sync` | Supply the visual source and audio track; preserve the requested language and spoken performance. |
| Restyle or edit an existing video while retaining its source motion | `video-edit` | Supply the source clip and explicit edit/restyle direction. |
| Presenter-led digital human or avatar video | `avatar-video` | Supply the presenter/avatar controls and script supported by the selected model. |

If a requested operation does not fit these cases, inspect
`studio_list_use_cases({ outputType: "VIDEO" })` and select from its live results. Do not
invent a use-case ID or replace a task-specific use case with a compound production workflow.

## Match the exact model contract

1. Read the user's model choice and `settings.generation.defaultModelByUseCase[useCaseId]`.
   Treat pins and explicit choices as preferences only when the model supports both the selected
   use case and the shot's media shape. For example, do not use an I2V model requiring `primary`
   for prompt-only T2V.
2. Read `studio_get_use_case_input_schema({ useCaseId, modelId })` for that exact pair. If no
   model is pinned, read the live use-case catalog and choose a supported model before reading
   its schema.
3. Confirm the schema accepts every required input: duration, aspect ratio when exposed,
   resolution, start and end frames, character/location/prop references, video or motion
   references, and audio. If the schema has no `aspect_ratio` parameter, check the model's
   framing behavior and whether the supplied media can meet the delivery ratio; the project
   default cannot create a missing control. A reference in `selectedElements` or prose does not
   substitute for a media slot the model does not accept. Choose another supported model/use case
   or stop for a decision if a required control cannot be represented.
4. Pass every setting through `input.parameters` only when the exact schema declares it. Read
   `schemaWarnings`; any warning about omitted media or parameters blocks polling or claiming a
   valid submission.

The live catalog currently lists `hailuo_v3_reference_to_video` first for `multi-shot-video`
and `hailuo-v3-image-to-video` first for `cinematic-video`. Treat that order as a starting
point, not a replacement for the project's per-use-case pin, the model schema, or the shot's
reference needs. For `MULTI_CUT` duration routing and fallbacks, see
[`mixio-shot-planning` model matching](../../mixio-shot-planning/references/model-matching.md#multi-cut-routing).

## Submit with explicit production context

Use the regular use case ID and pass the production scope in the separate `context` envelope.
For a shot output, the request includes the deepest known IDs and asks Studio to materialize
the result as a scoped asset:

```javascript
await studio_submit_studio_job({
  jobType: "video",
  model: "hailuo_v3_reference_to_video",
  useCaseId: "multi-shot-video",
  prompt: compiledPrompt,
  input: {
    media: {
      image_urls: approvedImageReferences,
      video_urls: approvedVideoReferences,
      audio_urls: approvedAudioReferences
    },
    parameters: {
      duration: String(shot.duration),
      aspect_ratio: deliveryAspectRatio,
      resolution: selectedResolution
    }
  },
  context: {
    projectId,
    episodeId,
    sceneId,
    shotId,
    outputPolicy: "scoped_asset",
    contextSelectionMode: "curated"
  },
  selectedElements: approvedReferencedElements,
  slotReferences: approvedSlotReferences,
  slotTags,
  mentionMap,
  promptEnhancementMode: "off"
})
```

This is a shape example, not a universal schema: include only media slots and parameters
accepted by the selected model's live schema. For example, the live H3 Ref2Vid schema on
`multi-shot-video` accepts `image_urls`, `video_urls`, and `audio_urls`, and exposes a string
duration selection from 5 through 15 seconds. Never copy those slots or values to a different
model without checking its schema.

The skill owns the effective prompt. Set `promptEnhancementMode: "off"` after composing it so
Studio does not silently rewrite authored cut, camera, dialogue, or reference direction. Use
`contextSelectionMode: "curated"` with only the selected graph elements and explicit media;
do not rely on automatic scene context to add missing references.

Whenever media is present, keep all three representations aligned:

- `input.media`: schema-valid URLs in the exact model slots;
- `slotTags` and `mentionMap`: one-to-one reference-identity/tag/label pairs (not slot/index keys);
- `prompt`: each exact `@tag` appears where the referenced subject or asset acts.

Use the reference identity key, not the `input.media` slot/index, for `slotTags`; the
[Prompt & Mention Sheet](prompt-mention-sheet.md) shows the pairing format.

Read the selected character look and location configuration/view before building these inputs.
Pass the approved variant on the media reference or select the matching graph entity so Studio
can resolve the correct look. Do not attach a reference merely because it exists in the project.

## Verify the resulting graph association

`context.outputPolicy: "scoped_asset"` asks Studio to create or update an output asset in the
submitted context. After the job completes, read the output element and query the target shot's
elements/relations. Confirm the generated asset is associated with the exact `shotId` before
reporting that the job is attached. Job status alone does not prove graph placement.

If the result element exists but lacks its `generated_for` relation, create or upsert the
project-scoped relation with the generated video as `fromId` and the shot as `toId`, then read it
back. A live Mixio CLI relation query confirmed the `VIDEO → SHOT` orientation for
`generated_for`. Do not use `tag_element` or a JSON `shotId` tag as a substitute for a graph
relation. If Studio does not expose a resolvable output element or relation, stop and report the
association as unverified; do not claim it landed under the shot.

The video generation path in these production skills does not submit `production-generate-video`.
That compound use case owns context gathering and hides controls the skills need to prepare,
inspect, and pass explicitly.
