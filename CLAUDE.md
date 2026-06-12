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

## TODO list

I'll _often_ give you multiple things, you should make _heavy_ usage of your
TODO tool. Add tasks _immediately_ to your TODO list (don't wait to complete
your task, you often forget about what I've said by the time you finish them.

## AI Writing

If I ask you for prose or written work (I don't often), you should read
https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing and _not_ do
anything on that list.
