# Lab 3 · Update the Local Business Agent to Foundry Hosted (10 min)

In Lab 2, you debugged `src/research_agent/` locally, or created your own business agent. This lab republishes the modified code to the shared Foundry project.

## 3.1 Goals

- Understand the responsibilities of `agent.yaml` and `agent.manifest.yaml`.
- Confirm `azure.yaml` points to the agent you want to publish.
- Incrementally publish with `azd deploy research-agent`.
- Verify business output through the hosted endpoint.

## 3.2 Agent-driven Release Flow

The point of Lab 3 is not “run deploy again”; it is safely publishing the local artifact from Lab 2 to the hosted slot. First ask Copilot for a read-only release review:

```text
@workspace I am working on Lab 3. Read #file:Lab-2-vibe-coding/azure.yaml, #file:Lab-2-vibe-coding/src/research_agent/agent.yaml, #file:Lab-2-vibe-coding/src/research_agent/agent.manifest.yaml, #file:Lab-2-vibe-coding/src/research_agent/main.py, and #file:Lab-2-vibe-coding/personas/research-agent.md.
Check the release path from local artifact to hosted agent. List 5 things that must be confirmed before deployment; do not modify files.
```

| Human owns | Copilot coding agent owns | Completion signal |
|------------|---------------------------|-------------------|
| Confirm Lab 2 business behavior is accepted and approve overwriting your hosted agent | Check yaml alignment, explain deployment impact, attribute hosted-call errors | Hosted `/responses` returns updated business JSON and guardrails still work |

## 3.3 Responsibilities of the Two YAML Files

| File | What it solves | Key fields |
|------|----------------|-----------|
| `src/research_agent/agent.yaml` | How Foundry hosts the container | `kind: hosted`, `protocols`, `resources`, `environment_variables` |
| `src/research_agent/agent.manifest.yaml` | Which model and server-side tools the agent uses at runtime | `model`, `instructions.file`, `tools` |
| `azure.yaml` | How azd builds and publishes the service | `host: azure.ai.agent`, `docker.remoteBuild: true`, postdeploy hook |

The default `research-agent` is already configured. For your own business agent, use Copilot `/deploy` to generate the two YAML files for the new directory, then point `azure.yaml.services` to the new service.

## 3.4 Use Copilot to Check Deployment Configuration

VS Code:

```text
@workspace Check whether #file:azure.yaml #file:src/research_agent/agent.yaml #file:src/research_agent/agent.manifest.yaml are suitable for deployment to the shared Foundry project; do not create infra and do not use local Docker build.
```

Copilot TUI (optional): start `copilot`, enter chat, then paste:

```text
Check Lab-2-vibe-coding azure.yaml, src/research_agent/agent.yaml, and src/research_agent/agent.manifest.yaml.
Requirements: host=azure.ai.agent, docker.remoteBuild=true, model uses ${AZURE_AI_MODEL_DEPLOYMENT_NAME}, no infra.
```

Ask Copilot to format the answer as:

```text
List results in OK / Risk / Fix columns. Risk should include only issues that affect azd deploy or hosted runtime.
```

## 3.5 Publish

Run from `Lab-2-vibe-coding`.

**Windows (PowerShell)**

```powershell
. ..\scripts\Windows\load-env.ps1
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
azd deploy research-agent
```

**macOS / Linux (bash)**

```bash
source ../scripts/macOSLinux/load-env.sh
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
azd deploy research-agent
```

After deployment, the postdeploy hook grants `AcrPull` and `Azure AI User` again to the latest runtime identities. This must happen for each new version, and the script is idempotent.

## 3.6 Verify the Hosted Endpoint

### Graphical Multi-turn Chat (Recommended)

**Windows (PowerShell)**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux (bash)**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

Sample prompts:

- `Research the consumer AI note-taking app category and compare five key players in 2025.`
- `For the second company you mentioned, find two negative reviews.`
- `Is Company X worth investing in?` (should trigger a guardrail refusal)

### Command-line Verification

**Windows (PowerShell)**

```powershell
..\scripts\Windows\invoke-hosted.ps1 `
  -Prompt "Research the consumer AI note-taking app category and compare five key players in 2025."
```

**macOS / Linux (bash)**

```bash
../scripts/macOSLinux/invoke-hosted.sh \
  --prompt "Research the consumer AI note-taking app category and compare five key players in 2025."
```

The result should match the local version's business JSON.

### Local vs Hosted Comparison

If the Lab 2 local service is still running, ask Copilot to design an apples-to-apples comparison:

```text
I want to compare local http://localhost:8087/responses with hosted invoke-hosted output. Give me a minimal verification set: one successful business prompt, one multi-turn context prompt, one guardrail refusal prompt, and expected differences.
```

Do not require exact text equality. Focus on field structure, citation strategy, refusal boundaries, and tool-use intent.

## 3.7 Status Check

**Windows (PowerShell)**

```powershell
..\scripts\Windows\invoke-hosted.ps1 -StatusOnly
..\scripts\Windows\sanity-check.ps1
```

**macOS / Linux (bash)**

```bash
../scripts/macOSLinux/invoke-hosted.sh --status-only
../scripts/macOSLinux/sanity-check.sh
```

## 3.8 Exit Checkpoint

- `azd deploy research-agent` completes without errors.
- Hosted `/responses` returns updated business JSON.
- Key `sanity-check.*` items pass.
- Call the hosted agent a few times before Lab 4 so Monitor metrics has data.
- Copilot can explain whether this release changed only business code or also changed model, server-side tools, or resource configuration.

## 3.9 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd deploy` reports missing variables | Go back to Lab 1 §1.4 and sync azd env, especially `AZURE_AI_PROJECT_ID` |
| ACR remote build is slow | First build is slower; later layers are reused |
| Hosted call returns 401 | Check `FOUNDRY_API_KEY` and project endpoint |
| Hosted call returns server error | Paste the error body into Copilot; wait 1-2 minutes for postdeploy RBAC propagation, and rerun `azd deploy research-agent` if needed |
| Instructions file not found | `agent.manifest.yaml.instructions.file` is relative to the manifest itself; default should be `../../personas/research-agent.md` |
| Quota / capacity error | Shared model deployment is busy; retry later or contact the instructor |

## 3.10 Bonus Challenges

1. Enable an instructor-configured server-side tool, such as Bing grounding, in `agent.manifest.yaml`.
2. Change a tool's mock/live behavior and redeploy, then compare hosted output differences.
3. Use Copilot to generate a bring-your-own business agent, then point `azure.yaml` to the new service and publish it.

→ [Lab 4 · Local observability](../Lab-4-observability/README.en.md)