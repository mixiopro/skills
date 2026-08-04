# Model Comparison

Resolution, speed, and cost vary by model and change as Studio adds providers — there's no static table to keep in sync. Get current values from the live catalog instead:

```
studio_list_generation_models({ mediaType: "image" | "video" })
studio_list_generation_models({ useCaseId: "..." })
studio_list_use_cases({ outputType: "IMAGE" | "VIDEO" })
```

## Known model IDs (confirm before use)

| Media | Model IDs |
|-------|-----------|
| Image | `gpt_image_2`, `gemini_image`, `nano_banana_2`, `seedream_5_pro`, `seedream_5_lite` |
| Video | `seedance_image_to_video_pro`, `seedance_text_to_video_pro`, `seedance_image_to_video_v2`, `veo_3_1`, `sora_2`, `kling_text_to_video_2_6_pro` |

## Picking a model

Without hardcoded benchmarks, use `studio_list_use_cases` to match your job to a supported use case first (e.g. `production-generate-video`, `image-edit`, `refine-character-image`), then `studio_list_generation_models({ useCaseId })` to see which models support it. Try 2-3 candidates on a draft prompt before committing to one for a full batch.
