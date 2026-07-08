---
name: prompting
description: Instruction guide for formatting and structuring user prompts for visual evaluation runs.
---

# Prompting Guide for Visual Evaluations

When submitting evaluations, structure prompts clearly using `@alias` annotations:

## 1. Referencing Registered Assets
Always use `@` followed by the asset's registered alias.
* **Good:** "Compare Mira's face in the keyframes @frames with the reference model @mira."
* **Bad:** "Compare the keyframe URLs with the character sheet."

## 2. Setting Expectations
Clearly state the capability context in the prompt so the verifier (like Gemini) knows what to look for:
* **Wardrobe check:** "Audit the wardrobe of the character in @video against the styling sheet @ref. Pay attention to jacket color and shirt details."
* **Alignment check:** "Confirm that @scene aligns with the storyboard frames in @storyboard."
