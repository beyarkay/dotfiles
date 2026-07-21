---
name: tmux-run
description: Run a shell command in a specified tmux pane and return the pane's output. Use when user asks to run something in a tmux pane, send a command to tmux, or check tmux pane output.
---

# tmux-run

Run a shell command in a tmux pane and capture the immediate output.

## Usage

```bash
$HOME/.claude/skills/tmux-run/tmux-run.sh <pane> <command...>
```

- **pane**: tmux target pane (e.g. `0:0.1`, `main:0.0`, `%3`). If not specified by the user, ask.
- **command**: the shell command to run

The script wraps the command with sentinels, sends it via `tmux send-keys`, waits 0.1s, then captures the pane to extract new output and the exit code.

## Output

- If the command finishes within 0.1s: shows output + `--- exited: N ---`
- If still running: shows partial output + `--- still running ---`

## Notes

- If the pane is in an interactive program (vim, less, python REPL), warn the user before sending keys — commands can get swallowed.
- For long-running commands, tell the user it was sent and offer to check back later with `tmux capture-pane -t PANE -p -S -200`.
