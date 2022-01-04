#!/bin/bash
# ==========================================================================
# Tmux Save
#
# This script will take all your current tmux sessions, their windows, and
# their panes, and write to a file the correct tmux commands to recreate the
# setup you've currently got. In short, it saves your current tmux state to
# file.
# ==========================================================================

TMUX_SAVE_FILE="/Users/boydkane/restore_tmux.sh"

# Loop over all tmux sessions
while IFS= read -r curr_sess; do
    echo "# ===================================="
    echo "# Create new session called $curr_sess"
    echo "# ===================================="
    echo "tmux new-session $curr_sess -d"

    # For each tmux session, loop over each window
    echo ""
    echo "# -------------------------------------------"
    echo "# Creating new windows for session $curr_sess"
    echo "# -------------------------------------------"
    while IFS= read -r curr_wind; do
        echo "tmux -t $curr_sess new-window $curr_wind -d"

        # For each tmux window, loop over each pane
        echo ""
        echo "# Creating new panes for window $curr_wind, session $curr_sess"
        while IFS= read -r curr_pane; do
            echo "Create pane somehow:  $curr_pane"
        done < <(tmux list-panes -t $curr_wind)
        echo ""
    done < <(tmux list-windows -t $curr_sess -F "#{window_name}")
    echo ""
done < <(tmux list-sessions -F "#{session_name}")
