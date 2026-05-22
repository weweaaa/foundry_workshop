---
name: market-research
description: 市场/竞品研究的标准 4 步流程：拆解问题 → 多源检索 → 摘要抽取 → 结构化报告。
triggers:
  - 用户提到"调研 / 分析 / 对比 / 市场 / 竞品 / 玩家 / 份额"
  - 用户给出产品名 / 品类名 / 公司名要做"画像"
  - 复合问题需要外部数据支撑
scripts: []
---

# Market Research 流程

## 1. 拆解子问题（不调用任何工具）

把用户问题拆成 3-7 个互不重叠的子问题。常用模板：

| 维度 | 子问题示例 |
|------|----------|
| 定义 | 这个品类包含什么 / 排除什么？ |
| 玩家 | 头部 3-5 家是谁？份额怎样？ |
| 产品 | 功能对比矩阵（按用户视角）？ |
| 商业 | 商业模式 / 定价 / 主要市场？ |
| 增长 | 近 2 年的增长信号 / 公开数字？ |
| 风险 | 政策 / 技术 / 替代品 / 法务 |

把子问题与计划用的工具一起返回给用户，再开始执行。

## 2. 多源检索（`web_search` + `web_fetch`）

对每个子问题：

1. 用 `web_search` 给 1-3 个不同关键词（中英文皆可）。
2. 从结果里选 2-3 个来源（域名不同优先），用 `web_fetch` 拉正文。
3. 每个来源记一条 `sources[]`：`{title, url, publishedAt, accessedAt}`。

**禁止**仅依赖单一来源（例如只用维基百科）做关键数字结论。

## 3. 整合与去重

把抓到的事实做 dedup：

- 同一个数字多源一致 → 标为 `confidence=high`
- 数字有冲突 → 都保留并在 `caveats` 注明差异
- 单源数字 → `confidence=low`，并在 `caveats` 写"仅 1 个来源"

## 4. 调用 `report_builder` 生成最终输出

`report_builder` 接受 sections + sources，返回符合 persona 输出契约的 JSON：

```text
report_builder(
  topic="...",
  subQuestions=[...],
  sections=[
    {"title": "市场玩家", "body": "...(¹)(²)", "citations": [1, 2]},
    ...
  ],
  sources=[...],
  confidence="medium",
  caveats=["IDC 与 Statista 在 2024 份额上有 5% 差异"]
)
```

工具会做最后的 schema 校验；不通过则抛错让你修补。

## 边界

- 找不到可靠来源 → 子问题标 "数据缺失" 并写到 `caveats`，不要编造数字。
- 用户问"是否值得投资"：触发 `personas/shared/guardrails.md` 的"不做投资建议"规则。

## 引用编号规则

引文必须按出现顺序编号（`(¹)`、`(²)`、`(³)` …），与 `sources[].id` 严格对应。同一 source 可被多次引用同一个编号。
