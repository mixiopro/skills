# Preflight settings write

Use this at Step 00 after resolving the project and episode and reading their current state.
Lock video model defaults by **normal use-case ID**. For the current catalog, the starting
defaults are H3 I2V (`hailuo-v3-image-to-video`) for image-backed `cinematic-video` and H3
Ref2Vid (`hailuo_v3_reference_to_video`) for `multi-shot-video`; honor supported project pins
and explicit user choices when their input shape fits. Prompt-only `T2V` also uses
`cinematic-video`, but needs a text-to-video model from that use case rather than an I2V model
that requires `primary`. These are separate model routes and must not share one generic
`preferredVideoModel` value.

Before writing settings:

1. Read `studio_list_use_cases({ outputType: "VIDEO" })`.
2. Read `studio_get_use_case_input_schema({ useCaseId, modelId })` for each selected
   `(useCaseId, modelId)` pair.
3. For each selected model, pass the locked delivery ratio only if its schema exposes
   `aspect_ratio`. If it does not, confirm the model's framing behavior and ensure the chosen
   input media can meet the delivery ratio; the project-level `VIDEO` default does not add a
   missing model control. Apply the same schema check to project-level resolution. A shot's
   authored duration remains an explicit per-job parameter; do not replace it with a generic
   project default.
4. Check existing `defaultParametersByUseCase` values against the selected model's schema. If a
   prior value is unsupported, surface it and resolve it before changing or dropping it; do not
   carry a production-use-case parameter into a normal use case by key similarity alone.

`updates.settings` replaces the complete settings object, so merge from a fresh project read and
read the result back. The episode frame contract is separate from project settings.

```javascript
const { settings = {} } = await studio_get_project({ projectId })
const currentModelPins = settings.generation?.defaultModelByUseCase ?? {}

const videoModelsByUseCase = {
  "cinematic-video":
    userConfirmed.videoModelsByUseCase?.["cinematic-video"] ??
    currentModelPins["cinematic-video"] ??
    "hailuo-v3-image-to-video",
  "multi-shot-video":
    userConfirmed.videoModelsByUseCase?.["multi-shot-video"] ??
    currentModelPins["multi-shot-video"] ??
    "hailuo_v3_reference_to_video"
}

const imageModel =
  userConfirmed.imageModel ??
  currentModelPins["production-generate-shot-keyframes"] ??
  "gemini_image"

const schemasByUseCase = {}
for (const [useCaseId, modelId] of Object.entries(videoModelsByUseCase)) {
  schemasByUseCase[useCaseId] = await studio_get_use_case_input_schema({
    useCaseId,
    modelId
  })
}

// Stop before the write if the selected schemas do not accept the confirmed controls,
// or if a pre-existing per-use-case parameter is incompatible with its new model.
const videoParametersByUseCase = {}
for (const useCaseId of Object.keys(videoModelsByUseCase)) {
  const prior = settings.generation?.defaultParametersByUseCase?.[useCaseId] ?? {}
  const schemaParameters =
    schemasByUseCase[useCaseId]?.properties?.parameters?.properties ?? {}
  const incompatible = Object.keys(prior).filter(key => !schemaParameters[key])
  if (incompatible.length) {
    throw new Error(`Resolve incompatible ${useCaseId} defaults before writing: ${incompatible}`)
  }
  videoParametersByUseCase[useCaseId] = {
    ...prior,
    ...(schemaParameters.resolution && userConfirmed.videoResolution !== undefined
      ? { resolution: userConfirmed.videoResolution }
      : {})
  }
}

const confirmed = {
  deliveryAspectRatio: userConfirmed.deliveryAspectRatio,
  anchorAspectRatio: userConfirmed.anchorAspectRatio,
  imageResolution: userConfirmed.imageResolution,
  videoResolution: userConfirmed.videoResolution,
  visualStyle: userConfirmed.visualStyle,
  toneAndMood: userConfirmed.toneAndMood,
  cinematographyDirection: userConfirmed.cinematographyDirection,
  defaultStylePrompt: userConfirmed.defaultStylePrompt,
  shotLengthMode: userConfirmed.shotLengthMode ?? "multi_cut",
  shotLengthBand: userConfirmed.shotLengthBand ?? "10-15",
  references: userConfirmed.references
}

await studio_update_project({ projectId, updates: { settings: {
  ...settings,
  generation: {
    ...settings.generation,
    defaultModelByUseCase: {
      ...currentModelPins,
      "production-generate-shot-keyframes": imageModel,
      ...videoModelsByUseCase
    },
    defaultAspectRatioByOutputType: {
      ...settings.generation?.defaultAspectRatioByOutputType,
      IMAGE: confirmed.deliveryAspectRatio,
      VIDEO: confirmed.deliveryAspectRatio
    },
    defaultResolutionByOutputType: {
      ...settings.generation?.defaultResolutionByOutputType,
      IMAGE: confirmed.imageResolution
    },
    defaultParametersByUseCase: {
      ...settings.generation?.defaultParametersByUseCase,
      ...videoParametersByUseCase
    }
  },
  studio: {
    ...settings.studio,
    videoDurationSeconds: confirmed.shotLengthBand,
    ...(confirmed.shotLengthMode === "panel"
      ? { defaultVideoShotMode: "single-shot" }
      : {}),
    visualStyle: confirmed.visualStyle,
    toneAndMood: confirmed.toneAndMood,
    cinematographyDirection: confirmed.cinematographyDirection,
    defaultStylePrompt: confirmed.defaultStylePrompt
  },
  references: { ...settings.references, ...confirmed.references }
}}})

const episode = await studio_get_episode({ projectId, episodeId })
const existingPipeline = episode.metadata?.pipeline ?? {}
await studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  ...existingPipeline,
  aspect_ratio: confirmed.deliveryAspectRatio,
  anchor_aspect_ratio: confirmed.anchorAspectRatio,
  shot_contract: { mode: confirmed.shotLengthMode, band: confirmed.shotLengthBand },
  step_00: "complete"
}}}})

const resolvedSettings = await studio_get_project({ projectId })
const resolvedEpisode = await studio_get_episode({ projectId, episodeId })
```

`defaultModelByUseCase` holds distinct pins for `cinematic-video` and `multi-shot-video`.
Leave any existing `settings.studio.preferredVideoModel` untouched; the skill-managed video
route does not read it to choose a model. Likewise, an existing compound-video model pin is not
copied into the normal use-case entries.

`defaultAspectRatioByOutputType` is keyed by output type (`IMAGE`, `VIDEO`). Video resolution
belongs in `defaultParametersByUseCase[useCaseId].resolution` only when that selected model's
schema exposes the parameter. `studio.videoDurationSeconds` is an open string used for the shot
length band (`"10-15"` or `"2.5-4.5"`); Step 05/06 passes each authored shot's exact duration
through the selected model's schema. Do not invent values for
`studio.defaultVideoShotMode`: the known biases are `single-shot`, `multi-keyframe`, and `grid`;
the multi-cut mode lives in episode `metadata.pipeline.shot_contract`.

The output-type aspect ratio is a project default, not proof that every model can accept or
enforce it. For example, the live `cinematic-video` schema for `hailuo-v3-image-to-video` has a
required `primary` image and optional `endFrame`, but no `aspect_ratio` parameter. The live
`hailuo-v3-text-to-video` schema has no required media and exposes `aspect_ratio`. Do not send an
unsupported ratio field or use an I2V pin for a prompt-only shot; confirm that the selected
model and its inputs satisfy the locked delivery ratio, or select a compatible model/use case
before Step 06.
