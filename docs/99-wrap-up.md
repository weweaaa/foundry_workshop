# Wrap-up · 总结 + 下一步(10 min)

## 5.1 一句话总结

- **Soul / Skills / Tools** 是 agent harness 的 DNA(`personas/` / `skills/` / `tools/`)。
- 学员从来不 provision 任何 Azure 资源;**`azd deploy <agent>`** 把代码推到讲师下发的共享 Foundry project。
- **Foundry agents 数据平面 API** 是不依赖 portal / App Insights 的本地观测入口。
- **GitHub Copilot + skill 生态**是把概念变代码的力放大器:
  - VS Code 的 `/persona` `/skill` `/tool` `/deploy` 四个斜杠命令(工作坊私有)
  - `.agents/skills/microsoft-foundry` / `agent-framework-azure-ai-py` / `azure-ai-projects-py`(微软官方,按关键词自动激活)

## 5.2 你今天搭出来的东西

```
你
 ↓
[本地 agentdev run 调试]
 ↓ azd deploy
[Foundry Hosted Agent: research-agent-stuNN]
 ↓ thread/run/step 自动落 Foundry 内部
[fetch-traces.ps1 + 本地 HTML]
 ↓
你的运维入口(不需要 Azure Portal)
```

## 5.3 学习路径

### 评估闭环

把 trace 转成评估数据集 → 跑 batch eval → 比较版本 → `prompt_optimize` → redeploy。

完整流程在 `.agents/skills/microsoft-foundry/foundry-agent/`:

- `eval-datasets/` — 数据集类型(seed / traces / curated / prod)、版本化、回归检测
- `observe/` — 持续 eval、analyze-results、compare-iterate、cicd-monitoring
- `faos-optimize/` — Prompt Optimizer 工作流

### 多 agent 编排

把工作坊学到的"一个 agent"延展到多个:

- `workflow.yaml`(声明式,推荐做主路由)
- `WorkflowBuilder`(代码式,复杂控制流)
- `connected_agents`(最简 demo)

### 自建 MCP server

把内部能力包成 MCP,在 `agent.manifest.yaml` 里 `type: mcp` 引用:

- Container Apps 模板:[`Azure-Samples/mcp-container-ts`](https://github.com/Azure-Samples/mcp-container-ts)
- Functions 模板:[`Azure-Samples/mcp-sdk-functions-hosting-python`](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python)
- skill 设计指南:`.agents/skills/skill-creator/SKILL.md`

### CI/CD 接入

- `.github/workflows/agent-eval.yml`:PR 门禁跑 P0 smoke
- `.github/workflows/agent-eval-scheduled.yml`:nightly trace harvest + 回归

详细模板可问 Copilot:`@workspace 参考 #file:.agents/skills/microsoft-foundry/foundry-agent/observe/references/cicd-monitoring.md,给 research-agent 写一份 PR 门禁 workflow`。

## 5.4 资源清理

讲师在工作坊结束 7 天后会统一清理学员 SP。你也可以主动放手:

```powershell
# 删掉自己的 hosted agent(共享 project 上的 agent 实例)
azd ai agent delete research-agent-${STUDENT_SUFFIX}
# 或者用 az CLI 直接调 Foundry data plane
```

> 共享 Foundry account / project / 模型 / ACR **不要**删!那是全员共享的。

## 5.5 反馈

请扫码 / 点链接填反馈表(讲师现场提供 URL),3 分钟完成。
你的吐槽与建议会直接进下一期工作坊的改进列表。

## 5.6 相关链接

- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Hosted Agents](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [`azd ai agent` 扩展](https://aka.ms/azdaiagent/docs)
- [Foundry Samples (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [GitHub Copilot in VS Code](https://code.visualstudio.com/docs/copilot/overview)
- [GitHub Copilot CLI](https://docs.github.com/copilot/github-copilot-in-the-cli)

## 5.7 进一步阅读

仓库 `backup/` 目录里有三份设计文档:

- `azd-foundry-research.md` — Phase 1:azd 创建 Foundry 资源的细节(讲师在另一仓库中处理)
- `agent-harness-architecture.md` — Phase 2:harness 四层架构
- `agent-observability-evaluation.md` — Phase 3:可观测性 + 评估

下一期再见 👋
