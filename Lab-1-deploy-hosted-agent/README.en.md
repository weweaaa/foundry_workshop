# Lab 1 · First Foundry Hosted Agent Deployment (15 min)

## 1.1 Goals

- Understand why this repository uses only `azd deploy`, with no `azd up` or infrastructure provisioning.
- Sync deployment variables from `.env` into the Lab 2 azd environment.
- Deploy the reference implementation to the shared Foundry project with `azd deploy research-agent`.
- Verify the hosted `/responses` endpoint with the local graphical chat UI or command-line script.

> Lab 1 deploys the built-in `research-agent`. Lab 2 changes the business logic locally, and Lab 3 publishes the updated version.

## 1.2 Agent-driven Flow

Treat Lab 1 as an auditable release, not a sequence of `azd` commands. First ask Copilot to read the deployment entrypoints and explain what it will verify:

```text
@workspace I am working on Lab 1. Read #file:Lab-2-vibe-coding/azure.yaml, #file:Lab-2-vibe-coding/src/research_agent/agent.yaml, #file:Lab-2-vibe-coding/src/research_agent/agent.manifest.yaml, and #file:Lab-2-vibe-coding/hooks/postdeploy-grant-roles.ps1.
First explain what deployment will do, why I must not run azd up, and what the completion signal is.
```

| Human owns | Copilot coding agent owns | Completion signal |
|------------|---------------------------|-------------------|
| Confirm `.env` came from the instructor and approve deploying your own `research-agent-<STUDENT_SUFFIX>` | Check for missing azd env values, explain `azure.yaml`, attribute deploy/invoke errors | `azd deploy research-agent` succeeds and `invoke-hosted.* -Prompt ping` returns completed |

## 1.3 Working with Copilot

| Task | VS Code path (main) | Copilot TUI path (optional) |
|------|---------------------|-----------------------------|
| Explain `azure.yaml` | `@workspace Explain #file:azure.yaml services.research-agent` | Run `copilot`, paste the relevant `azure.yaml` snippet, and ask the same question |
| Understand deployment metadata | `#file:src/research_agent/agent.yaml #file:src/research_agent/agent.manifest.yaml explain the difference` | Paste the relevant content from both yaml files and ask TUI chat to compare responsibilities |
| Troubleshoot deployment failure | Paste the `azd deploy` error and ask it to analyze only this workshop path | Paste the error output and ask TUI chat to troubleshoot only within this workshop's constraints |

## 1.4 Initialize azd env and Sync Variables

Start from the repository root.

**Windows (PowerShell)**

```powershell
. .\scripts\Windows\load-env.ps1
cd Lab-2-vibe-coding
azd init -e dev --no-prompt

azd env set AZURE_SUBSCRIPTION_ID $env:AZURE_SUBSCRIPTION_ID
azd env set AZURE_LOCATION $env:AZURE_LOCATION
azd env set AZURE_AI_PROJECT_ENDPOINT $env:AZURE_AI_PROJECT_ENDPOINT
azd env set FOUNDRY_PROJECT_ENDPOINT $env:AZURE_AI_PROJECT_ENDPOINT
azd env set AZURE_AI_PROJECT_ID $env:AZURE_AI_PROJECT_ID
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME $env:AZURE_AI_MODEL_DEPLOYMENT_NAME
azd env set AZURE_CONTAINER_REGISTRY_NAME $env:AZURE_CONTAINER_REGISTRY_NAME
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT $env:AZURE_CONTAINER_REGISTRY_ENDPOINT
azd env set STUDENT_SUFFIX $env:STUDENT_SUFFIX
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
```

**macOS / Linux (bash)**

```bash
source scripts/macOSLinux/load-env.sh
cd Lab-2-vibe-coding
azd init -e dev --no-prompt

azd env set AZURE_SUBSCRIPTION_ID "$AZURE_SUBSCRIPTION_ID"
azd env set AZURE_LOCATION "$AZURE_LOCATION"
azd env set AZURE_AI_PROJECT_ENDPOINT "$AZURE_AI_PROJECT_ENDPOINT"
azd env set FOUNDRY_PROJECT_ENDPOINT "$AZURE_AI_PROJECT_ENDPOINT"
azd env set AZURE_AI_PROJECT_ID "$AZURE_AI_PROJECT_ID"
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME "$AZURE_AI_MODEL_DEPLOYMENT_NAME"
azd env set AZURE_CONTAINER_REGISTRY_NAME "$AZURE_CONTAINER_REGISTRY_NAME"
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT "$AZURE_CONTAINER_REGISTRY_ENDPOINT"
azd env set STUDENT_SUFFIX "$STUDENT_SUFFIX"
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
```

> `azd env` stores only non-interactive variables needed for deployment. Scripts and the postdeploy hook still read the repository-root `.env`.

After syncing, let Copilot do a read-only check:

```text
I have run the Lab 1 azd env set commands. Tell me which azd env get-value commands I should run to verify the variables; do not modify files.
```

## 1.5 Understand the Lab 2 Deployment Entry

In `Lab-2-vibe-coding/azure.yaml`, the key information is a single service:

```yaml
services:
  research-agent:
    project: src/research_agent
    host: azure.ai.agent
    language: docker
    docker:
      remoteBuild: true
```

Key points:

- `remoteBuild: true` means ACR remote build creates the image; students do not need local Docker.
- There is no `infra:` because shared Foundry and ACR have already been created by the instructor.
- `hooks.postdeploy` grants `AcrPull` and `Azure AI User` to the managed identities that Foundry creates for this agent version.

## 1.6 Deploy

```powershell
azd deploy research-agent
```

Deployment does three things:

1. Builds and pushes the container image with ACR remote build.
2. Creates or updates `research-agent-<STUDENT_SUFFIX>` in the shared Foundry project.
3. Runs the postdeploy hook to grant image-pull and model-call permissions to the runtime identity for this version.

> Do not run `azd up`. This workshop has no student-side infrastructure, so `azd up` / `azd provision` is not the correct path.

## 1.7 Verify the Hosted Endpoint

### Graphical Chat (Recommended)

**Windows (PowerShell)**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux (bash)**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

The script reads `FOUNDRY_API_KEY`, project endpoint, and agent name from the repository-root `.env`, then opens a local HTML chat UI. Credentials only live in the local URL hash and are not sent to third parties.

### Command-line Verification

**Windows (PowerShell)**

```powershell
..\scripts\Windows\invoke-hosted.ps1 -Prompt "ping"
```

**macOS / Linux (bash)**

```bash
../scripts/macOSLinux/invoke-hosted.sh --prompt "ping"
```

The response passes when JSON status is `completed` and text output exists.

Ask Copilot to summarize the release result:

```text
Here is the invoke-hosted output. Decide whether Lab 1 is complete, and explain in 3 bullets whether the hosted agent, FOUNDRY_API_KEY, and postdeploy RBAC are healthy.
```

## 1.8 Self-check

**Windows (PowerShell)**

```powershell
..\scripts\Windows\sanity-check.ps1
```

**macOS / Linux (bash)**

```bash
../scripts/macOSLinux/sanity-check.sh
```

Expected checks:

- Key `.env` variables are set.
- Model deployment is accessible.
- Hosted agent is reachable and can run `ping`.
- ACR remote build permission is available.

## 1.9 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd deploy` reports missing `AZURE_AI_PROJECT_ID` | Repeat the azd env sync in Lab 1 §1.4 |
| `azd deploy` ACR push / remote build is slow | The first base image push can be slow; wait |
| Hosted call returns 401 | Check `.env` `FOUNDRY_API_KEY` and project endpoint |
| Hosted call returns 403 / runtime server error | Postdeploy RBAC may not have propagated; rerun `azd deploy research-agent` or contact the TA |
| Agent name conflict | Confirm `STUDENT_SUFFIX` matches the value assigned by the instructor |
| `azd up` fails | Wrong command; only use `azd deploy research-agent` |

→ [Lab 2 · GitHub Copilot vibe coding business agent](../Lab-2-vibe-coding/README.en.md)
