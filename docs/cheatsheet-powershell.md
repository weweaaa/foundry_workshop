# 速查卡 · PowerShell 转义与常用命令

> Windows 学员默认在 `pwsh` (PowerShell 7) 里跑。macOS / Linux 学员推荐直接用工作坊提供的原生 bash 版脚本（`scripts/macOSLinux/*.sh`）；如果仍希望用 PowerShell，可装 [PowerShell on Linux/macOS](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)。

## 字符串引用规则

| 场景 | 写法 | 说明 |
|------|------|------|
| 普通字符串 | `"hello"` 或 `'hello'` | 单引号 = 字面;双引号 = 插值 |
| 含 `$` `!` 等特殊字符的 secret | **必用双引号** `"P@ss!w0rd$xyz"`;CLI 参数用 `=` 语法 `--client-secret=$Secret` | 单引号下 `$` 不会被解析,但 azd CLI 仍按字面字符串接收;若 secret 含 `-` `s` 等会被 PS5.1 当成下一个参数前缀,**必须**用 `=` |
| secret 含双引号 | `"abc`"def"` | 用 backtick `` ` `` 转义 |
| 单引号字符串里含单引号 | `'it''s'` | 重复单引号转义 |
| 多行字符串 | `@" ... "@`(here-string) | 含 `$` 会被插值;改 `@' ... '@` 不插值 |

## azd / az 服务主体登录

```powershell
$AppId    = "<appId>"
$Secret   = "<secret>"
$TenantId = "<tid>"
$SubId    = "<subId>"

# azd — 注意必须用 `=` 语法，否则 PS5.1 可能把 secret 当下个参数前缀吞掉
azd auth login --client-id $AppId --tenant-id $TenantId --client-secret=$Secret
azd auth login --check-status

# az — `--password=` 同理；secret 含 `-` 开头风险字符时不加 `=` 会失败
az login --service-principal -u $AppId "--password=$Secret" --tenant $TenantId
az account set --subscription $SubId
az account show
```

## 常用 azd 命令

```powershell
azd env get-values                    # 看所有环境变量
azd env get-value AZURE_AI_PROJECT_ENDPOINT
azd env set <KEY> <VALUE>             # 写环境变量
azd env refresh                       # 拉远端 RG 状态到本地
azd deploy <service>                  # 单独发布某 service (本工作坊主要用这个)
```

> 本工作坊**不要**跑 `azd up` / `azd provision` / `azd down` —— 学员 SP 没 RG 级权限。

## 常用 az 命令

```powershell
az account show -o table
az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
```

## 调 hosted agent

```powershell
$ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT
$TOKEN    = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv

$body = @{ input = "Hello, who are you?" } | ConvertTo-Json
Invoke-RestMethod -Method POST `
  -Uri "$ENDPOINT/agents/<AgentName>/endpoint/protocols/openai/responses?api-version=2025-11-15-preview" `
  -Headers @{ Authorization = "Bearer $TOKEN" } `
  -ContentType "application/json" `
  -Body $body
```

> 一般直接用 `scripts/Windows/invoke-hosted.ps1` (或 macOS / Linux 上的 `scripts/macOSLinux/invoke-hosted.sh`) 即可,它把 token 获取 / URL 构造 / 重试都封装好了。

## 跨 shell 的环境变量

```powershell
# 当前 PowerShell 会话
$env:KEY = "value"

# 持久(用户级)
[Environment]::SetEnvironmentVariable("KEY", "value", "User")

# 从 azd 注入
$env:AZURE_AI_PROJECT_ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT
```

## 文件 / 目录

```powershell
# Get-ChildItem(等同 ls / dir)
Get-ChildItem -Recurse -Filter "*.py" -Path .\Lab-2-vibe-coding\

# Test-Path
if (Test-Path .\Lab-2-vibe-coding\.azure\dev\.env) { Write-Host "yes" }

# 读写 JSON
$env_data = Get-Content .azure\dev\.env -Raw
$obj = "{}" | ConvertFrom-Json
$obj | ConvertTo-Json | Set-Content out.json
```

## 常见坑

| 现象 | 原因 | 处理 |
|------|------|------|
| `az login -p $Secret` 返回 `Get Token request returned http error: 401` | secret 被 shell 转义 | 双引号包裹;或写 `"$Secret"` |
| `azd env set FOO '{"a":1}'` 设进去变成空 | 单引号 + JSON 嵌套引号 | 改用 here-string 或用 `--no-prompt` + stdin |
| `Invoke-RestMethod` 报 SSL | 自签证书 | `-SkipCertificateCheck`(PS 7+) |
| `pwsh` 与 `powershell` 行为不同 | PS 5 vs PS 7 | 本 workshop 推荐 `pwsh`(PowerShell 7) |
