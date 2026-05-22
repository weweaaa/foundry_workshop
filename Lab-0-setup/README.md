# Lab 0 · 本地环境 + Copilot + 讲师凭据登录(20 min)

## 0.1 目标

- 工具链(git / azd / az / Python / Docker / VS Code 或终端 / Copilot)就绪
- 用**讲师下发的 SP 凭据**登录 azd / az
- 启用 Copilot:VS Code Copilot Chat **或** GitHub Copilot CLI(二选一)
- 确认 `.agents/skills/` 下的微软官方 skill 可被 Copilot 识别

> 共享 Foundry 资源(account / project / 模型 / ACR)已由讲师在配套仓库中预部署。学员**没有权限**自己创建,直接用讲师下发的凭据接入即可。

## 0.2 工具最低版本

```powershell
azd version          # ≥ 1.21.3
az version           # ≥ 2.55
python --version     # ≥ 3.11
docker version       # 可选 (本工作坊走 ACR remote build;本地有 Docker 更方便)
gh --version         # 任意 (用 Copilot CLI 必装)
code --version       # 用 VS Code 路径必装
```

不达标 → 举手 `#help-lab-0`。

## 0.3 从讲师处领凭据

开课前讲师会给你这些字段(信封 / 飞书私信 / 邮件均可):

```
AZURE_TENANT_ID                = <tenant guid>
AZURE_SUBSCRIPTION_ID          = <sub guid>
AZURE_CLIENT_ID                = <学员 SP appId>
AZURE_CLIENT_SECRET            = <学员 SP secret>

AZURE_AI_PROJECT_ENDPOINT      = https://<account>.services.ai.azure.com/api/projects/<project>
AZURE_AI_MODEL_DEPLOYMENT_NAME = gpt-5-mini             # 或讲师指定的
AZURE_CONTAINER_REGISTRY_NAME  = cr<token>
AZURE_CONTAINER_REGISTRY_ENDPOINT = cr<token>.azurecr.io

STUDENT_SUFFIX                 = stuNN                  # 你的专属后缀,决定 hosted agent 名
```

GitHub Copilot 订阅 / trial 激活信息也找讲师拿。

## 0.4 SP 登录(azd + az 都要登)

```powershell
$AppId   = "<AZURE_CLIENT_ID>"
$Secret  = "<AZURE_CLIENT_SECRET>"
$TenId   = "<AZURE_TENANT_ID>"
$SubId   = "<AZURE_SUBSCRIPTION_ID>"

# 1. azd 登录(注意必须用 `=`，否则 PS5.1 在 secret 含 `-` `s` 等字符时会把它当下个参数前缀吞掉)
azd auth login --client-id $AppId --tenant-id $TenId --client-secret=$Secret

# 2. az 登录(azd 内部 hook 还会调 az)
az login --service-principal -u $AppId "--password=$Secret" --tenant $TenId | Out-Null
az account set --subscription $SubId

# 3. azd 默认订阅
azd config set defaults.subscription $SubId
```

> ⚠️ PowerShell 转义:secret 含 `$` `!` 空格等用双引号;含 `"` 用反引号 `` ` `` 转义。详见 [`cheatsheet-powershell.md`](cheatsheet-powershell.md)。

## 0.5 安装 azd ai agent 扩展

```powershell
azd extension install azure.ai.agents
azd extension list
```

## 0.6 Clone workshop 仓库

```powershell
git clone https://github.com/<org>/foundry-workshop.git
cd foundry-workshop\workshop
git checkout lab-0-ready    # 把你拉到 Lab 0 起点
```

## 0.7 启用 Copilot(二选一)

### 路径 A · VS Code Copilot Chat(推荐)

```powershell
.\scripts\install-maf-copilot-skills.ps1
```

脚本会:

1. 检查 VS Code + Copilot/Copilot Chat 扩展。
2. 写 `Lab-2-vibe-coding/.vscode/settings.json` 开启 chatmodes / instructions / prompts 装载。
3. 打印每个 customization 文件的入口(哪个文件、Chat 里怎么触发)。

完成后:

```powershell
cd Lab-2-vibe-coding
code .
# Ctrl+Alt+I 打开 Copilot Chat
# 顶部下拉应该能看到 "maf-agent" chatmode
# 输入 /persona / /tool / /skill / /deploy 试试斜杠命令
```

**确认 `.agents/skills/` 也被识别**:在 Copilot Chat 输入:

```
@workspace 列出当前 workspace 已激活的 skills
```

应能看到 `microsoft-foundry`、`agent-framework-azure-ai-py`、`azure-ai-projects-py`、`skill-creator` 这 4 个。

### 路径 B · GitHub Copilot CLI

```powershell
# 装 gh-copilot 扩展
gh extension install github/gh-copilot

# 验证
gh copilot suggest "list azure resource groups in current sub"
```

CLI 不会自动读 `.agents/skills/`。需要 skill 知识时,用 cheat sheet 里的模式手动拼接:

```powershell
$ctx = Get-Content .agents\skills\microsoft-foundry\SKILL.md -Raw
gh copilot suggest "$ctx`n`n基于上面的 skill 内容回答: 我如何确认共享 Foundry project 上是否有名为 research-agent-stu07 的 hosted agent?"
```

详见 [`cheatsheet-copilot.md`](cheatsheet-copilot.md)。

## 0.8 把讲师凭据写入本地 .env

```powershell
cd Lab-2-vibe-coding
Copy-Item .env.example .env
# 用 notepad 打开 .env,逐行填入讲师给你的字段
notepad .env
```

## 0.9 出口检查点

```powershell
azd auth login --check-status
if ($LASTEXITCODE -eq 0) { Write-Host "✅ azd OK" } else { Write-Host "❌ azd NOT logged in" }
az account show --query name -o tsv
```

✅ `azd auth login --check-status` 退出码 0
✅ `az account show` 输出当前订阅名
✅ Copilot 路径 A:VS Code Copilot 图标常亮 + Chat 顶部可选 `maf-agent`
✅ Copilot 路径 B:`gh copilot suggest "ping"` 能返回建议
✅ `.env` 已填好

## 0.10 故障速查

| 现象 | 处理 |
|------|------|
| `azd auth login` 报 `AADSTS7000215: Invalid client secret` | secret 失效或被特殊字符吃掉,回讲师那确认 |
| `az login` OK 但 `azd auth login` 失败 | azd 与 az 独立登录态,两边都要登 |
| `azd extension install` 网络超时 | 切手机热点 / 找助教要离线 nupkg |
| Copilot 图标灰色 | `Ctrl+Shift+P` → `GitHub Copilot: Sign in` 重登 |
| Copilot Chat 下拉看不到 `maf-agent` | 重新跑 `install-maf-copilot-skills.ps1`,然后 `Developer: Reload Window` |
| `gh copilot suggest` 报 `not authenticated` | `gh auth login` → 选 GitHub.com → 用浏览器登录 |
| `.agents/skills/` 下找不到 skill | 跑 `npx -y skills add microsoft/skills --full-depth --copy -y -a github-copilot -s microsoft-foundry agent-framework-azure-ai-py azure-ai-projects-py skill-creator` 补装 |

→ [Lab 1 · 部署你的第一个 GPT-5 云端 agent](../Lab-1-deploy-hosted-agent/README.md)
