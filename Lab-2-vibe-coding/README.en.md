# Lab 2 · GitHub Copilot + Agent Framework Vibe Coding (30 min)

Lab 1 has already deployed the built-in `research-agent` to Foundry. In Lab 2, you iterate on business capability locally: first understand the default market and competitive research scenario, then optionally ask Copilot to generate or modify persona, skill, and tool files. Lab 3 publishes the updated version.

## 2.1 Goals

- Understand the **Soul / Persona · Skills · Tools** trio.
- Use Copilot to generate or modify the trio.
- Run `/responses` locally with `agentdev run`.
- Optionally replace the default research assistant with your own business agent.

## 2.2 Agent-driven Workflow

Lab 2 is the core vibe-coding part of the workshop. Do not ask Copilot to “rewrite the whole agent” in one shot. Split the work into persona, skill, tool, local run, and reflection milestones. Use the same rhythm for each milestone:

| Stage | You do | Copilot coding agent does |
|-------|--------|---------------------------|
| Brief | State the business goal, non-goals, and expected output | Restate the goal and point to relevant files |
| Ask | Use `/persona`, `/skill`, `/tool`, or an `@workspace` prompt | Generate or modify the smallest necessary files |
| Inspect | Review the diff and decide whether it makes business sense | Explain how the change maps to the persona contract or tool schema |
| Verify | Run lint, unit tests, `agentdev run`, and HTTP POST | Summarize results and attribute failures |
| Reflect | Decide whether to move to the next milestone | Suggest next steps and rollback options |

Starter prompt:

```text
@workspace I am working on Lab 2. First read #file:Lab-2-vibe-coding/README.md, #file:personas/research-agent.md, #file:skills/market-research/SKILL.md, #file:tools/web_search.py, and #file:src/research_agent/main.py.
This round should do only one mini-milestone. Tell me the goal, relevant files, verification command, and completion signal.
```

## 2.3 Working with Copilot

| Task | VS Code path (main) | Copilot TUI path (optional) |
|------|---------------------|-----------------------------|
| Generate / edit persona | `/persona agentName=… role=… boundaries=…` | Run `copilot`, then paste `.github/prompts/persona.prompt.md` plus parameters into chat |
| Generate / edit SKILL.md | `/skill skillName=… purpose=…` | Paste `skill.prompt.md` plus parameters |
| Generate / edit tool | `/tool toolName=… inputs=… outputs=…` | Paste `tool.prompt.md` plus parameters |
| Explain SDK / hosted tools | Ask chat directly; keywords will activate `.agents/skills/agent-framework-azure-ai-py/` | Paste the relevant `SKILL.md` content into TUI chat |

## 2.4 Default Scenario: Market / Competitive Research Assistant

```text
Input: a product / category / company
   │
   ▼
[ResearchAgent]
   ├─ Break down 3-7 sub-questions
   ├─ web_search       Multi-keyword, multi-source search
   ├─ web_fetch        Fetch body text + remove HTML
   └─ report_builder   Validate citations + output structured JSON
   ▼
Output: markdown report with footnotes + sources array + confidence rating
```

Core files:

- `personas/research-agent.md`: role, boundaries, output contract.
- `personas/shared/guardrails.md`: shared refusal and safety boundaries.
- `skills/market-research/SKILL.md`: research workflow.
- `tools/*.py`: Agent Framework `@tool` functions.
- `src/research_agent/main.py`: wires persona, skills, and tools into the agent.

## 2.5 Code Directory Overview

```text
Lab-2-vibe-coding/
├── azure.yaml                         # azd deploy entrypoint
├── hooks/postdeploy-grant-roles.ps1   # azd postdeploy wrapper
├── personas/
│   ├── shared/guardrails.md
│   └── research-agent.md
├── skills/
│   ├── market-research/SKILL.md
│   └── citation-format/SKILL.md
├── tools/
│   ├── web_search.py
│   ├── web_fetch.py
│   └── report_builder.py
├── src/research_agent/
│   ├── main.py
│   ├── agent.yaml
│   ├── agent.manifest.yaml
│   ├── Dockerfile
│   └── requirements.txt
├── tests/unit/
├── .github/                           # VS Code Copilot customization
├── requirements.txt
└── pyproject.toml
```

## 2.6 Mini-milestones

### M1 · Persona / Soul (5 min)

**Brief**: Confirm the agent role, refusal boundaries, tool-use rules, and JSON output contract. The default scenario does not require edits; only bring-your-own scenarios generate a new persona.

**Ask Copilot**:

```text
@workspace Check #file:personas/research-agent.md and #file:personas/shared/guardrails.md.
Explain this persona's role, refusal boundaries, tool order, and output contract. Do not modify files.
```

The default scenario is already written. Run lint first:

```powershell
python ..\scripts\lint-persona.py personas\research-agent.md
```

```bash
python3 ../scripts/lint-persona.py personas/research-agent.md
```

For a bring-your-own scenario, ask Copilot to generate a new persona, for example:

```text
/persona agentName=invoice-explainer role="invoice explanation assistant" boundaries="do not fetch live exchange rates; do not provide tax advice; extract facts only from the invoice text supplied by the user" tools="ocr_extract, classify_charges, currency_normalize" contract="{lineItems, totalsByCategory, suspiciousFlags}"
```

**Inspect**: Confirm frontmatter has `name`, `version`, `owner`, and `extends`; the body references `{{include: shared/guardrails.md}}`; and tool names match the planned tools.

**Verify**: Run `lint-persona.py` again after generation.

**Reflect**: Ask Copilot:

```text
Map each persona boundary to a testable prompt, and indicate which prompts should be refused and which should call tools.
```

### M2 · Skill (5 min)

**Brief**: A skill is a workflow instruction, not code. It tells the model when to trigger, what order to follow, and how to degrade on failure.

**Ask Copilot**:

```text
@workspace Read #file:skills/market-research/SKILL.md and #file:personas/research-agent.md.
Check whether the skill steps support the persona output contract. If you find conflicts, propose only minimal changes.
```

For the default scenario, read `skills/market-research/SKILL.md`. For your own business scenario, use:

```text
/skill skillName=invoice-explain purpose="explain an uploaded invoice step by step" triggers="the user uploads invoice image or text; the user asks where each charge went" tools="ocr_extract, classify_charges, currency_normalize" relatedSkills="citation-format"
```

**Inspect**: A good `SKILL.md` includes triggers, steps, tool usage, and failure/refusal boundaries.

**Verify**: Ask Copilot to walk through 2 success prompts and 1 refusal prompt, confirming it does not skip required citations or schema checks.

**Reflect**: If the skill and persona disagree, prefer editing the skill. Persona should express durable identity and boundaries.

### M3 · Client-side Tools (8 min)

**Brief**: A tool is the callable boundary for the model. In the classroom, tools must be mockable, testable, and observable; external API failure should not block the entire lab.

**Ask Copilot**:

```text
@workspace Reference #file:tools/web_search.py, #file:tools/web_fetch.py, #file:tools/report_builder.py, and #file:.github/instructions/maf-tools.instructions.md.
Check whether existing tools meet classroom requirements for input/output, mock fallback, timeout, and OTel spans.
```

Default tools already live under `tools/`. When generating a new tool, use:

```text
/tool toolName=ocr_extract purpose="extract text from image or PDF" inputs="image_url: HttpUrl, lang: str='auto'" outputs="text: str, blocks: list[dict], pages: int" liveBackend="Azure Computer Vision Read API" envKey="AZURE_VISION_KEY"
```

Requirements:

- Define inputs and outputs clearly with Pydantic.
- Use `@tool(description=...)` to explain when the model should call it.
- Include mock fallback so classroom network or external APIs do not block progress.
- Add reasonable timeouts and do not swallow exceptions.

**Inspect**: Confirm the new tool has no hard-coded keys, returns diagnosable errors, and has a concrete enough description for the model to choose it.

**Verify**:

```powershell
pytest tests/unit/test_tools.py
```

If you only changed a new tool and there is no unit test yet, ask Copilot to generate a mock-path test and run the relevant test.

**Reflect**: Ask Copilot which failures come from external services and which come from schema or prompt design, so you do not misdiagnose network problems as agent logic problems.

### M4 · Local Assembly + Run (8 min)

**Brief**: Wire persona, skills, and tools into `src/research_agent/main.py`, then use `agentdev run` to verify the full `/responses` protocol locally.

**Ask Copilot**:

```text
@workspace Explain how #file:src/research_agent/main.py loads persona, SkillsProvider, and tools.
If I switch to my own business agent, tell me the minimum imports, tool list, and persona filename changes.
```

**Windows (PowerShell)**

```powershell
cd Lab-2-vibe-coding
pip install -r requirements.txt
. ..\scripts\Windows\load-env.ps1
agentdev run src\research_agent\main.py --port 8087
```

In a second terminal:

```powershell
$body = @{ input = "Research the consumer AI note-taking app category and compare five key players in 2025." } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

**macOS / Linux (bash)**

```bash
cd Lab-2-vibe-coding
pip install -r requirements.txt
source ../scripts/macOSLinux/load-env.sh
agentdev run src/research_agent/main.py --port 8087
```

In a second terminal:

```bash
curl -s -X POST http://localhost:8087/responses \
  -H "Content-Type: application/json" \
  -d '{"input":"Research the consumer AI note-taking app category and compare five key players in 2025."}' | jq .
```

Expected output is JSON matching the persona output contract, at least including `report`, `sources`, and `confidence`.

**Inspect**: If the response runs but has the wrong structure, paste it into Copilot and ask it to compare against `personas/research-agent.md`.

**Verify**: In addition to the success sample, run one refusal sample to confirm guardrails still apply locally.

### M5 · Inspector + Reflection (4 min)

**Brief**: Inspector is not a demo toy; it verifies whether the model followed persona/skill/tool agreements.

```text
agentdev inspect
```

In the browser, send a prompt that should be refused:

```text
Is Company X worth investing in? Buy or sell?
```

Expected result: the persona refuses investment advice according to guardrails. Give the Inspector span or screenshot to Copilot and ask why it did not continue calling tools.

**Reflect prompt**:

```text
Here is the Inspector span / screenshot text. Explain:
1. Which step called the model
2. Which tools were called or skipped
3. Whether the result satisfies the persona contract
4. What still needs fixing before Lab 3
```

## 2.7 Mock Mode

When `BING_SEARCH_API_KEY` / `GOOGLE_CSE_*` are missing, `web_search` automatically falls back to local mock data. Set `WORKSHOP_WEB_FETCH_FORCE_MOCK=1` to force `web_fetch` into mock mode. Enable both to do fully offline vibe coding.

Ask Copilot to confirm the offline path:

```text
@workspace Check the mock fallback for web_search and web_fetch. Tell me whether local Lab 2 can still complete an end-to-end demo without external search keys.
```

## 2.8 Minimal Bring-your-own-business Changes

1. Copy or generate `personas/<agent>.md`.
2. Describe the workflow in `skills/<skill>/SKILL.md`.
3. Write an `@tool` in `tools/<tool>.py`.
4. Create `src/<agent>/main.py` using `src/research_agent/main.py` as a reference.
5. Use `/deploy` to generate matching `agent.yaml` and `agent.manifest.yaml`.

Do not hard-code keys. All configuration must come from `.env` / environment variables.

## 2.9 Deploy to Foundry (Lab 3)

Lab 1 has already initialized and synced azd env. After Lab 2 changes, you only need:

**Windows (PowerShell)**

```powershell
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
azd deploy research-agent
..\scripts\Windows\invoke-hosted.ps1 -Prompt "ping"
```

**macOS / Linux (bash)**

```bash
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
azd deploy research-agent
../scripts/macOSLinux/invoke-hosted.sh --prompt "ping"
```

See [../Lab-3-update-hosted-agent/README.en.md](../Lab-3-update-hosted-agent/README.en.md).

## 2.10 Exit Checkpoint

- Persona lint passes.
- `agentdev run` starts without errors.
- Local POST `/responses` returns business JSON.
- If you changed a tool, there is a unit test or at least one local mock/live call verification.
- Copilot can explain how local behavior differs from the Lab 1 hosted version.

## 2.11 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `FoundryChatClient` 401 | Confirm `. ..\scripts\Windows\load-env.ps1` or `source ../scripts/macOSLinux/load-env.sh` has been run; the SP needs `Azure AI User` on the shared project |
| `agentdev run` port conflict | Use `--port 8088` |
| Copilot output does not follow conventions | Explicitly reference `.github/instructions/maf-*.instructions.md` in the prompt |
| Model does not call the tool | Check whether `@tool(description=...)` is specific enough and the input schema is clear |
| Skill not loaded | `SKILL.md` must live at `skills/<skill-name>/SKILL.md` |

Before leaving this directory, ask Copilot for a summary:

```text
Summarize which persona/skill/tool/runtime files I changed in Lab 2, which verifications passed, and the 3 most likely failure points for Lab 3 deployment.
```

→ [Lab 3 · Push the local agent to hosted](../Lab-3-update-hosted-agent/README.en.md)