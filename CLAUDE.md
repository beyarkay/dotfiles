# HI CLAUDE

can you see this? let me know if you can, i'm not sure if it's working

## Preferred tools

Rust, `uv`, `ty`

## Interactive editing: `drop-user-in-file`

`~/.claude/tools/drop-user-in-file PATH [LINE]` drops the user into an
interactive nvim session at PATH:LINE, pauses Claude until they `:q`, then
prints the before/after unified diff. Invoke it via Bash when the user wants
to hand-edit a file mid-session (or asks to be "dropped into" a file).

- Requires tmux (it floats nvim in a `display-popup`; Claude's Bash subshell
  has no TTY, so tmux's server is what paints the popup on the user's pane).
  `display-popup -E` blocks the invoking shell until nvim exits — so the Bash
  call naturally waits. Use a long timeout (e.g. 600000ms).
- Window-gated: if this Claude's tmux window isn't active, the popup waits
  (window renamed `✎ EDIT WAITING — …`) and only appears when the user
  switches back — so it never ambushes another window when running multiple
  Claudes. No desktop notification by design.
- Read the returned diff to see what they changed.
