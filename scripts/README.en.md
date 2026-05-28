# Workshop Utility Scripts

> Utilities used by students and instructors across Labs 0-4. **Windows uses PowerShell (`*.ps1`), while macOS / Linux uses bash (`*.sh`).** The two sets map one-to-one and behave consistently.

## Directory Structure

```text
scripts/
├── Windows/         # PowerShell 7 (pwsh) / Windows PowerShell 5.1, UTF-8 BOM
├── macOSLinux/      # bash 3.2+ (compatible with default macOS bash), requires curl + jq
├── chat-hosted/     # Browser-based graphical chat UI loaded by chat-hosted.*
├── lint-persona.py  # Cross-platform; runs directly with Python 3
└── README.md
```

## Script Overview

| Purpose | Used in | Windows (`.ps1`) | macOS / Linux (`.sh`) |
|---------|---------|------------------|------------------------|
| Enable VS Code Copilot chatmodes/instructions/prompts and print skill entrypoints | Lab 0 | [Windows/install-maf-copilot-skills.ps1](./Windows/install-maf-copilot-skills.ps1) | [macOSLinux/install-maf-copilot-skills.sh](./macOSLinux/install-maf-copilot-skills.sh) |
| Load the workshop root `.env` into the current shell; other scripts also load it automatically | All | [Windows/load-env.ps1](./Windows/load-env.ps1) | [macOSLinux/load-env.sh](./macOSLinux/load-env.sh) |
| Validate `.env`, SP credentials, shared Foundry access, hosted agent reachability, and ACR push permission | Lab 1 / Lab 3 | [Windows/sanity-check.ps1](./Windows/sanity-check.ps1) | [macOSLinux/sanity-check.sh](./macOSLinux/sanity-check.sh) |
| Invoke hosted agent `/responses` with api-key and append `response_id` to the Lab 4 index; `--status-only` checks reachability | Lab 1 / Lab 3 / Lab 4 | [Windows/invoke-hosted.ps1](./Windows/invoke-hosted.ps1) | [macOSLinux/invoke-hosted.sh](./macOSLinux/invoke-hosted.sh) |
| Open the local browser graphical chat UI in api-key mode | Lab 1 / Lab 3 | [Windows/chat-hosted.ps1](./Windows/chat-hosted.ps1) | [macOSLinux/chat-hosted.sh](./macOSLinux/chat-hosted.sh) |
| `azd deploy` postdeploy hook: grant AcrPull + Azure AI User to each per-version agent MI | Lab 1 / Lab 3 (automatic) | [Windows/grant-agent-runtime-roles.ps1](./Windows/grant-agent-runtime-roles.ps1) | [macOSLinux/grant-agent-runtime-roles.sh](./macOSLinux/grant-agent-runtime-roles.sh) |
| Validate persona frontmatter, `{{include}}` references, and required sections | Lab 2 | [lint-persona.py](./lint-persona.py) | [lint-persona.py](./lint-persona.py) |

> Lab 4 `fetch-traces.*` scripts live next to [Lab-4-observability/README.en.md](../Lab-4-observability/README.en.md). They query Azure Monitor metrics and generate `data/my-metrics.js`: Windows uses `fetch-traces.ps1`; macOS / Linux uses `fetch-traces.sh` (requires `curl` + `jq`).

## Usage Examples

### Windows (PowerShell)

```powershell
# Lab 0
.\scripts\Windows\install-maf-copilot-skills.ps1

# Lab 1 / Lab 3 post-deployment self-check
cd Lab-2-vibe-coding
..\scripts\Windows\sanity-check.ps1

# Lab 2 persona lint
python ..\scripts\lint-persona.py personas\research-agent.md

# Lab 3 hosted endpoint call
..\scripts\Windows\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"

# Open graphical chat
..\scripts\Windows\chat-hosted.ps1
```

### macOS / Linux (bash)

```bash
# Lab 0
./scripts/macOSLinux/install-maf-copilot-skills.sh

# Lab 1 / Lab 3 post-deployment self-check
cd Lab-2-vibe-coding
../scripts/macOSLinux/sanity-check.sh

# Lab 2 persona lint
python3 ../scripts/lint-persona.py personas/research-agent.md

# Lab 3 hosted endpoint call
../scripts/macOSLinux/invoke-hosted.sh \
    --agent-name "research-agent-${STUDENT_SUFFIX}" \
    --prompt "ping"

# Open graphical chat
../scripts/macOSLinux/chat-hosted.sh
```

> Bash scripts use long-form flags such as `--agent-name`, `--api-key`, `--status-only`, `--no-store`, and `--no-open`, matching PowerShell `-AgentName` / `-StatusOnly`. `load-env.sh` must be sourced to affect the current shell: `source ../scripts/macOSLinux/load-env.sh`.

## Cross-platform Notes

- **Windows**: `*.ps1` works in PowerShell 7 (`pwsh`) and Windows PowerShell 5.1. Scripts contain Chinese text and are saved with UTF-8 BOM for PS 5.1 compatibility.
- **macOS / Linux**: `*.sh` uses `#!/usr/bin/env bash`, compatible with bash 3.2+ (default macOS `/bin/bash`; no Homebrew bash required). Dependencies:
  - `curl`, `jq` (required; macOS: `brew install jq`, Debian/Ubuntu: `apt-get install jq`)
  - `base64`, `uuidgen` (system-provided)
  - `azd` (optional; only for `azd env get-value` fallback)
  - `code` (optional; only used by `install-maf-copilot-skills.sh` to detect extensions)
- **Credential source precedence** in both script sets: command-line arguments > process environment variables > workshop root `.env` > `azd env`.