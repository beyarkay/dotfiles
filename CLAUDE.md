# HI CLAUDE

can you see this? let me know if you can, i'm not sure if it's working

## Preferred tools

Rust, `uv`, `ty`

## Interactive editing: `drop-user-in-file`

When the user wants to hand-edit a file mid-session (or asks to be "dropped
into" a file), use the **`drop-user-in-file` skill** — it floats an
interactive nvim popup at PATH:LINE, blocks until they `:q`, and returns the
diff. Full usage and requirements live in its `SKILL.md`
(`~/.claude/skills/drop-user-in-file/`).
