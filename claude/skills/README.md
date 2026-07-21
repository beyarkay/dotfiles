# claude-skills

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for managing ML training infrastructure and experiment reporting.

## Skills

### RunPod (`runpod/`)

Manage [RunPod](https://www.runpod.io/) GPU pods and run LLM fine-tuning experiments remotely. Handles the full lifecycle: creating pods, SSHing in, copying files, launching training jobs (with tmux for long runs), monitoring GPU usage, and tearing down pods when done.

Supports multi-GPU parallel training and includes safety guardrails to avoid touching other users' pods on shared accounts.

### W&B Report Generator (`wandb-report/`)

Create [Weights & Biases](https://wandb.ai/) reports for experiment reviews. Follows a structured 3-phase workflow: gather context, draft an outline for approval, then generate the report via the `wandb_workspaces` API. Designed for producing clear, skimmable reports that lead with key findings.

## Getting Started

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- A RunPod account and API key (for the RunPod skill)
- A Weights & Biases account and API key (for the W&B skill)

### Installation

Clone this repo into your Claude Code skills directory:

```bash
git clone https://github.com/beyarkay/claude-skills.git ~/.claude/skills
```

If you already have a `~/.claude/skills` directory, clone it elsewhere and copy the skill folders in:

```bash
git clone https://github.com/beyarkay/claude-skills.git /tmp/claude-skills
cp -r /tmp/claude-skills/runpod ~/.claude/skills/
cp -r /tmp/claude-skills/wandb-report ~/.claude/skills/
```

### Configuration

**These skills were built for a specific local environment and contain hardcoded paths.** Before using them, you'll need to update the paths in each `SKILL.md` to match your own setup:

**RunPod skill** (`runpod/SKILL.md`):
- Update the `.env` source path to wherever you store your API keys (e.g. `RUNPOD_API_KEY`, `WANDB_API_KEY`)
- Update or replace the helper script paths (`runpod-ctl.sh`, `pod-ssh.sh`) — these scripts wrap `runpodctl` and SSH commands
- Change the resource naming convention (currently uses `-boyd-` as an identifier) to your own
- Update the Docker image, volume ID, and datacenter to match your RunPod setup
- Install [`runpodctl`](https://github.com/runpod/runpodctl) if you haven't already

**W&B Report skill** (`wandb-report/SKILL.md`):
- Ensure `WANDB_API_KEY` is available in your environment or in a `.env` file
- Install the `wandb` and `wandb_workspaces` Python packages: `pip install wandb wandb-workspaces`
- Update the entity and project names to match your W&B workspace

### Usage

Once installed and configured, the skills are automatically available in Claude Code. You can invoke them by describing what you want:

- *"Create a RunPod instance and start a training run"*
- *"Check the status of my RunPod pods"*
- *"Create a W&B report comparing my last 5 runs"*
- *"Stop my RunPod pod"*

Claude Code will match your request to the appropriate skill and follow the instructions defined in the skill's `SKILL.md`.

## Structure

```
~/.claude/skills/
├── README.md
├── LICENSE
├── runpod/
│   └── SKILL.md        # RunPod management instructions
└── wandb-report/
    └── SKILL.md        # W&B report generation instructions
```

Each skill is a directory containing a `SKILL.md` file with YAML frontmatter (name and description) followed by detailed instructions that Claude Code follows when the skill is activated.

## License

MIT
