# Copilot MAF Skills

> Adds the context needed for “market research agent vibe coding” to the student's VS Code Copilot experience. These files are shipped with the workshop repository and are automatically recognized by Copilot.

## Auto-load Locations

When VS Code Copilot Chat opens a workspace, it reads these files from the workspace root:

- `.github/agents/*.agent.md` (this workshop currently uses `*.chatmode.md` filenames) — custom agent modes (switch from the top dropdown)
- `.github/instructions/*.instructions.md` — injected into Copilot context based on `applyTo` globs
- `.github/prompts/*.prompt.md` — `/<slug>` slash commands

In Lab 0, students `cd` into `Lab-2-vibe-coding` and run `code .`; all files in this directory then become active.

## Provided Skills

| File | Type | Trigger |
|------|------|---------|
| `agents/maf-agent.chatmode.md` | agent mode | Select "maf-agent" from the Copilot Chat dropdown |
| `instructions/maf-tools.instructions.md` | instructions | Auto-injected while editing `tools/**/*.py` |
| `instructions/maf-personas.instructions.md` | instructions | Auto-injected while editing `personas/**/*.md` |
| `instructions/maf-skills.instructions.md` | instructions | Auto-injected while editing `skills/**/SKILL.md` |
| `prompts/persona.prompt.md` | prompt | Type `/persona` in Chat |
| `prompts/skill.prompt.md` | prompt | Type `/skill` in Chat |
| `prompts/tool.prompt.md` | prompt | Type `/tool` in Chat |
| `prompts/deploy.prompt.md` | prompt | Type `/deploy` in Chat |

## Enable VS Code Settings (if not already enabled)

VS Code 1.95+ enables agents/prompts/instructions by default. If you do not see them, run:

**Windows (PowerShell)**

```powershell
..\..\scripts\Windows\install-maf-copilot-skills.ps1
```

**macOS / Linux (bash)**

```bash
../../scripts/macOSLinux/install-maf-copilot-skills.sh
```

The script will:

1. Check VS Code and Copilot extension versions.
2. Write `.vscode/settings.json` to enable `chat.promptFiles` / `chat.modeFiles` / `chat.instructionsFiles`.
3. Open VS Code in the current directory.

## Rewrite the Default Scenario

To adapt the skills to your own business domain:

- Replace the "Default scenario" at the top of `agents/maf-agent.chatmode.md`.
- Usually keep `instructions/*` unchanged; they are the convention layer.
- Update `prompts/*.prompt.md` input fields and examples.