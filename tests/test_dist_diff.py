#!/usr/bin/env python3
"""Tests for scripts/dist-diff.py (T3.1)."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "dist-diff.py"


class DistDiffTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.linux = self.tmp / "dist-linux"
        self.windows = self.tmp / "dist-windows"
        self.linux.mkdir()
        self.windows.mkdir()

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, root, relative, text="x"):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_diff(self):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.linux), str(self.windows)],
            text=True,
            capture_output=True,
        )

    def test_identical_trees_pass(self):
        for root in (self.linux, self.windows):
            self.write(root, "pack/root.zip", "same")
            self.write(root, "BGM/track.mp3", "same")
        result = self.run_diff()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 unexpected", result.stdout)

    def test_platform_runtime_files_are_expected(self):
        self.write(self.linux, "metin2client")
        self.write(self.linux, "metin2")
        self.write(self.linux, "runtime/libzip.so.4")
        self.write(self.linux, "lib/posixpath.pyc")
        self.write(self.windows, "metin2client.exe")
        self.write(self.windows, "python27.dll")
        self.write(self.windows, "libstdc++-6.dll")
        self.write(self.windows, "pack/root.zip")
        self.write(self.linux, "pack/root.zip")
        result = self.run_diff()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unexpected_linux_file_fails(self):
        self.write(self.linux, "pack/root.zip")
        self.write(self.windows, "pack/root.zip")
        self.write(self.linux, "BGM/extra.mp3")
        result = self.run_diff()
        self.assertEqual(result.returncode, 1)
        self.assertIn("BGM/extra.mp3", result.stdout)

    def test_unexpected_windows_file_fails(self):
        self.write(self.linux, "pack/root.zip")
        self.write(self.windows, "pack/root.zip")
        self.write(self.windows, "tools/extra.exe")
        result = self.run_diff()
        self.assertEqual(result.returncode, 1)
        self.assertIn("tools/extra.exe", result.stdout)

    def test_shared_file_content_must_match(self):
        self.write(self.linux, "pack/root.zip", "linux")
        self.write(self.windows, "pack/root.zip", "windows")
        result = self.run_diff()
        self.assertEqual(result.returncode, 1)
        self.assertIn("pack/root.zip", result.stdout)


if __name__ == "__main__":
    unittest.main()
