# Workshop Utility Scripts

> 學員或講師在 Lab 0~4 會用到的小工具。**Windows 使用 PowerShell（`*.ps1`），macOS / Linux 使用 bash（`*.sh`）**，兩套腳本一一對應，行為一致。

## 目錄結構

```text
scripts/
├── Windows/         # PowerShell 7 (pwsh) / Windows PowerShell 5.1 都能跑，UTF-8 BOM
├── macOSLinux/      # bash 3.2+（相容預設 macOS bash），依賴 curl + jq
├── chat-hosted/     # 瀏覽器圖形化 chat UI，被 chat-hosted.* 呼叫載入
├── lint-persona.py  # 跨平台，Python 3 直接跑
└── README.md
```

## 腳本一覽

| 用途 | 用在哪個 Lab | Windows (`.ps1`) | macOS / Linux (`.sh`) |
|------|--------------|------------------|------------------------|
| 啟用 VS Code Copilot 的 chatmodes/instructions/prompts；列印 skill 入口 | Lab 0 | [Windows/install-maf-copilot-skills.ps1](./Windows/install-maf-copilot-skills.ps1) | [macOSLinux/install-maf-copilot-skills.sh](./macOSLinux/install-maf-copilot-skills.sh) |
| 把 workshop 根 `.env` 載入目前 shell（其他腳本被呼叫時也會自動跑一次） | 全部 | [Windows/load-env.ps1](./Windows/load-env.ps1) | [macOSLinux/load-env.sh](./macOSLinux/load-env.sh) |
| 驗證 `.env` / SP 憑據 / 共享 Foundry / hosted agent 可達 / ACR 推送權限 | Lab 1 / Lab 3 | [Windows/sanity-check.ps1](./Windows/sanity-check.ps1) | [macOSLinux/sanity-check.sh](./macOSLinux/sanity-check.sh) |
| 用 api-key 呼叫 hosted agent `/responses` + 將 `response_id` 寫入 Lab 4 索引；`--status-only` 只看可達 | Lab 1 / Lab 3 / Lab 4 | [Windows/invoke-hosted.ps1](./Windows/invoke-hosted.ps1) | [macOSLinux/invoke-hosted.sh](./macOSLinux/invoke-hosted.sh) |
| 開啟本機瀏覽器圖形 chat UI（api-key 模式） | Lab 1 / Lab 3 | [Windows/chat-hosted.ps1](./Windows/chat-hosted.ps1) | [macOSLinux/chat-hosted.sh](./macOSLinux/chat-hosted.sh) |
| `azd deploy` postdeploy hook：給 agent per-version MI 授 AcrPull + Azure AI User | Lab 1 / Lab 3（自動） | [Windows/grant-agent-runtime-roles.ps1](./Windows/grant-agent-runtime-roles.ps1) | [macOSLinux/grant-agent-runtime-roles.sh](./macOSLinux/grant-agent-runtime-roles.sh) |
| 校驗 persona frontmatter / `{{include}}` 引用 / 必備 section | Lab 2 | [lint-persona.py](./lint-persona.py) | [lint-persona.py](./lint-persona.py) |

> Lab 4 的 `fetch-traces.*` 腳本放在 [Lab-4-observability/README.zh-TW.md](../Lab-4-observability/README.zh-TW.md) 所在目錄，和 HTML 在一起。它們會查詢 Azure Monitor metrics 並產生 `data/my-metrics.js`：Windows 用 `fetch-traces.ps1`，macOS / Linux 用 `fetch-traces.sh`（依賴 `curl` + `jq`）。

## 用法範例

### Windows（PowerShell）

```powershell
# Lab 0
.\scripts\Windows\install-maf-copilot-skills.ps1

# Lab 1 / Lab 3 部署後自檢
cd Lab-2-vibe-coding
..\scripts\Windows\sanity-check.ps1

# Lab 2 persona lint
python ..\scripts\lint-persona.py personas\research-agent.md

# Lab 3 hosted endpoint 呼叫
..\scripts\Windows\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"

# 開啟圖形 chat
..\scripts\Windows\chat-hosted.ps1
```

### macOS / Linux（bash）

```bash
# Lab 0
./scripts/macOSLinux/install-maf-copilot-skills.sh

# Lab 1 / Lab 3 部署後自檢
cd Lab-2-vibe-coding
../scripts/macOSLinux/sanity-check.sh

# Lab 2 persona lint
python3 ../scripts/lint-persona.py personas/research-agent.md

# Lab 3 hosted endpoint 呼叫
../scripts/macOSLinux/invoke-hosted.sh \
    --agent-name "research-agent-${STUDENT_SUFFIX}" \
    --prompt "ping"

# 開啟圖形 chat
../scripts/macOSLinux/chat-hosted.sh
```

> bash 腳本旗標使用長形式（`--agent-name`、`--api-key`、`--status-only`、`--no-store`、`--no-open` 等），與 PowerShell 的 `-AgentName` / `-StatusOnly` 一一對應。`load-env.sh` 必須用 `source`（或 `.`）才能注入目前 shell：`source ../scripts/macOSLinux/load-env.sh`。

## 跨平台說明

- **Windows**：`*.ps1` 在 PowerShell 7 (`pwsh`) 與 Windows PowerShell 5.1 都能跑。腳本含中文，已用 UTF-8 BOM 儲存以相容 PS 5.1。
- **macOS / Linux**：`*.sh` 使用 `#!/usr/bin/env bash`，相容 bash 3.2+（macOS 預設 `/bin/bash` 即可，無需 Homebrew bash）。依賴：
  - `curl`、`jq`（必裝；macOS：`brew install jq`，Debian/Ubuntu：`apt-get install jq`）
  - `base64`、`uuidgen`（系統自帶）
  - `azd`（可選，僅用於 `azd env get-value` fallback）
  - `code`（可選，僅 `install-maf-copilot-skills.sh` 用於檢測擴充）
- **憑據來源優先順序**（兩套腳本一致）：命令列參數 > 程序環境變數 > workshop 根 `.env` > `azd env`。