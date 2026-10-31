import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "pack-assets.sh"


def write_file(path: Path, data: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data)


class PackAssetsTests(unittest.TestCase):
    def run_pack(self, source: Path, dest: Path, archiver: str = "zip"):
        return subprocess.run(
            ["bash", str(SCRIPT), str(source), str(dest), archiver],
            text=True,
            capture_output=True,
        )

    def test_merges_case_colliding_directories_into_index_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bin-pack"
            dest = root / "dist-pack"

            write_file(source / "ETC" / "ymir work" / "ui" / "a.txt", "A")
            write_file(source / "etc" / "ymir work" / "ui" / "b.txt", "B")
            write_file(source / "orphan" / "not-indexed.txt", "X")
            write_file(source / "Index", "ETC\tZIP\n")

            result = self.run_pack(source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)

            self.assertEqual([p.name for p in dest.iterdir()], ["ETC.zip"])
            with zipfile.ZipFile(dest / "ETC.zip") as archive:
                names = set(archive.namelist())
                self.assertIn("ymir work/ui/a.txt", names)
                self.assertIn("ymir work/ui/b.txt", names)
                self.assertNotIn("not-indexed.txt", names)

    def test_renames_a_single_case_mismatched_directory_to_the_index_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bin-pack"
            dest = root / "dist-pack"

            write_file(source / "PC" / "ymir work" / "pc.txt", "P")
            write_file(source / "Index", "pc\tZIP\n")

            result = self.run_pack(source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)

            self.assertEqual([p.name for p in dest.iterdir()], ["pc.zip"])
            with zipfile.ZipFile(dest / "pc.zip") as archive:
                self.assertIn("ymir work/pc.txt", archive.namelist())

    def test_keeps_index_order_when_merging_duplicate_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bin-pack"
            dest = root / "dist-pack"

            write_file(source / "ETC" / "same.txt", "upper")
            write_file(source / "etc" / "same.txt", "lower")
            write_file(source / "Index", "ETC\tZIP\n")

            result = self.run_pack(source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)

            with zipfile.ZipFile(dest / "ETC.zip") as archive:
                # ASCII sort puts ETC/ before etc/, so the later copy wins.
                self.assertEqual(archive.read("same.txt").decode(), "lower")

    def test_copies_a_prebuilt_archive_when_no_directory_matches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bin-pack"
            dest = root / "dist-pack"
            source.mkdir(parents=True)

            with zipfile.ZipFile(source / "Patch.zip", "w") as archive:
                archive.writestr("entry.txt", "patch")
            write_file(source / "Index", "Patch\tZIP\n")

            result = self.run_pack(source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)

            with zipfile.ZipFile(dest / "Patch.zip") as archive:
                self.assertEqual(archive.read("entry.txt").decode(), "patch")

    def test_skips_index_entries_without_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bin-pack"
            dest = root / "dist-pack"
            write_file(source / "Index", "missing\tZIP\n")

            result = self.run_pack(source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("no matching directory or archive", result.stderr)
            self.assertEqual(list(dest.iterdir()), [])

    def test_fails_without_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bin-pack"
            source.mkdir(parents=True)

            result = self.run_pack(source, root / "dist-pack")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no Index", result.stderr)


if __name__ == "__main__":
    unittest.main()
