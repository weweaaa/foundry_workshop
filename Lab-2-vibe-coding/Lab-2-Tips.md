# Lab 2 — 部署排障笔记 & 最佳实践

> 一次把 `azd deploy research-agent` 从「报错」推到「agent 正常回话」的完整记录。
> 按报错出现的顺序排列；每个问题都给了**根因**、**修复**和**诊断方法**。

---

## TL;DR — 5 个连环坑

| # | 报错现象 | 真正根因 | 修复 |
|---|----------|----------|------|
| 1 | `AzureDeveloperCLICredential: signal: killed` | 扩展 `azure.ai.agents` 0.1.34 与 azd 1.25.1 **不兼容**，退回到 spawn `azd auth token` 子进程，被 SDK 的 10s 超时 `SIGKILL` | azd 升 **1.25.4** + 扩展升 **0.1.37**（走 gRPC 进程内取凭据） |
| 2 | pip `ResolutionImpossible` / 远程构建超时 | `requirements.txt` 用 `opentelemetry-*>=1.25.0` 松下界 + `--pre`，抓到 1.42.1，与传递依赖硬钉的 `==1.40 / ==0.61b0` 冲突 | otel 全家**精确钉到 `1.40.0 / 0.61b0`** |
| 3 | `FOUNDRY_PROJECT_ENDPOINT is required` | 新扩展把变量**改名**（旧 `AZURE_AI_PROJECT_ENDPOINT` → 新 `FOUNDRY_PROJECT_ENDPOINT`） | `azd env set FOUNDRY_PROJECT_ENDPOINT/ID` |
| 4 | postdeploy hook `AZURE_TENANT_ID is not set` | SP 凭据只在仓库根 `.env`，不在 azd 环境里 | `azd env set AZURE_TENANT_ID <guid>`（公开 GUID，非密钥） |
| 5 | 运行时 `server_error` / `storage_error`；日志里 `404 DeploymentNotFound` | 模型 `gpt-5.5` **在 Foundry 项目里不存在** | 改成真实存在的 **`gpt-5.4-mini`** |

外加一个 UI 专属坑（见下文「Chat UI」）和一个非致命的可观测性 403。

---

## 详细记录

### 坑 1 — `signal: killed`（凭据子进程被杀）

**现象**
```
ERROR: publishing service research-agent: ... get_foundry_project:
AzureDeveloperCLICredential: signal: killed
```

**根因**
- `azd extension list` 显示 `azure.ai.agents 0.1.34-preview ⚠ Incompatible`
- 不兼容导致扩展不走「向父 azd 进程 gRPC 要 token」的快路径，而是退回 spawn 一个 `azd auth token` 子进程
- Azure Go SDK 的 `AzureDeveloperCLICredential` 给该子进程**硬编码 10s 超时**；国内到 `login.microsoftonline.com` 每次取 token 往返 1–2s、串行多次，叠加破 10s → `SIGKILL` → `signal: killed`
- 关键时间戳证据：handler 开始到报错**正好 10.0s**

**修复**
```bash
# azd 升级（brew 装失败时见下方"网络受限"小节，可手动放二进制）
azd version          # 目标 >= 1.25.2，本次用 1.25.4
azd extension upgrade azure.ai.agents   # → 0.1.37-preview
azd extension list --installed          # 确认不再 Incompatible
```

**诊断技巧**：`azd deploy --debug 2>&1 | grep -iE "credential|killed|grpc|extension"`，看扩展 handler 的起止时间戳是否卡 10s 整。

---

### 坑 2 — pip 依赖回溯 / `ResolutionImpossible`

**现象**：远程构建里 `pip install --pre` 把几十个 `opentelemetry-*` 版本挨个下载（`This is taking longer than usual... backtracking`），最终 `ResolutionImpossible: Cannot install line 6 and line 8`。

**根因**：传递链 `agent-framework-foundry-hosting → azure-ai-agentserver-core → microsoft-opentelemetry` **硬钉死**了 otel：
```
opentelemetry-api == 1.40
opentelemetry-sdk == 1.40
opentelemetry-exporter-otlp-proto-http == 1.40
opentelemetry-instrumentation(-httpx) == 0.61b0
azure-monitor-opentelemetry-exporter ~= 1.0.0b52   # 同样要 1.40
```
而 `requirements.txt` 写 `>=1.25.0` + `--pre`，pip 先抓最新 1.42.1（要 `semantic-conventions==0.63b1`），与上面的 `==0.61b0` 打架，一路回溯到无解。

**修复**（[src/research_agent/requirements.txt](src/research_agent/requirements.txt)）：
```diff
- httpx>=0.27.0
- opentelemetry-api>=1.25.0
- opentelemetry-sdk>=1.25.0
- opentelemetry-exporter-otlp>=1.25.0
- opentelemetry-instrumentation-httpx>=0.46b0
+ httpx>=0.27.0,<1.0
+ opentelemetry-api==1.40.0
+ opentelemetry-sdk==1.40.0
+ opentelemetry-exporter-otlp==1.40.0
+ opentelemetry-instrumentation-httpx==0.61b0
```
`sdk==1.40.0` 与 `instrumentation-httpx==0.61b0` **都依赖 `semantic-conventions==0.61b0`**，一致 → 搜索空间塌缩，pip 一步到位。

**诊断技巧**：先查约束包到底要哪个版本，别瞎猜：
```bash
curl -s https://pypi.org/pypi/microsoft-opentelemetry/json \
  | python3 -c "import sys,json;print('\n'.join(r for r in json.load(sys.stdin)['info']['requires_dist'] if 'opentelemetry' in r.lower()))"
```

---

### 坑 3 — `FOUNDRY_PROJECT_ENDPOINT is required`

**根因**：扩展 0.1.37 把部署目标解析所需的变量改名了（旧 `AZURE_AI_PROJECT_*` → 新 `FOUNDRY_PROJECT_*`）。

**修复**：
```bash
azd env set FOUNDRY_PROJECT_ENDPOINT "$(azd env get-value AZURE_AI_PROJECT_ENDPOINT)"
azd env set FOUNDRY_PROJECT_ID       "$(azd env get-value AZURE_AI_PROJECT_ID)"
```

---

### 坑 4 — postdeploy hook 缺 `AZURE_TENANT_ID`

**现象**：agent 实际已 `Done`，但末尾 `failed invoking event handlers for 'postdeploy', AZURE_TENANT_ID is not set` 让整个 `azd deploy` 退出码变 1。

**根因**：SP 凭据（tenant/client/secret）只放在仓库根 `.env`，没进 azd 环境；azd 的 hook 层要求 `AZURE_TENANT_ID` 在 azd env 里。

**修复**（让以后 `azd deploy` 一把过）：
```bash
azd env set AZURE_TENANT_ID <tenant-guid>   # 公开 GUID，非密钥，可安全入 azd env
```
**临时补救**（当次直接补授权，脚本自带从根 `.env` 兜底，幂等）：
```bash
pwsh -NoProfile -File hooks/postdeploy-grant-roles.ps1
```

> 该脚本给 agent 的两个 per-version 托管身份授 `AcrPull`（拉镜像）+ `Azure AI User`（容器内调模型），缺了容器起不来/调不动模型。

---

### 坑 5 — 运行时 `404 DeploymentNotFound`（最隐蔽）

**现象**：部署成功，但 invoke 返回 `server_error`（CLI）/ `storage_error`（UI），`output: []`、`model: ""`。

**根因（容器日志坐实）**：
```
POST .../openai/v1/responses → HTTP 404
openai.NotFoundError: code 'DeploymentNotFound'
agent_framework.exceptions.ChatClientException: FoundryChatClient ... 404
```
`AZURE_AI_MODEL_DEPLOYMENT_NAME="gpt-5.5"`，但项目里**没有 gpt-5.5**。可用部署：
```bash
az cognitiveservices account deployment list \
  --name itd-foundry --resource-group foundry-workshop -o table
# → Kimi-K2.6 / gpt-chat-latest / gpt-5.4-mini / text-embedding-3-small / DeepSeek-V4-Pro
```

**修复**：
```bash
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME gpt-5.4-mini
# 根 .env 同步：sed -i '' 's/^AZURE_AI_MODEL_DEPLOYMENT_NAME=.*/...=gpt-5.4-mini/' ../.env
azd deploy research-agent      # 重新注册容器环境变量
```

**诊断技巧 — 拉 hosted agent 容器日志**（排运行时问题的杀手锏）：
```bash
azd ai agent invoke "ping" --new-session        # 拿到 session id
azd ai agent monitor --session-id <id> --tail 120
```

---

### Chat UI 专属坑 — localStorage 旧配置 + 命名错位

**两个叠加问题**：
1. **命名错位**：azd 按 `azure.yaml` 的服务名部署出 agent `research-agent`；但所有测试脚本（invoke-hosted / chat-hosted UI / sanity-check / fetch-traces / grant-roles）默认解析成 `research-agent-$STUDENT_SUFFIX` = `research-agent-stu001`（另一个旧 agent）。
   - **修复**：根 `.env` 加一行 `AGENT_NAME=research-agent`（所有脚本都优先读它，一改全对齐）。
2. **UI 读旧缓存**：`index.html` 的配置只在**带 `#cfg=` 片段加载**时才覆盖 localStorage；直接双击打开文件（无 hash）就一直读 localStorage 里的旧 `stu001`。macOS `open` 又会聚焦已开的旧标签页、不真正加载新 URL。
   - **修复**：页面点 `⚙ 高级` → 把 **Agent name** 改成 `research-agent` → 点输入框外（blur 自动存 localStorage，badge 立刻更新）。

---

## 网络受限环境（国内）专项 tips

- **brew 装 azd 失败**（`Failed to download ruby from ghcr.io` / `curl (18) partial file`）：从 GitHub Releases 下 `azd-darwin-*.zip`，解压后把二进制放到 PATH 里**排在 brew 前面**的目录即可，零破坏、不动 brew：
  ```bash
  # ~/bin 或 ~/.local/bin 通常已在 PATH 且优先于 /opt/homebrew/bin
  cp azd-darwin-amd64 ~/bin/azd && chmod +x ~/bin/azd
  xattr -dr com.apple.quarantine ~/bin/azd    # 去 Gatekeeper 隔离
  hash -r; which azd; azd version
  ```
  - Apple Silicon 上跑 x86_64 build 没问题（Rosetta），只是稍慢。
- **`signal: killed` 本质也是网络**：到 `login.microsoftonline.com` 延迟高把 10s 预算耗尽。版本对齐（走 gRPC、不 spawn 子进程）是正解；治标可改善代理。
- macOS 没有 `timeout` 命令；长任务用后台跑 + 读日志文件，别用 `timeout`。

---

## 最佳实践清单（写给下一个踩坑的人）

1. **版本先对齐再 deploy**：`azd version` + `azd extension list --installed`，看到 `⚠ Incompatible` 先解决，别硬部署。azd ≥ 1.25.2 才配 `azure.ai.agents` 0.1.37。
2. **pre-release 依赖一律精确钉版**：用了 `pip install --pre` 时，凡是被传递依赖硬钉的包（这里是 otel 全家）都要 `==` 精确钉，否则 pip 回溯爆炸 / `ResolutionImpossible`。**先查 `requires_dist` 再定版本，不要猜。**
3. **模型部署名要核实存在**：部署前 `az cognitiveservices account deployment list` 对一遍，`DeploymentNotFound` 在部署阶段看不出来、只在运行时炸。
4. **agent 命名要全链路一致**：azd 用服务名命名 agent，测试脚本默认用 `STUDENT_SUFFIX` 后缀名——两者必须对齐（根 `.env` 设 `AGENT_NAME`，或让 azd 用后缀名部署）。
5. **凭据放对地方**：tenant id（公开 GUID）可入 azd env 让 hook 通过；client secret 留在根 `.env`，靠脚本兜底读，别灌进 azd 的 `.azure/<env>/.env`（会明文持久化）。
6. **运行时问题先拉容器日志**：`azd ai agent monitor --session-id <id> --tail N`，比盯着 `server_error` 猜快得多。
7. **`azd deploy` 退出码 1 ≠ 部署失败**：先看是 deploy 本身挂了还是末尾 postdeploy hook 挂了（agent 可能早已 `Done`）。
8. **Chat UI 永远走 `chat-hosted.sh` 给的 `#cfg=` URL 打开**；直接开文件会吃 localStorage 旧值。

---

## 本次落到文件 / 环境的改动

| 位置 | 改动 |
|------|------|
| `~/bin/azd` | 放入 azd 1.25.4 二进制（覆盖 brew 的 1.25.1） |
| 扩展 | `azure.ai.agents` 0.1.34 → 0.1.37 |
| `src/research_agent/requirements.txt` | otel 钉到 `1.40.0 / 0.61b0`；`httpx<1.0` |
| 根 `.env` | `AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-5.4-mini`；新增 `AGENT_NAME=research-agent` |
| azd env (`dev`) | 新增 `FOUNDRY_PROJECT_ENDPOINT`、`FOUNDRY_PROJECT_ID`、`AZURE_TENANT_ID`；`AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-5.4-mini` |

## 已知遗留（非阻塞）

- **可观测性 403**：容器日志 `agent365_exporter HTTP 403 — Required app role: Agent365.Observability.OtelWrite`。只是 OTLP 遥测导出缺角色，不影响对话；留到 Lab-4 observability 处理。
- **命名设计取舍**：当前让全链路指向不带后缀的 `research-agent`。若该 Foundry 项目要多人共用、每人一个 `research-agent-stuNN` 隔离，应反过来让 azd 用后缀名部署（改 `azure.yaml` 服务名或 agent 名覆盖），而不是改测试脚本。
