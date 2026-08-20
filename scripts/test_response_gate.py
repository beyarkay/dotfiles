#!/usr/bin/env python3
"""Tests for the response-gate Stop hook.

Run with: /usr/bin/python3 scripts/test_response_gate.py
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(ROOT, "claude", "hooks", "response-gate.sh")
SHIPPED_RULES = os.path.join(ROOT, "claude", "hooks", "response-rules.yaml")

MISSING = [tool for tool in ("jq", "yq", "rg") if shutil.which(tool) is None]

TEST_RULES = """
max_rewrites: 2
patterns:
  - name: banned-word
    regex: '(?i)\\bfoo\\b'
    message: 'Do not say foo.'
  - name: raw-only
    regex: 'ZZZ'
    message: 'No ZZZ anywhere.'
    scope: raw
"""


def run_hook(reply, sid, prompt_id="p1", agent_id="", rules=None, env=None):
    payload = {
        "session_id": sid,
        "prompt_id": prompt_id,
        "agent_id": agent_id,
        "hook_event_name": "Stop",
        "last_assistant_message": reply,
    }
    environ = dict(os.environ)
    environ["CLAUDE_RESPONSE_RULES"] = rules or SHIPPED_RULES
    environ.update(env or {})
    return subprocess.run(
        [HOOK], input=json.dumps(payload), capture_output=True, text=True, env=environ
    )


@unittest.skipIf(MISSING, f"needs {MISSING}")
class GateTests(unittest.TestCase):
    def setUp(self):
        self.sid = "test-gate-" + uuid.uuid4().hex[:12]
        state = f"/tmp/claude-gate-{self.sid}.state"
        self.addCleanup(lambda: os.path.exists(state) and os.remove(state))
        self.state = state

        handle = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False)
        handle.write(TEST_RULES)
        handle.close()
        self.rules = handle.name
        self.addCleanup(os.remove, self.rules)

    def gate(self, reply, **kwargs):
        kwargs.setdefault("rules", self.rules)
        return run_hook(reply, self.sid, **kwargs)

    def test_clean_reply_passes_silently(self):
        proc = self.gate("The parser now rejects trailing commas.")
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stderr, "")

    def test_violation_blocks_with_rule_name_and_message(self):
        proc = self.gate("This foo is broken.")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("banned-word", proc.stderr)
        self.assertIn("Do not say foo.", proc.stderr)

    def test_block_message_quotes_the_offending_line(self):
        proc = self.gate("All fine here.\nBut this foo is broken.")
        self.assertIn("in: But this foo is broken.", proc.stderr)

    def test_fenced_code_is_exempt(self):
        proc = self.gate("Done.\n\n```py\nfoo = 1\n```\n\nTests pass.")
        self.assertEqual(proc.returncode, 0)

    def test_inline_code_span_is_exempt(self):
        self.assertEqual(self.gate("I renamed `foo` to `bar`.").returncode, 0)

    def test_raw_scope_still_sees_code(self):
        proc = self.gate("Done.\n\n```py\nZZZ = 1\n```")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("raw-only", proc.stderr)

    def test_word_boundaries_survive_the_yaml_round_trip(self):
        self.assertEqual(self.gate("The foobar helper is fine.").returncode, 0)
        self.assertEqual(self.gate("The foo helper is broken.").returncode, 2)

    def test_rewrites_are_capped_then_the_turn_is_let_through(self):
        codes = [self.gate("This foo is broken.").returncode for _ in range(3)]
        self.assertEqual(codes, [2, 2, 0])

    def test_a_new_prompt_resets_the_cap(self):
        for _ in range(3):
            self.gate("This foo is broken.")
        self.assertEqual(self.gate("This foo is broken.", prompt_id="p2").returncode, 2)

    def test_a_corrupt_state_file_does_not_wedge_the_gate(self):
        with open(self.state, "w") as handle:
            handle.write("garbage\n")
        self.assertEqual(self.gate("This foo is broken.").returncode, 2)

    def test_subagent_replies_are_ignored(self):
        self.assertEqual(self.gate("This foo is broken.", agent_id="sub-1").returncode, 0)

    def test_empty_reply_is_ignored(self):
        for reply in ("", "   \n\t "):
            with self.subTest(reply=repr(reply)):
                self.assertEqual(self.gate(reply).returncode, 0)

    def test_off_switch(self):
        env = {"CLAUDE_RESPONSE_GATE": "0"}
        self.assertEqual(self.gate("This foo is broken.", env=env).returncode, 0)

    def test_recursion_guard_so_the_judge_cannot_gate_itself(self):
        env = {"CLAUDE_RESPONSE_GATE_INNER": "1"}
        self.assertEqual(self.gate("This foo is broken.", env=env).returncode, 0)

    def test_a_missing_ruleset_is_not_an_error(self):
        proc = self.gate("This foo is broken.", rules="/nonexistent/rules.yaml")
        self.assertEqual(proc.returncode, 0)


@unittest.skipIf(MISSING, f"needs {MISSING}")
class ShippedRulesetTests(unittest.TestCase):
    def setUp(self):
        self.sids = []
        self.addCleanup(self.clean_state)

    def clean_state(self):
        for sid in self.sids:
            path = f"/tmp/claude-gate-{sid}.state"
            if os.path.exists(path):
                os.remove(path)

    def run_once(self, reply):
        sid = "test-gate-" + uuid.uuid4().hex[:12]
        self.sids.append(sid)
        return run_hook(reply, sid)

    def assertFires(self, rule, reply):
        proc = self.run_once(reply)
        self.assertEqual(proc.returncode, 2, f"{rule!r} did not fire on {reply!r}")
        self.assertIn(rule, proc.stderr)

    def assertQuiet(self, reply):
        proc = self.run_once(reply)
        self.assertEqual(proc.returncode, 0, f"false alarm on {reply!r}:\n{proc.stderr}")

    def test_rules_parse(self):
        out = subprocess.run(["yq", "-o=json", ".", SHIPPED_RULES], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertTrue(json.loads(out.stdout)["patterns"])

    def test_sycophancy(self):
        self.assertFires("sycophancy", "That is a great question, and the answer is no.")
        self.assertQuiet("The good news is that it finished in four seconds.")

    def test_flattering_agreement(self):
        self.assertFires("flattering-agreement", "You are absolutely right, I will fix it.")
        self.assertQuiet("The right operand is evaluated first.")

    def test_abbreviation_matches_the_stub_not_the_whole_word(self):
        self.assertFires("abbreviation", "The emb layer disagrees with the score.")
        self.assertQuiet("The embodiment layer disagrees with the coherence score.")

    def test_apology(self):
        self.assertFires("apology", "I apologize, that was wrong.")
        self.assertQuiet("The server returned 'sorry, no route to host'.")

    def test_ordinary_engineering_prose_is_left_alone(self):
        for reply in (
            "Done. The parser rejects trailing commas now, and 14 of 14 tests pass.",
            "I could not reproduce it. The log shows the retry firing twice, not once.",
            "Two things are wrong here: the lock is taken too late, and it is never released.",
            "That will not work, because the reducer runs before the state is hydrated.",
        ):
            with self.subTest(reply=reply):
                self.assertQuiet(reply)


if __name__ == "__main__":
    unittest.main(verbosity=2)
