---
name: mixio-eval
description: "Evaluate generated media quality with Mixio Eval — score outputs, compare variants, and enforce quality gates before delivery."
version: 0.1.0
invoke: /mixio:eval
---

# Mixio Eval

Score and evaluate generated media using Mixio's evaluation pipeline. Use as a quality gate before delivering outputs to clients.

## Prerequisites

- Mixio CLI configured (`mixio setup`)
- Eval API available on staging: `https://eval.staging.mixio.pro`

## Workflow

### Score a generation

```
1. generate(model, prompt)           → job_id
2. generation_result(job_id)         → output URLs
3. eval_score(url, criteria)         → quality score 0-100
4. If score >= threshold → deliver
   If score < threshold → regenerate with adjusted prompt
```

### Compare variants

```
1. Generate 3-4 variants with different models/prompts
2. eval_compare(urls, criteria)      → ranked list with scores
3. Pick the highest-scoring variant
```

## MCP Tools

### `eval_score`

Score a single media output.

```json
{
  "tool": "eval_score",
  "arguments": {
    "url": "https://cdn.mixio.pro/media/abc123.mp4",
    "criteria": ["composition", "lighting", "motion_quality"],
    "reference_prompt": "A cinematic wide shot..."
  }
}
```

Returns:
```json
{
  "overall": 82,
  "breakdown": {
    "composition": 85,
    "lighting": 90,
    "motion_quality": 72
  },
  "notes": "Strong composition and lighting. Motion has minor jitter in frames 45-60."
}
```

### `eval_compare`

Compare multiple outputs and rank them.

```json
{
  "tool": "eval_compare",
  "arguments": {
    "urls": ["url1", "url2", "url3"],
    "criteria": ["overall_quality", "prompt_adherence"],
    "reference_prompt": "Original prompt..."
  }
}
```

### `eval_blueprint`

Run a predefined evaluation blueprint (batch scoring with standard criteria).

```json
{
  "tool": "eval_blueprint",
  "arguments": {
    "blueprint": "cinematic-video",
    "url": "https://cdn.mixio.pro/media/abc123.mp4"
  }
}
```

Available blueprints: `cinematic-video`, `product-photo`, `social-content`, `audio-narration`

## Quality Criteria

| Criterion | What it measures |
|-----------|-----------------|
| `composition` | Framing, rule of thirds, visual balance |
| `lighting` | Exposure, color temperature, contrast |
| `motion_quality` | Smoothness, physics, temporal coherence |
| `prompt_adherence` | How well output matches the prompt |
| `technical_quality` | Resolution, artifacts, noise |
| `aesthetic` | Overall visual appeal |
| `audio_clarity` | (audio) Intelligibility, background noise |
| `voice_naturalness` | (TTS) Prosody, pacing, emotion |

## Quality Gates

Set minimum thresholds for automated pipelines:

```
If eval_score < 70 → reject and regenerate
If eval_score 70-85 → flag for human review
If eval_score > 85 → auto-approve
```

## Tips

- Always eval before delivering to clients — saves revision cycles
- Use `eval_compare` with 3+ variants to find the best output
- Blueprints encode industry-standard criteria — start there
- Custom criteria can be combined freely
- Eval costs 0 credits (included in platform)
