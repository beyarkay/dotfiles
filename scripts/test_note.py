#!/usr/bin/env python3
"""Tests for the /note hook and its status-line row.

Run with: /usr/bin/python3 scripts/test_note.py
"""

import json
import os
import re
import subprocess
import uuid
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(ROOT, "claude", "hooks", "note.sh")
STATUSLINE = os.path.join(ROOT, "claude", "statusline.sh")

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def run_hook(prompt, sid):
    proc = subprocess.run(
        [HOOK],
        input=json.dumps({"session_id": sid, "prompt": prompt}),
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    return proc.stdout.strip()


def run_statusline(sid, used_percentage=5):
    payload = {"session_id": sid, "context_window": {"used_percentage": used_percentage}}
    proc = subprocess.run([STATUSLINE], input=json.dumps(payload), capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    return [ANSI.sub("", line) for line in proc.stdout.splitlines()]


class NoteHookTests(unittest.TestCase):
    def setUp(self):
        self.sid = "test-note-" + uuid.uuid4().hex[:12]
        self.note_file = f"/tmp/claude-note-{self.sid}.txt"
        self.addCleanup(lambda: os.path.exists(self.note_file) and os.remove(self.note_file))

    def read_note(self):
        with open(self.note_file) as handle:
            return handle.read()

    def test_sets_a_note_and_blocks_the_prompt(self):
        out = json.loads(run_hook("/note this is a custom note", self.sid))
        self.assertEqual(out["decision"], "block")
        self.assertEqual(out["reason"], "note: this is a custom note")
        self.assertEqual(self.read_note(), "this is a custom note")

    def test_bare_note_clears_it(self):
        run_hook("/note something", self.sid)
        out = json.loads(run_hook("/note", self.sid))
        self.assertEqual(out["reason"], "note cleared")
        self.assertFalse(os.path.exists(self.note_file))

    def test_trailing_whitespace_also_clears(self):
        run_hook("/note something", self.sid)
        run_hook("/note   ", self.sid)
        self.assertFalse(os.path.exists(self.note_file))

    def test_surrounding_whitespace_is_trimmed_and_newlines_flattened(self):
        run_hook("/note   ship the\nrelease  ", self.sid)
        self.assertEqual(self.read_note(), "ship the release")

    def test_note_is_overwritten_not_appended(self):
        run_hook("/note first", self.sid)
        run_hook("/note second", self.sid)
        self.assertEqual(self.read_note(), "second")

    def test_quotes_and_shell_metacharacters_survive_verbatim(self):
        note = """don't `run` $(this) "yet" & | > ;"""
        run_hook("/note " + note, self.sid)
        self.assertEqual(self.read_note(), note)

    def test_ordinary_prompts_pass_through_untouched(self):
        for prompt in ("fix the parser", "/notepad is a program", "note this down", "/notes"):
            with self.subTest(prompt=prompt):
                self.assertEqual(run_hook(prompt, self.sid), "")
                self.assertFalse(os.path.exists(self.note_file))


class StatusLineTests(unittest.TestCase):
    def setUp(self):
        self.sid = "test-note-" + uuid.uuid4().hex[:12]
        self.note_file = f"/tmp/claude-note-{self.sid}.txt"
        self.addCleanup(lambda: os.path.exists(self.note_file) and os.remove(self.note_file))

    def test_context_row_is_unchanged_without_a_note(self):
        self.assertEqual(run_statusline(self.sid)[1], "5% context")

    def test_note_is_appended_to_the_context_row(self):
        run_hook("/note this is a custom note", self.sid)
        rows = run_statusline(self.sid)
        self.assertEqual(rows[0], "\U0001f3af (no current task set)")
        self.assertEqual(rows[1], "5% context | this is a custom note")


if __name__ == "__main__":
    unittest.main(verbosity=2)
