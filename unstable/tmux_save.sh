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
while IFS= read -r curr_sess_id; do
    curr_sess_name=$(tmux list-sessions -F "#{session_id} #{session_name}" | \grep \'$curr_sess_id\' | cut -d' ' -f 2)
    echo "# ===================================="
    echo "# Create new session called $curr_sess_name"
    echo "# ===================================="
    echo "tmux new-session $curr_sess_name -d"

    # For each tmux session, loop over each window
    # echo ""
    # echo "# -------------------------------------------"
    # echo "# Creating new windows for session $curr_sess_name"
    # echo "# -------------------------------------------"
    # while IFS= read -r curr_wind_id; do
    #     curr_wind_name=$( tmux display-message -t $curr_wind_id -p "#{window_name}" )

    #     echo "tmux -t $curr_sess_id new-window $curr_wind_id -d"

    #     # For each tmux window, loop over each pane
    #     echo ""
    #     echo "# Creating new panes for window $curr_wind_id, session $curr_sess_id"
    #     while IFS= read -r curr_pane; do
    #         echo "tmux split-window -t $curr_wind_id"
    #     done < <(tmux list-panes -t $curr_sess_id:$curr_wind_id -F "#{pane_id}" )

    #     layout=$( tmux display-message -t $curr_wind_id -p "#{window_layout}" )
    #     echo "tmux select-layout $layout"
    #     echo ""
    # done < <(tmux list-windows -t $curr_sess_id -F "#{window_id}")
    # echo ""
done < <(tmux list-sessions -F "#{session_id}")

