---
name: evals-guide
description: Instruction guide on how to prepare assets, select execution parameters, trigger evaluations, and parse reports.
---

# Visual Evaluation Execution Guide

Use this flow to execute evaluations:

## Phase 1: Asset Preparation
1. Ensure files are uploaded to the file service.
2. Call `register_asset` to assign stable `@aliases` for the files within the project.

## Phase 2: Parameter Selection
* **Default Algorithm:** Always use `gemini_review`. Keep it set to this default unless a specific capability or check requires a DINOv2 or other fast-embedding check.
* **Default Threshold:** Use `0.80` unless the user requires high strictness (use `0.85+`) or allows variance (use `0.70`).

## Phase 3: Trigger & Poll
1. Call `run_evaluation` with `background: true`.
2. Retrieve the `id` (e.g. `resp_123`).
3. Call `get_evaluation_result` periodically until `status` is `completed`.
4. Synthesize the findings and explain the scores and overlay paths clearly to the user.
