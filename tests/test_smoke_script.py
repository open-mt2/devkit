#!/usr/bin/env python3
"""Tests for scripts/smoke.sh (T3.2)."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "smoke.sh"


class SmokeScriptTest(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], text=True, capture_output=True, timeout=15)

    def test_help_exits_zero(self):
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("linux", result.stdout)
        self.assertIn("windows", result.stdout)

    def test_unknown_target_is_rejected(self):
        result = self.run_script("amiga")
        self.assertEqual(result.returncode, 2)
        self.assertIn("linux|windows", result.stderr)

    def test_missing_dist_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_script("linux", "--dist", tmp)
            self.assertEqual(result.returncode, 2)
            self.assertIn("metin2client", result.stderr)

    def test_windows_target_requires_wine(self):
        text = SCRIPT.read_text()
        self.assertIn("wine not found", text)
        self.assertIn("command -v wine", text)

    def test_artifacts_and_black_screen_flags_are_documented(self):
        text = SCRIPT.read_text()
        for token in ("--artifact", "--home", "--settle", "--min-colors", "--reference"):
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
