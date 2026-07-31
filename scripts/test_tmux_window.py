#!/usr/bin/env python3
"""Tests for the tmux window-marker hook.

Runs against a throwaway tmux server on its own socket, so the tests never
touch a real session. Skipped entirely if tmux is not installed.

Run with: /usr/bin/python3 scripts/test_tmux_window.py
"""

import json
import os
import shutil
import subprocess
import unittest
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(ROOT, "claude", "hooks", "tmux-window.sh")
SETTINGS = os.path.join(ROOT, "claude", "settings.json")

QUESTION = "❓"  # ❓
BUSY = "\U0001f6a7"  # 🚧
COMPACT = "\U0001f5dc️"  # 🗜️, a base code point plus a variation selector


@unittest.skipUnless(shutil.which("tmux"), "tmux is not installed")
class MarkerTests(unittest.TestCase):
    def setUp(self):
        self.label = "claude-test-" + uuid.uuid4().hex[:12]
        self.tmux("new-session", "-d", "-s", "s", "-x", "80", "-y", "24")
        self.addCleanup(self.kill_server)
        self.pane = self.tmux("list-panes", "-F", "#{pane_id}").splitlines()[0]
        self.socket = self.tmux("display-message", "-p", "#{socket_path}")

    def kill_server(self):
        subprocess.run(["tmux", "-L", self.label, "kill-server"], capture_output=True, text=True)

    def tmux(self, *args):
        proc = subprocess.run(["tmux", "-L", self.label, *args], capture_output=True, text=True)
        assert proc.returncode == 0, proc.stderr
        return proc.stdout.strip()

    def window_name(self):
        return self.tmux("display-message", "-t", self.pane, "-p", "#W")

    def run_hook(self, *args, pane=None, socket=None):
        env = dict(os.environ)
        env["TMUX"] = f"{socket if socket is not None else self.socket},0,0"
        if pane is not None:
            env["TMUX_PANE"] = pane
        else:
            env["TMUX_PANE"] = self.pane
        proc = subprocess.run([HOOK, *args], capture_output=True, text=True, env=env)
        assert proc.returncode == 0, proc.stderr
        return proc

    def test_strips_the_compaction_marker(self):
        self.tmux("rename-window", "-t", self.pane, f"dotfiles {COMPACT}")
        self.run_hook()
        self.assertEqual(self.window_name(), "dotfiles")

    def test_strips_the_single_codepoint_markers(self):
        for marker in (QUESTION, BUSY):
            with self.subTest(marker=marker):
                self.tmux("rename-window", "-t", self.pane, f"dotfiles {marker}")
                self.run_hook()
                self.assertEqual(self.window_name(), "dotfiles")

    def test_sets_a_marker(self):
        self.tmux("rename-window", "-t", self.pane, "dotfiles")
        self.run_hook(COMPACT)
        self.assertEqual(self.window_name(), f"dotfiles {COMPACT}")

    def test_replaces_rather_than_stacks_markers(self):
        self.tmux("rename-window", "-t", self.pane, f"dotfiles {BUSY}")
        self.run_hook(COMPACT)
        self.assertEqual(self.window_name(), f"dotfiles {COMPACT}")
        self.run_hook(QUESTION)
        self.assertEqual(self.window_name(), f"dotfiles {QUESTION}")

    def test_stripping_an_unmarked_window_is_a_no_op(self):
        self.tmux("rename-window", "-t", self.pane, "dotfiles")
        self.run_hook()
        self.assertEqual(self.window_name(), "dotfiles")

    def test_leaves_emoji_that_are_part_of_the_name_alone(self):
        self.tmux("rename-window", "-t", self.pane, "\U0001f680 deploy")
        self.run_hook()
        self.assertEqual(self.window_name(), "\U0001f680 deploy")

    def test_a_name_that_is_only_a_marker_strips_to_empty(self):
        self.tmux("rename-window", "-t", self.pane, f" {COMPACT}")
        self.run_hook()
        self.assertEqual(self.window_name(), "")

    def test_does_nothing_without_a_pane(self):
        self.tmux("rename-window", "-t", self.pane, f"dotfiles {COMPACT}")
        env = dict(os.environ)
        env.pop("TMUX_PANE", None)
        env["TMUX"] = f"{self.socket},0,0"
        proc = subprocess.run([HOOK], capture_output=True, text=True, env=env)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(self.window_name(), f"dotfiles {COMPACT}")

    def test_survives_a_pane_that_no_longer_exists(self):
        proc = self.run_hook(pane="%99999")
        self.assertEqual(proc.returncode, 0)


class SettingsTests(unittest.TestCase):
    def test_every_tmux_hook_goes_through_the_script(self):
        with open(SETTINGS) as handle:
            settings = json.load(handle)
        commands = [
            hook["command"]
            for matchers in settings["hooks"].values()
            for matcher in matchers
            for hook in matcher["hooks"]
        ]
        self.assertFalse(
            [c for c in commands if "display-message" in c],
            "inline tmux rename one-liners cannot strip the compaction marker",
        )

    def test_precompact_marker_is_cleared_by_postcompact(self):
        with open(SETTINGS) as handle:
            settings = json.load(handle)

        def commands_for(event):
            return [
                hook["command"]
                for matcher in settings["hooks"].get(event, [])
                for hook in matcher["hooks"]
            ]

        self.assertIn(f"$HOME/.claude/hooks/tmux-window.sh {COMPACT}", commands_for("PreCompact"))
        self.assertIn("$HOME/.claude/hooks/tmux-window.sh", commands_for("PostCompact"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
