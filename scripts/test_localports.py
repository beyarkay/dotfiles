#!/usr/bin/env python3
"""Tests for localports. Run with: /usr/bin/python3 scripts/test_localports.py"""

import json
import os
import socket
import subprocess
import sys
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

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


def _reap(process):
    if process.poll() is None:
        process.kill()
    process.wait()


def _free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class KillTests(unittest.TestCase):
    """The kill endpoint is the one that can do damage, so it gets the most cover."""

    @classmethod
    def setUpClass(cls):
        cls.port = _free_port()
        lp.Handler.scanner = lp.Scanner(cls.port)
        lp.Handler.allowed_origins = ("http://localhost:{}".format(cls.port),
                                      "http://127.0.0.1:{}".format(cls.port))
        cls.server = ThreadingHTTPServer(("127.0.0.1", cls.port), lp.Handler)
        cls.server.daemon_threads = True
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def _post(self, payload, headers=None):
        headers = {"Content-Type": "application/json", "X-Localports": "1"} \
            if headers is None else headers
        request = urllib.request.Request(
            "http://127.0.0.1:{}/kill".format(self.port),
            data=json.dumps(payload).encode(), method="POST")
        for key, value in headers.items():
            request.add_header(key, value)
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read())

    def _start_victim(self):
        port = _free_port()
        victim = subprocess.Popen(
            [sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(_reap, victim)
        for _ in range(50):
            with socket.socket() as probe:
                if probe.connect_ex(("127.0.0.1", port)) == 0:
                    return port, victim
            time.sleep(0.1)
        self.fail("victim server never came up")

    def test_rejects_requests_without_the_custom_header(self):
        """Without this, a form POST from any site you visit could kill things."""
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self._post({"port": 1, "pid": 1}, headers={"Content-Type": "application/json"})
        self.assertEqual(caught.exception.code, 403)

    def test_rejects_a_foreign_origin(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self._post({"port": 1, "pid": 1},
                       headers={"Content-Type": "application/json",
                                "X-Localports": "1", "Origin": "https://evil.example"})
        self.assertEqual(caught.exception.code, 403)

    def test_rejects_a_malformed_body(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self._post({"port": "not-a-number", "pid": 1})
        self.assertEqual(caught.exception.code, 400)

    def test_refuses_when_the_pid_no_longer_owns_the_port(self):
        port, victim = self._start_victim()
        result = self._post({"port": port, "pid": victim.pid + 100000})
        self.assertFalse(result["ok"])
        self.assertIn("refusing", result["message"])
        self.assertIsNone(victim.poll(), "victim must survive a mismatched pid")

    def test_kills_the_process_holding_the_port(self):
        port, victim = self._start_victim()
        result = self._post({"port": port, "pid": victim.pid})
        self.assertTrue(result["ok"], result["message"])
        self.assertFalse(result["alive"], result["message"])
        self.assertIsNotNone(victim.poll(), "victim should be dead")

    def test_reports_an_empty_port_without_signalling_anything(self):
        result = self._post({"port": _free_port(), "pid": os.getpid()})
        self.assertTrue(result["ok"])
        self.assertIn("nothing on", result["message"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
