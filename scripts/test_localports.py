#!/usr/bin/env python3
"""Tests for localports. Run with: /usr/bin/python3 scripts/test_localports.py"""

import os
import sys
import threading
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import localports as lp  # noqa: E402


class ParsingTests(unittest.TestCase):
    def test_port_of_handles_ipv4_wildcard_and_ipv6(self):
        self.assertEqual(lp._port_of("127.0.0.1:8000"), ("127.0.0.1", 8000))
        self.assertEqual(lp._port_of("*:4173"), ("*", 4173))
        self.assertEqual(lp._port_of("[::1]:5432"), ("[::1]", 5432))

    def test_port_of_rejects_non_sockets(self):
        self.assertEqual(lp._port_of("/some/path"), (None, None))
        self.assertEqual(lp._port_of("localhost:http"), (None, None))

    def test_ipv6_loopback_counts_as_reachable(self):
        self.assertTrue({"[::1]"} & lp.LOOPBACK_ADDRS)


class GroupingTests(unittest.TestCase):
    def test_launchd_helpers_are_apps(self):
        self.assertTrue(lp._is_app("/"))
        self.assertTrue(lp._is_app(""))
        self.assertTrue(lp._is_app("/Applications/Utilities/LogiPluginService.app"))
        self.assertTrue(lp._is_app("/Applications/Foo.app/Contents/MacOS"))

    def test_project_directories_are_not_apps(self):
        self.assertFalse(lp._is_app("/Users/brk/projects/quartz"))
        self.assertFalse(lp._is_app("/opt/homebrew/var/postgresql@15"))

    def test_framework_python_interpreter_is_not_an_app(self):
        """The path lives inside Python.app, but the cwd is what decides."""
        self.assertFalse(lp._is_app("/Users/brk/projects/language-model-melee"))


class DescribeTests(unittest.TestCase):
    def test_title_is_extracted_and_unescaped(self):
        out = lp._describe("http", "http://x/", 200, {"Content-Type": "text/html"},
                           b"<html><head><title>Factory &amp; builder</title></head>")
        self.assertEqual(out["title"], "Factory & builder")

    def test_h1_is_used_when_there_is_no_title(self):
        out = lp._describe("http", "http://x/", 200, {"Content-Type": "text/html"},
                           b"<body><h1>Manifold</h1></body>")
        self.assertEqual(out["title"], "Manifold")

    def test_json_endpoints_are_labelled(self):
        out = lp._describe("http", "http://x/", 200, {"Content-Type": "application/json"}, b"{}")
        self.assertEqual(out["title"], "JSON endpoint")


class IdleTests(unittest.TestCase):
    """The agent runs all day; it must not shell out to lsof when unobserved."""

    def setUp(self):
        self.scanner = lp.Scanner(lp.DEFAULT_PORT)
        self.scans = 0
        self.scanner.scan = self._count

    def _count(self):
        self.scans += 1

    def _run_briefly(self, seconds):
        threading.Thread(target=self.scanner.run_forever, daemon=True).start()
        time.sleep(seconds)

    def test_no_scans_while_nobody_is_watching(self):
        self._run_briefly(lp.SCAN_INTERVAL * 2.5)
        self.assertEqual(self.scans, 0)

    def test_scans_resume_once_the_page_is_open(self):
        self.scanner.mark_active()
        self._run_briefly(lp.SCAN_INTERVAL * 2.5)
        self.assertGreaterEqual(self.scans, 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
