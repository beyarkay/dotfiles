---
description: Pin a free-text note to the status line (no arguments clears it)
---

This file exists so `/note` shows up in the slash-command menu. The work is done
by hooks/note.sh, a UserPromptSubmit hook that intercepts `/note` before it is
expanded and blocks the turn — so this body should never be reached.

If you are reading it, that hook did not run. Tell the user their `/note` hook is
not wired up in settings.json, and do nothing else.
