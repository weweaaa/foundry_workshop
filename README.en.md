# GitHub Copilot + Microsoft Foundry Hosted Agent · 90min Hands-on Workshop

> In 90 minutes, you will use 5 labs to build a Microsoft Foundry hosted agent that can be **deployed, invoked, and observed**, then use GitHub Copilot to iterate on its persona, skills, and tools.
>
> Students do not create Azure infrastructure. The instructor pre-provisions the shared Foundry account, project, model deployment, and ACR. Each student only deploys their own hosted agent named with `STUDENT_SUFFIX`.

## Language Versions

- Simplified Chinese: [README.md](README.md)
- Traditional Chinese: [README.zh-TW.md](README.zh-TW.md)
- English: [README.en.md](README.en.md)

## Workshop Collaboration Model

This is not a “copy commands from a document” lab. Every step follows the same coding-agent-driven loop:

1. **Brief**: the human states the goal, business boundary, and acceptance signal.
2. **Ask Copilot**: GitHub Copilot coding agent reads the relevant files, explains the current structure, and proposes the next step.
3. **Run / Edit**: Copilot helps run checks, generate scaffolding, or edit files; the key commands remain visible for human review.
4. **Verify**: scripts, HTTP calls, lint, or the dashboard prove that the result works.
5. **Reflect**: Copilot summarizes differences, failures, and next steps instead of stopping at “the command ran”.

Humans own intent, business judgment, safety boundaries, and final acceptance. Copilot owns codebase exploration, candidate changes, command execution, error attribution, and verification summaries. Each lab gives a clear handoff prompt and completion signal.

## 30-second Start

**Windows (PowerShell)**

```powershell
git clone https://github.com/ITD-NextDimension/foundry_workshop.git
cd foundry_workshop

Copy-Item .env.example .env
notepad .env      # Fill in the SP, Foundry endpoint/API key, ACR, and STUDENT_SUFFIX from the instructor

code Lab-0-setup\README.en.md
```

**macOS / Linux (bash)**

```bash
git clone https://github.com/ITD-NextDimension/foundry_workshop.git
cd foundry_workshop

cp .env.example .env
${EDITOR:-nano} .env

code Lab-0-setup/README.en.md
```

Key conventions:

- Keep exactly one `.env` file at the repository root; scripts load it automatically.
- `chat-hosted.*`, `invoke-hosted.*`, and `sanity-check.*` use the Foundry `api-key` or OAuth2 REST and do not require `az login`.
- `azd deploy` still requires `azd auth login`; Lab 1 syncs deployment variables from `.env` into the current azd environment.
- Do not run `azd up` or `azd provision`; this workshop has no student-side infrastructure.

## Repository Layout

```text
foundry_workshop/
├── README.md
├── .env.example                    # Copy to .env; used by the whole workshop
├── scripts/
│   ├── Windows/                    # PowerShell 7 / Windows PowerShell 5.1
│   ├── macOSLinux/                 # bash 3.2+, requires curl + jq
│   ├── chat-hosted/index.html      # Local graphical chat UI
│   └── lint-persona.py
├── Lab-0-setup/                    # Tools, credentials, Copilot, azd auth
├── Lab-1-deploy-hosted-agent/      # First deployment of research-agent to shared Foundry
├── Lab-2-vibe-coding/              # Main local business-agent codebase
│   ├── azure.yaml                  # azd deploy entrypoint, no infra
│   ├── hooks/postdeploy-grant-roles.ps1
│   ├── personas/
│   ├── skills/
│   ├── tools/
│   ├── src/research_agent/
│   ├── tests/unit/
│   └── .github/                    # Copilot agents / instructions / prompts
├── Lab-3-update-hosted-agent/      # Redeploy local changes to the hosted agent
└── Lab-4-observability/            # Local HTML + Azure Monitor metrics
```

## Opening Architecture Overview

A production-ready agent is more than “a prompt plus a model”. This workshop uses a lightweight harness that splits the agent into versionable, deployable, and observable pieces:

- **Soul / Persona**: role boundaries, tone, refusal policy → `Lab-2-vibe-coding/personas/*.md`
- **Skills**: step-by-step task instructions → `Lab-2-vibe-coding/skills/<skill>/SKILL.md`
- **Tools**: functions that call external APIs or write state → `Lab-2-vibe-coding/tools/*.py`
- **Runtime**: model + container + routing → Microsoft Foundry Hosted Agent

```text
L3 App layer     Hosted Agent container = Agent Framework app     ← Labs 2/3
                 ├── instructions ← personas/*.md
                 ├── context_providers=[SkillsProvider]
                 ├── tools=[client-side @tool]
                 └── client = FoundryChatClient

L2 Model/tool layer  Foundry server-side tools + model deployment ← Instructor pre-provisions
L1 Shared infra      Foundry account / project / model / ACR      ← Students do not change
```

The default scenario is a market and competitive research assistant. To move fast, use the default `research-agent`. To bring your own business scenario, use `/persona`, `/skill`, and `/tool` in Lab 2 to create your own three-part harness.

## What You Will Be Able To Do

1. Deploy an Agent Framework Python agent to the shared Foundry project with `azd deploy research-agent`.
2. Iterate on **Soul / Persona + Skills + Tools** with GitHub Copilot. The main classroom path is VS Code Copilot Chat; terminal TUI is only an optional fallback.
3. Debug the business agent locally with `agentdev run`, then publish the modified version to the hosted slot.
4. Invoke the hosted `/responses` endpoint with `api-key`, and use a local graphical chat UI for multi-turn conversations.
5. Use the Lab 4 local dashboard to inspect AgentResponses, tokens, tool calls, model latency, and related operational metrics.

## Timeline (90 min)

| # | Segment | Duration | Exit artifact |
|---|---------|----------|---------------|
| 0 | [Opening architecture overview](#opening-architecture-overview) | 5 min | Understand shared Foundry, the harness, and human/agent roles |
| 1 | [Lab 0 · Setup, credentials, and Copilot](Lab-0-setup/README.en.md) | 10 min | Readiness check says you can enter Lab 1 |
| 2 | [Lab 1 · First hosted-agent deployment](Lab-1-deploy-hosted-agent/README.en.md) | 15 min | Hosted endpoint returns 200 OK; Copilot can explain the deployment path |
| 3 | Buffer | 5 min | — |
| 4 | [Lab 2 · Copilot vibe coding](Lab-2-vibe-coding/README.en.md) | 30 min | Local agent returns business JSON; persona/skill/tool validation is recorded |
| 5 | [Lab 3 · Update hosted agent](Lab-3-update-hosted-agent/README.en.md) | 10 min | Hosted endpoint returns updated business JSON; local vs hosted behavior is understood |
| 6 | [Lab 4 · Local observability](Lab-4-observability/README.en.md) | 10 min | Dashboard shows your metrics and you can explain metric ownership |
| 7 | [Wrap-up](#wrap-up--next-steps) | 5 min | Next learning path |

## Copilot Environments

The classroom main path is **VS Code GitHub Copilot**. It automatically reads the `Lab-2-vibe-coding/.github/` agents, instructions, and prompts. The terminal `copilot` TUI is only an optional fallback for students who cannot use VS Code Chat. Do not turn it into an old command-suggestion/explanation workflow.

| Environment | Entry | Best for |
|-------------|-------|----------|
| VS Code Copilot Chat (recommended) | After Lab 0 installs customization, open `Lab-2-vibe-coding/`, select the `maf-agent` agent mode, and use `/persona`, `/skill`, `/tool`, `/deploy` | Multi-file generation and edits |
| Copilot TUI (optional) | Run `copilot` in the terminal, enter chat, and paste the lab prompt or template content | Fallback conversation path when VS Code Chat is unavailable |

Both environments can use the official skills under the repository root `.agents/skills/`:

- `microsoft-foundry` — hosted agent deployment, invocation, observability, evaluation, RBAC, quotas
- `agent-framework-azure-ai-py` — Agent Framework Python SDK
- `azure-ai-projects-py` — Azure AI Projects SDK
- `skill-creator` — creating and revising custom skills

## If You Get Stuck

- Run the relevant self-check first: Windows `scripts\Windows\sanity-check.ps1`, macOS / Linux `scripts/macOSLinux/sanity-check.sh`.
- For deployment failures, only troubleshoot `azd deploy research-agent`; do not modify the shared Foundry project or ACR.
- Only operate on your own `research-agent-<STUDENT_SUFFIX>` resource; do not delete or update other students' agents.

## Cheat Sheet

### Copilot Prompts

Starter prompt for every lab:

```text
@workspace I am working on Lab <N>. First read this lab's README and the scripts/config files it references.
Answer these 4 things:
1. What must the human confirm?
2. What can you check, run, or edit?
3. What is the completion signal?
4. What is the minimal troubleshooting order if it fails?
```

Ask Copilot to read before acting:

```text
@workspace Read only first; do not edit files. Read #file:<path1> #file:<path2>, then summarize the current state, risks, and next verification command.
Wait for my confirmation before making changes.
```

When verification fails:

```text
Here is the command output. Do not give generic reinstall advice.
Based on this workshop's constraints, decide whether the failure is credentials, azd env, Foundry RBAC, agent runtime, or code logic. Give the smallest fix and the verification command to rerun afterward.
```

### PowerShell Notes

- When signing in to `azd` with a service principal, use `--client-secret=$Secret` or `--client-secret=$env:AZURE_CLIENT_SECRET` so Windows PowerShell 5.1 does not swallow the secret as a parameter prefix.
- This workshop does not run `azd up`, `azd provision`, or `azd down`. Use only `azd deploy research-agent`.
- For manual hosted-agent calls, prefer `scripts/Windows/invoke-hosted.ps1`; it wraps the api-key, URL construction, and response indexing.

### Foundry Hosted Agent API / Metrics

- Hosted `/responses` URL: `<endpoint>/agents/<agent-name>/endpoint/protocols/openai/responses?api-version=2025-11-15-preview`
- Daily invocation: `scripts/Windows/invoke-hosted.ps1 -Prompt "ping"` or `scripts/macOSLinux/invoke-hosted.sh --prompt "ping"`
- Lab 4 metrics use Azure Monitor REST API, not the Foundry api-key. The script exchanges the SP credentials for an ARM token.
- `AgentResponses` can be split by `AgentId`; `AgentInputTokens`, `AgentOutputTokens`, and `AgentToolCalls` are shown at project scope in this workshop.

## Wrap-up · Next Steps

Today you completed an agent iteration loop:

```text
Soul / Persona + Skills + Tools
  ↓ local debugging with agentdev run
Foundry Hosted Agent: research-agent-<STUDENT_SUFFIX>
  ↓ operational metrics flow into Azure Monitor
Lab 4 local dashboard
```

Bring the same pattern back to your team: Brief → Ask Copilot → Inspect diff → Verify → Reflect.

Possible next steps:

- **Evaluation loop**: turn real invocations into evaluation datasets, run batch eval, compare versions, then improve prompt / persona.
- **Multi-agent orchestration**: connect multiple specialized agents with workflows or connected agents.
- **MCP server**: wrap internal capabilities as MCP and reference them in `agent.manifest.yaml`.
- **CI/CD**: run smoke eval or regression eval in PRs or nightly jobs.

Related links:

- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Hosted Agents](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [`azd ai agent` extension](https://aka.ms/azdaiagent/docs)
- [Foundry Samples (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [GitHub Copilot in VS Code](https://aka.ms/vscode-copilot)
- [GitHub Copilot in the terminal](https://docs.github.com/copilot/github-copilot-in-the-cli)