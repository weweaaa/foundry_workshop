# Copilot MAF Skills

> 給學員的 VS Code Copilot 裝上「市場研究 agent vibe coding」所需的上下文。這些檔案隨 workshop 倉庫分發，會自動被 Copilot 識別。

## 自動載入位置

VS Code Copilot Chat 在開啟任意 workspace 時，會讀取該 workspace 根目錄下的：

- `.github/chatmodes/*.chatmode.md` — 自訂 chat mode（頂部下拉切換）
- `.github/instructions/*.instructions.md` — 按 `applyTo` glob 注入到匹配檔案的 Copilot 上下文
- `.github/prompts/*.prompt.md` — `/<slug>` 斜杠命令

學員在 Lab 0 `cd` 到 `Lab-2-vibe-coding` 並執行 `code .`，本目錄的所有檔案即自動生效。

## 提供的 skill

| 檔案 | 類型 | 觸發方式 |
|------|------|----------|
| `chatmodes/maf-agent.chatmode.md` | chatmode | Copilot Chat 頂部下拉選擇 "maf-agent" |
| `instructions/maf-tools.instructions.md` | instructions | 編輯 `tools/**/*.py` 時自動注入 |
| `instructions/maf-personas.instructions.md` | instructions | 編輯 `personas/**/*.md` 時自動注入 |
| `instructions/maf-skills.instructions.md` | instructions | 編輯 `skills/**/SKILL.md` 時自動注入 |
| `prompts/persona.prompt.md` | prompt | Chat 輸入 `/persona` |
| `prompts/skill.prompt.md` | prompt | Chat 輸入 `/skill` |
| `prompts/tool.prompt.md` | prompt | Chat 輸入 `/tool` |
| `prompts/deploy.prompt.md` | prompt | Chat 輸入 `/deploy` |

## 啟用 VS Code 設定（如果預設未開）

VS Code 1.95+ 預設啟用 chatmodes/prompts/instructions。如果沒看到，執行：

**Windows（PowerShell）**

```powershell
..\..\scripts\Windows\install-maf-copilot-skills.ps1
```

**macOS / Linux（bash）**

```bash
../../scripts/macOSLinux/install-maf-copilot-skills.sh
```

腳本會：

1. 檢查 VS Code 與 Copilot 擴充版本。
2. 寫入 `.vscode/settings.json` 啟用 `chat.promptFiles` / `chat.modeFiles` / `chat.instructionsFiles`。
3. 開啟 VS Code 到目前目錄。

## 改寫預設場景

把這些 skill 檔案改寫成你自己的業務領域：

- 將 `chatmodes/maf-agent.chatmode.md` 頂部的 "Default scenario" 換成你的業務。
- `instructions/*` 通常不改；它們是約定層。
- 修改 `prompts/*.prompt.md` 的 input 欄位與範例。