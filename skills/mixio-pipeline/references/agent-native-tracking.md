# Agent-native goal and task tracking

Use this guide for full, multi-step Mixio episode runs. Agent platforms expose different planning and tracking features, so keep the production contract portable and adapt only to the task surfaces available in the current host.

## Choose the lightest tracker

- For a full episode pipeline, use the host’s visible task list or plan when it is available. Track pipeline milestones, not one task per shot.
- Use a persistent native goal only when the user asks the agent to keep pursuing an outcome across turns, or when the host’s documented workflow explicitly makes that goal the way to start. Do not create a persistent goal for a one-off skill call.
- If no native tracker is available, show a compact stage checklist in the conversation. Do not simulate a host feature with guessed commands or tools.
- Check the current host and model’s available features. Availability and persistence can vary by product, model, mode, and configuration.

## Keep a portable completion contract

Keep the native goal/task plan short and phase-based. It should capture:

1. **Objective:** what result the user asked for in this confirmed project and episode.
2. **Milestones:** resolve scope and source; build the local director/specialist plan; audit continuity; show the exact diff; wait for approval; sync and read back; resolve reference readiness; plan production; generate and evaluate only when included and approved.
3. **Constraints:** preserve screenplay text, label inference, do not write a breakdown before approval, and respect separate image-generation and cost gates.
4. **Evidence:** the reviewed plan and diff, explicit user decisions, persisted Studio readback, readiness and cost approvals, and evaluation results as applicable.
5. **Stop and resume conditions:** stop at each required user decision. On resume, re-resolve the scope and read current Studio state before continuing.

Example objective:

> Prepare and sync an approved, continuity-checked shot plan for the confirmed episode. Keep the screenplay unchanged, mark inferred direction, show the exact Studio diff, and stop for approval before writing. After approval, read the persisted changes back. Continue into image generation or paid production only if separately requested and approved.

## The tracker is not the production record or an approval

- Use native goals and task lists for progress visibility and continuation cues, not as the source of truth for screenplay, project, episode, shots, or relations. Studio remains authoritative for persisted production state.
- Keep the detailed, unapproved shot table in the working context. A goal, task checkbox, saved plan, or completed milestone does not approve it or authorize a Studio write.
- An approval gate is satisfied only by the user’s explicit decision. A task list marked complete cannot approve a diff, a rendered sheet, or a credit spend.
- A persistent goal does not grant open-ended authority to continue through approval gates or submit billable jobs.
- If the working context is lost before sync, rebuild the local plan from the current source and Studio graph; never assume an old plan or tracker describes current Studio state.

## Host feature examples

These examples illustrate the adapter idea; check the host’s current documentation and live tool availability rather than hard-coding commands into the production workflow.

| Host | Native surface described by its documentation |
|---|---|
| Codex | Persistent, thread-scoped Goals for defined outcomes that continue across turns. [Codex Goals](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex) |
| Claude Code | Task tools (`TaskCreate`, `TaskGet`, `TaskUpdate`, `TaskList`) for a task list; availability depends on model and configuration. [Claude Code tools reference](https://code.claude.com/docs/en/tools-reference) |
| Google Antigravity | Planning-mode task groups with a top-level goal, subtasks, progress updates, and pending steps. [Antigravity task groups](https://www.antigravity.google/docs/tools/) |
| Cursor | Plan Mode with structured to-dos and dependencies; plans can be edited and saved as Markdown. [Cursor Plan Mode](https://cursor.com/blog/plan-mode) |
| OpenCode | `todowrite` task lists for tracking complex work during a coding session. [OpenCode tools](https://opencode.ai/docs/tools/) |
