#!/usr/bin/env bash
# tmux-run.sh — Send a command to a tmux pane and return the new output.
# Usage: tmux-run.sh <pane> <command...>
# Example: tmux-run.sh 0:0.1 ls -la
#
# Wraps the command with sentinels in a single line so we can extract
# exactly the new output and exit code.

set -uo pipefail

PANE="$1"
shift
CMD="$*"

TAG="__TR_$$"
START="${TAG}_S"
END="${TAG}_E"

# Verify pane exists
if ! tmux has-session -t "$PANE" 2>/dev/null; then
    echo "ERROR: pane '$PANE' not found. Available panes:"
    tmux list-panes -a -F "  #{session_name}:#{window_index}.#{pane_index}  (#{pane_current_command})"
    exit 1
fi

# Send everything as one line: start sentinel, command, end sentinel with exit code
# Using ; to chain so it's a single shell command line
tmux send-keys -t "$PANE" "echo ${START}; ${CMD}; echo ${END}:"'$?' Enter

# Wait for the command to (maybe) finish
sleep 0.1

# Capture pane
OUTPUT=$(tmux capture-pane -t "$PANE" -p -S -500)

# Extract: lines starting with sentinel are output lines, not the typed command
if echo "$OUTPUT" | grep -q "^${END}:"; then
    # Command finished
    echo "$OUTPUT" \
        | sed -n "/^${START}\$/,/^${END}:/p" \
        | grep -v "^${START}$" \
        | grep -v "^${END}:"
    EXIT_CODE=$(echo "$OUTPUT" | grep "^${END}:" | head -1 | sed "s/^${END}://")
    echo "--- exited: ${EXIT_CODE} ---"
elif echo "$OUTPUT" | grep -q "^${START}$"; then
    # Command still running
    echo "$OUTPUT" \
        | sed -n "/^${START}\$/,\$p" \
        | grep -v "^${START}$" \
        | grep -v "^.*❯ "
    echo "--- still running ---"
else
    echo "--- sent, waiting for output ---"
fi
