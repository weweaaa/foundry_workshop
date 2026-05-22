---
mode: agent
description: 生成 agent.yaml + agent.manifest.yaml 用于 Foundry hosted agent 部署
---

参考 `#file:src/research_agent/agent.yaml` 与 `#file:src/research_agent/agent.manifest.yaml`，
为 `#file:src/${input:agentDir}/main.py` 生成对应的 agent.yaml 与 agent.manifest.yaml：

agent.yaml 要求：
- kind: hosted
- name: ${input:agentDeployName}     # 末尾加 -${STUDENT_SUFFIX}
- host: azure.ai.agent
- language: docker，docker.remoteBuild: true
- resources: cpu 1 / memory 2Gi，scale 1-3
- env 注入: AZURE_AI_PROJECT_ENDPOINT / AZURE_AI_MODEL_DEPLOYMENT_NAME / AGENT_NAME / STUDENT_SUFFIX

agent.manifest.yaml 要求：
- name 同上
- instructions.file 指向 `../../personas/${input:agentDeployName}.md`
- model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}
- tools: code_interpreter；若学员需要 Foundry Bing grounding，注释里给出取消注释的位置

完成后执行：
```
azd deploy ${input:agentDeployName}
..\scripts\invoke-hosted.ps1 -AgentName ${input:agentDeployName} -Prompt "ping"
```
