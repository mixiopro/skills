---
{
  "id": "ka.serial-arc-progression",
  "type": "knowledge_atom",
  "title": "连续剧弧光推进",
  "kind": "heuristic",
  "summary": "分集或连续容器里，反转、揭示、关系跃迁和升级要按照因果与节奏逐步展开。",
  "mediums": [
    "episodic",
    "short_drama",
    "game_narrative",
    "branching_interactive"
  ],
  "stages": [
    "premise",
    "structure",
    "outline",
    "rewrite"
  ],
  "problem": "连续项目容易在前段集中解释和升级，让后段失去推进空间；也可能长期停留在铺垫，缺少清楚的进展。",
  "decision_rules": [
    "先确定容器参数：集数、单集时长、单元或连续属性、主线数量。",
    "按照人物因果和故事进展安排 reveal、relationship turn、value turn 与 world-rule escalation。",
    "区分本集闭环推进和季级或长线推进，让每集都改变角色处境或故事理解。"
  ],
  "anti_patterns": [
    "前几集集中曝光主要秘密与关系突破，后段只重复放大冲突",
    "大量中段集只维持设定，不推进长线弧光",
    "每集都靠更大的信息轰炸假装升级",
    "没有先确定容器就开始安排重大节点"
  ],
  "prompt_primitives": [
    "本集推进的是当集闭环、季级主线，还是人物长期弧光中的哪一步",
    "这个 reveal 会如何改变人物的选择和后续因果",
    "本集结束时，角色处境或观众理解发生了什么变化"
  ],
  "evaluation_checks": [
    "集数、时长和连续属性是否先于弧光设计被锁定",
    "长线变化是否按照因果逐步展开",
    "本集闭环与系列推进是否彼此支撑"
  ],
  "links": [
    "ka.causality-chain",
    "ka.medium-episode",
    "ka.medium-short-drama"
  ],
  "source_status": "synthesized"
}
---

# 连续剧弧光推进

连续项目需要让主要秘密、关系变化、价值选择和世界规则变化持续推动后续故事。容器长度会影响节奏，但这些节点的安排来自因果：一次揭示改变人物掌握的信息，一次关系变化影响下一次合作，一次选择带来新的代价或责任。

先确定集数、时长和单元或连续属性，再安排关键转折如何逐步改变角色处境。避免开篇过度集中重大揭示，也避免前段长期停留在没有结果的铺垫。
