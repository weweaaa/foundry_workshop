# Workshop Utility Scripts

> 学员或讲师在 Lab 0~4 里会用到的小工具。**Windows 用 PowerShell（`*.ps1`）、macOS / Linux 用 bash（`*.sh`），两套脚本一一对应，行为一致。**

## 目录结构

```
scripts/
├── Windows/         # PowerShell 7 (pwsh) / Windows PowerShell 5.1 都能跑，UTF-8 BOM
├── macOSLinux/      # bash 3.2+（兼容默认 macOS shell），依赖 curl + jq
├── chat-hosted/     # 浏览器图形化 chat UI，被 chat-hosted.* 调用加载
├── lint-persona.py  # 跨平台，Python 3 直接跑
└── README.md
```

## 脚本一览

| 用途 | 用在哪个 Lab | Windows (`.ps1`) | macOS / Linux (`.sh`) |
|------|------------|------------------|------------------------|
| 启用 VS Code Copilot 的 chatmodes/instructions/prompts；打印 skill 入口 | Lab 0 | [`Windows/install-maf-copilot-skills.ps1`](./Windows/install-maf-copilot-skills.ps1) | [`macOSLinux/install-maf-copilot-skills.sh`](./macOSLinux/install-maf-copilot-skills.sh) |
| 把 workshop 根 `.env` 加载进当前 shell（其它脚本被调时也会自动跑一次） | 全部 | [`Windows/load-env.ps1`](./Windows/load-env.ps1) | [`macOSLinux/load-env.sh`](./macOSLinux/load-env.sh) |
| 验证 `.env` / SP 凭据 / 共享 Foundry / hosted agent 可达 / ACR 推送权限 | Lab 1 / Lab 3 | [`Windows/sanity-check.ps1`](./Windows/sanity-check.ps1) | [`macOSLinux/sanity-check.sh`](./macOSLinux/sanity-check.sh) |
| api-key 调 hosted agent `/responses` + 落 `response_id` 到 Lab 4 索引；`--status-only` 只看可达 | Lab 1 / Lab 3 / Lab 4 | [`Windows/invoke-hosted.ps1`](./Windows/invoke-hosted.ps1) | [`macOSLinux/invoke-hosted.sh`](./macOSLinux/invoke-hosted.sh) |
| 打开本地浏览器图形 chat UI（api-key 模式，URL 反复用） | Lab 1 / Lab 3 | [`Windows/chat-hosted.ps1`](./Windows/chat-hosted.ps1) | [`macOSLinux/chat-hosted.sh`](./macOSLinux/chat-hosted.sh) |
| `azd deploy` postdeploy 钩子：给 agent per-version MI 授 AcrPull + Azure AI User | Lab 1 / Lab 3（自动） | [`Windows/grant-agent-runtime-roles.ps1`](./Windows/grant-agent-runtime-roles.ps1) | [`macOSLinux/grant-agent-runtime-roles.sh`](./macOSLinux/grant-agent-runtime-roles.sh) |
| 校验 persona frontmatter / `{{include}}` 引用 / 必备 section | Lab 2 | [`lint-persona.py`](./lint-persona.py)（共用） | [`lint-persona.py`](./lint-persona.py)（共用） |

> Lab 4 的 `fetch-traces.*`（调 Azure Monitor metrics，生成 `data/my-metrics.js`）单独放在 [Lab-4-observability/README.md](../Lab-4-observability/README.md) 所在目录，与 HTML 在一起：Windows 用 `fetch-traces.ps1`，macOS / Linux 用 `fetch-traces.sh`（依赖 `curl` + `jq`）。

## 用法示例

### Windows（PowerShell）

```powershell
# Lab 0
.\scripts\Windows\install-maf-copilot-skills.ps1

# Lab 1 / Lab 3 部署后自检
cd Lab-2-vibe-coding
..\scripts\Windows\sanity-check.ps1

# Lab 2 persona lint
python ..\scripts\lint-persona.py personas\research-agent.md

# Lab 3 hosted endpoint 调用
..\scripts\Windows\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"

# 打开图形 chat
..\scripts\Windows\chat-hosted.ps1
```

### macOS / Linux（bash）

```bash
# Lab 0
./scripts/macOSLinux/install-maf-copilot-skills.sh

# Lab 1 / Lab 3 部署后自检
cd Lab-2-vibe-coding
../scripts/macOSLinux/sanity-check.sh

# Lab 2 persona lint
python3 ../scripts/lint-persona.py personas/research-agent.md

# Lab 3 hosted endpoint 调用
../scripts/macOSLinux/invoke-hosted.sh \
    --agent-name "research-agent-${STUDENT_SUFFIX}" \
    --prompt "ping"

# 打开图形 chat
../scripts/macOSLinux/chat-hosted.sh
```

> bash 脚本的旗标用长形式（`--agent-name`、`--api-key`、`--status-only`、`--no-store`、`--no-open` 等），与 PowerShell 的 `-AgentName` / `-StatusOnly` 一一对应。`load-env.sh` 必须用 `source`（或 `.`）才能注入当前 shell：`source ../scripts/macOSLinux/load-env.sh`。

## 跨平台说明

- **Windows**：`*.ps1` 在 PowerShell 7 (`pwsh`) 与 Windows PowerShell 5.1 都能跑。脚本含中文，已用 UTF-8 BOM 保存以兼容 PS 5.1。
- **macOS / Linux**：`*.sh` 使用 `#!/usr/bin/env bash`，兼容 bash 3.2+（macOS 默认 `/bin/bash` 即可，无需 homebrew bash）。依赖：
  - `curl`、`jq`（必装；macOS：`brew install jq`，Debian/Ubuntu：`apt-get install jq`）
  - `base64`、`uuidgen`（系统自带）
  - `azd`（可选，仅用于 `azd env get-value` fallback）
  - `code`（可选，仅 `install-maf-copilot-skills.sh` 用于检测扩展）
- **凭据来源优先级**（两套脚本一致）：命令行参数 > 进程环境变量 > workshop 根 `.env` > `azd env`
