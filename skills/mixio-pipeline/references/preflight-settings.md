# Preflight settings write

Use this at Step 00 after reading the current project settings. When no model has been pinned,
default images to `gemini_image` and ordinary video to H3 I2V (`hailuo-v3-image-to-video`). The
production input-aware selector uses H3 Ref2Vid (`hailuo_v3_reference_to_video`) for ordered
keyframes and compatible reference-to-video routes, and H3 T2V for prompt-only video. Existing
project settings and explicit model selections take precedence. `updates.settings` replaces the
complete settings object, so merge from a fresh project read and read the result back. The episode
frame contract is separate from project settings.

```javascript
const { settings = {} } = await studio_get_project({ projectId })
const projectImageModel =
  settings.generation?.defaultModelByUseCase?.["production-generate-shot-keyframes"]
const projectVideoModel =
  settings.generation?.defaultModelByUseCase?.["production-generate-video"] ??
  settings.studio?.preferredVideoModel

const confirmed = {
  imageModel: userConfirmed.imageModel ?? projectImageModel ?? "gemini_image",
  videoModel:
    userConfirmed.videoModel ?? projectVideoModel ?? "hailuo-v3-image-to-video",
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
const videoSchema = await studio_get_use_case_input_schema({
  useCaseId: "production-generate-video",
  modelId: confirmed.videoModel
})
const videoHasResolution = Boolean(
  videoSchema?.properties?.parameters?.properties?.resolution
)
const existingVideoParameters =
  settings.generation?.defaultParametersByUseCase?.["production-generate-video"]

await studio_update_project({ projectId, updates: { settings: {
  ...settings,
  generation: {
    ...settings.generation,
    defaultModelByUseCase: {
      ...settings.generation?.defaultModelByUseCase,
      "production-generate-shot-keyframes": confirmed.imageModel,
      "production-generate-video": confirmed.videoModel
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
      "production-generate-video": {
        ...existingVideoParameters,
        ...(videoHasResolution ? { resolution: confirmed.videoResolution } : {})
      }
    }
  },
  studio: {
    ...settings.studio,
    preferredVideoModel: confirmed.videoModel,
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

await studio_update_episode({ projectId, episodeId, updates: { metadata: { pipeline: {
  aspect_ratio: confirmed.deliveryAspectRatio,
  anchor_aspect_ratio: confirmed.anchorAspectRatio,
  shot_contract: { mode: confirmed.shotLengthMode, band: confirmed.shotLengthBand },
  step_00: "complete"
}}}})

const resolved = await studio_get_project({ projectId })
```

`defaultAspectRatioByOutputType` is keyed by output type (`IMAGE`, `VIDEO`) and
`defaultModelByUseCase` by use case ID. In live projects, image resolution belongs in
`defaultResolutionByOutputType.IMAGE`; video resolution belongs in
`defaultParametersByUseCase[useCaseId].resolution` only when that model exposes the parameter.
The global `IMAGE`
default remains the delivery ratio. Submit every anchor job with its explicit
`anchor_aspect_ratio`; an anchor is local work, not a project-wide image preference.

`studio.videoDurationSeconds` is an open string (no enum) — write the confirmed band verbatim
(`"10-15"` or `"2.5-4.5"`). Do not invent values for `studio.defaultVideoShotMode`: the known
Studio biases are `single-shot` / `multi-keyframe` / `grid`, so only the `panel` mode writes it.
The multi-cut mode lives in the episode's `metadata.pipeline.shot_contract`. A band containing
13–15s must be routed through the `multi-shot-video` use case at Step 05/06:
`production-generate-video`'s H3 duration enum tops out at 12 seconds.