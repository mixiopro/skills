# Preflight settings write

Use this at Step 00 after the user confirms the six settings choices. `updates.settings` replaces
the complete settings object, so merge from a fresh project read and read the result back. The
episode frame contract is separate from project settings.

```javascript
const { settings = {} } = await studio_get_project({ projectId })

const confirmed = {
  imageModel: userConfirmed.imageModel,
  videoModel: userConfirmed.videoModel,
  deliveryAspectRatio: userConfirmed.deliveryAspectRatio,
  anchorAspectRatio: userConfirmed.anchorAspectRatio,
  imageResolution: userConfirmed.imageResolution,
  videoResolution: userConfirmed.videoResolution,
  visualStyle: userConfirmed.visualStyle,
  toneAndMood: userConfirmed.toneAndMood,
  cinematographyDirection: userConfirmed.cinematographyDirection,
  defaultStylePrompt: userConfirmed.defaultStylePrompt,
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
    visualStyle: confirmed.visualStyle,
    toneAndMood: confirmed.toneAndMood,
    cinematographyDirection: confirmed.cinematographyDirection,
    defaultStylePrompt: confirmed.defaultStylePrompt
  },
  references: { ...settings.references, ...confirmed.references }
}}})

await studio_update_episode({ episodeId, updates: { metadata: { pipeline: {
  aspect_ratio: confirmed.deliveryAspectRatio,
  anchor_aspect_ratio: confirmed.anchorAspectRatio,
  step_00: "complete"
}}}})

const resolved = await studio_get_project({ projectId })
```

`defaultAspectRatioByOutputType` is keyed by output type (`IMAGE`, `VIDEO`) and
`defaultModelByUseCase` by use case ID. In live projects, image resolution belongs in
`defaultResolutionByOutputType.IMAGE`; video resolution belongs in
`defaultParametersByUseCase[useCaseId].resolution` only when that model exposes the parameter.
The global `IMAGE` default remains the delivery ratio. Submit every anchor job with its explicit
`anchor_aspect_ratio`; an anchor is local work, not a project-wide image preference.
