# Lab 0 · Local Environment + Credentials + Copilot (10 min)

## 0.1 Goals

- Toolchain ready: git, azd, Python, VS Code or terminal, and GitHub Copilot.
- Create and fill the single `.env` file at the repository root.
- Sign in to `azd` with the service principal provided by the instructor, preparing for `azd deploy` in Labs 1 and 3.
- Enable VS Code Copilot customization; terminal `copilot` TUI is optional only.

> Students do not create Foundry, model, or ACR resources. Shared resources are pre-provisioned by the instructor; you only deploy your own `research-agent-<STUDENT_SUFFIX>`.

## 0.2 Agent-driven Flow

The goal of this lab is not to memorize tool commands. The goal is to let Copilot help decide whether this machine is ready for Lab 1. Start with this in Copilot Chat:

```text
@workspace I am working on Lab 0. Read #file:Lab-0-setup/README.md, #file:.env.example, #file:scripts/Windows/sanity-check.ps1, and #file:scripts/macOSLinux/sanity-check.sh.
List the credentials I must confirm manually, the checks you can run, and the completion signal for entering Lab 1.
```

| Human owns | Copilot coding agent owns | Completion signal |
|------------|---------------------------|-------------------|
| Get credentials from the instructor and choose VS Code or TUI path | Check `.env.example` fields, explain script output, attribute toolchain issues | `.env` is complete, `azd auth login --check-status` passes, Copilot path works |

If Copilot wants to run commands, have it run the real commands below. Do not let it generate a new login script or change the credential file format.

## 0.3 Minimum Tool Requirements

**Windows (PowerShell)**

```powershell
git --version
azd version          # >= 1.21.3
python --version     # >= 3.11
code --version       # Required for the VS Code path
Get-Command copilot  # Required only for the optional Copilot TUI path
```

**macOS / Linux (bash)**

```bash
git --version
azd version          # >= 1.21.3
python3 --version    # >= 3.11
code --version       # Required for the VS Code path
command -v copilot   # Required only for the optional Copilot TUI path
jq --version         # Required by bash scripts; macOS: brew install jq; Ubuntu: apt-get install jq
```

Notes:

- This workshop uses ACR remote build. Students do **not** need Docker or Podman locally.
- Azure CLI `az` is only a troubleshooting tool, not the main path. Scripts and Lab 4 use REST/OAuth2 directly.

## 0.4 Clone the Repository and Fill `.env`

```powershell
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop
Copy-Item .env.example .env
notepad .env
```

```bash
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop
cp .env.example .env
${EDITOR:-nano} .env
```

The instructor provides these fields:

```text
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
AZURE_LOCATION

AZURE_AI_PROJECT_ENDPOINT
AZURE_AI_PROJECT_ID
AZURE_AI_MODEL_DEPLOYMENT_NAME
FOUNDRY_API_KEY

AZURE_CONTAINER_REGISTRY_NAME
AZURE_CONTAINER_REGISTRY_ENDPOINT
STUDENT_SUFFIX
```

Ask Copilot to check field completeness, but do not paste secret values into chat:

```text
@workspace Based only on the key names in #file:.env.example, check which keys my .env should contain; do not ask me to paste secret values.
```

## 0.5 Sign in to azd (Deployment Only)

**Windows (PowerShell)**

```powershell
. .\scripts\Windows\load-env.ps1
azd auth login --client-id $env:AZURE_CLIENT_ID --tenant-id $env:AZURE_TENANT_ID --client-secret=$env:AZURE_CLIENT_SECRET
azd config set defaults.subscription $env:AZURE_SUBSCRIPTION_ID
azd auth login --check-status
```

**macOS / Linux (bash)**

```bash
source scripts/macOSLinux/load-env.sh
azd auth login --client-id "$AZURE_CLIENT_ID" --tenant-id "$AZURE_TENANT_ID" --client-secret "$AZURE_CLIENT_SECRET"
azd config set defaults.subscription "$AZURE_SUBSCRIPTION_ID"
azd auth login --check-status
```

> You do not need `az login`. If you later use `az` manually for troubleshooting, sign in only then.

## 0.6 Install the azd ai agent Extension

```powershell
azd extension install azure.ai.agents
azd extension list
```

Confirm that `azure.ai.agents` appears in the list.

## 0.7 Enable Copilot (Choose One)

### Path A · VS Code Copilot Chat (Recommended)

**Windows (PowerShell)**

```powershell
.\scripts\Windows\install-maf-copilot-skills.ps1
cd Lab-2-vibe-coding
code .
```

**macOS / Linux (bash)**

```bash
./scripts/macOSLinux/install-maf-copilot-skills.sh
cd Lab-2-vibe-coding
code .
```

In VS Code, open Copilot Chat and select the `maf-agent` chatmode at the top. Try:

```text
@workspace List the Copilot prompts and skills supported by this workshop.
```

### Path B · Copilot TUI (Optional)

```powershell
copilot
```

After entering chat, type:

```text
Explain this workshop's Lab 0 readiness check based on the current directory. If you need context, I will paste README or script snippets.
```

The TUI path does not automatically use the `maf-agent` chatmode, instructions, or slash prompts. When it needs Foundry or Agent Framework context, paste the relevant `SKILL.md` or `.github/prompts/*.prompt.md` content into chat. Copilot prompt guidance is consolidated in [../README.en.md](../README.en.md#cheat-sheet).

## 0.8 Exit Checkpoint

```powershell
azd auth login --check-status
.\scripts\Windows\sanity-check.ps1
```

```bash
azd auth login --check-status
./scripts/macOSLinux/sanity-check.sh
```

Before continuing to Lab 1, confirm:

- `.env` is complete.
- `azd auth login --check-status` exits with code 0.
- Your chosen Copilot path works.
- `.env`, model, and ACR permission checks pass in `sanity-check.*`; hosted agent checks may fail before Lab 1 deployment, which is normal.

Use this closing prompt with Copilot:

```text
Here is the Lab 0 readiness check output. Decide whether I can enter Lab 1. If not, list only the smallest fix steps and do not suggest creating Azure resources.
```

## 0.9 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd auth login` reports `AADSTS7000215` | Secret is wrong or shell escaping ate it; compare `.env` against instructor-provided values |
| PowerShell sign-in fails when the secret has special characters | Use `--client-secret=$env:AZURE_CLIENT_SECRET`; do not use a space-separated value |
| `azd extension install` times out | Switch networks or ask the TA for an offline extension package |
| Copilot Chat does not show `maf-agent` | Rerun `install-maf-copilot-skills.*`, then run `Developer: Reload Window` |
| `copilot` command is missing or requires login | Prefer the VS Code main path; ask the TA to help install/sign in to Copilot TUI if needed |

→ [Lab 1 · First hosted agent deployment](../Lab-1-deploy-hosted-agent/README.en.md)