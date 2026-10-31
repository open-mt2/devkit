#!/usr/bin/env python3
"""Tests for scripts/pack-assets.sh (#115).

The client reads the archives named by ``pack/Index``; the unpacked
directories under ``bin/pack`` are only the build input. These tests pin that
mapping: index-driven naming, case-variant merging and ignoring unindexed
directories.
"""

from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "pack-assets.sh"


class PackAssetsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.source = self.tmp / "pack"
        self.dest = self.tmp / "dist" / "pack"
        self.source.mkdir(parents=True)

    def tearDown(self):
        self._tmp.cleanup()

    def write_index(self, entries, metadata=True):
        (self.source / "Index").write_text(entries, encoding="utf-8")
        if metadata:
            (self.source / "Index.dev").write_text(entries, encoding="utf-8")
            (self.source / "meta.rdch").write_text("rdch", encoding="utf-8")

    def add_dir(self, name, files):
        directory = self.source / name
        directory.mkdir()
        for relative, text in files.items():
            path = directory / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    def run_script(self, *extra):
        return subprocess.run(
            ["bash", str(SCRIPT), "--source", str(self.source), "--dest", str(self.dest), *extra],
            text=True,
            capture_output=True,
        )

    def names(self, archive, files_only=False):
        with zipfile.ZipFile(self.dest / archive) as handle:
            names = handle.namelist()
        if files_only:
            names = [name for name in names if not name.endswith("/")]
        return sorted(names)

    def test_packs_only_directories_listed_in_the_index(self):
        self.add_dir("alpha", {"a.txt": "a"})
        self.add_dir("beta", {"b.txt": "b"})
        self.write_index("alpha\tZIP\n")

        result = self.run_script("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.dest / "alpha.zip").is_file())
        self.assertFalse((self.dest / "beta.zip").exists())
        self.assertEqual(self.names("alpha.zip", files_only=True), ["a.txt"])

    def test_merges_case_colliding_directories_into_one_archive(self):
        self.add_dir("ETC", {"one.txt": "1"})
        self.add_dir("etc", {"two.txt": "2"})
        self.write_index("ETC\tZIP\n")

        result = self.run_script("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.names("ETC.zip", files_only=True), ["one.txt", "two.txt"])
        self.assertFalse((self.dest / "etc.zip").exists())

    def test_uses_the_index_spelling_for_the_archive(self):
        self.add_dir("Monster", {"mob.txt": "m"})
        self.write_index("monster\tZIP\n")

        result = self.run_script("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.dest / "monster.zip").is_file())
        self.assertFalse((self.dest / "Monster.zip").exists())

    def test_copies_index_and_rdch_metadata(self):
        self.add_dir("alpha", {"a.txt": "a"})
        self.write_index("alpha\tZIP\n")

        result = self.run_script("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ("Index", "Index.dev", "meta.rdch"):
            self.assertTrue((self.dest / name).is_file(), name)

    def test_missing_indexed_directory_is_skipped_not_fatal(self):
        self.add_dir("alpha", {"a.txt": "a"})
        self.write_index("alpha\tZIP\nmissing\tZIP\n")

        result = self.run_script("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("missing", result.stderr)
        self.assertTrue((self.dest / "alpha.zip").is_file())

    def test_archive_entries_are_relative_paths(self):
        self.add_dir("alpha", {"nested/deep.txt": "x"})
        self.write_index("alpha\tZIP\n")

        result = self.run_script("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.names("alpha.zip", files_only=True), ["nested/deep.txt"])

    def test_help_exits_zero(self):
        result = subprocess.run(["bash", str(SCRIPT), "--help"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("pack-assets.sh", result.stdout)


if __name__ == "__main__":
    unittest.main()
