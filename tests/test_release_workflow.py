#!/usr/bin/env python3
"""Tests for the release image and its proprietary-content gate (REL.1)."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "release.yml"
GATE = ROOT / "scripts" / "verify-no-proprietary.sh"


class ReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text(encoding="utf-8")

    def test_publishes_on_version_tags(self):
        self.assertIn('tags: ["v*"]', self.text)
        self.assertIn("packages: write", self.text)

    def test_publishes_the_client_image(self):
        self.assertIn("ghcr.io/open-mt2/client", self.text)
        self.assertIn("${{ github.ref_name }}", self.text)
        self.assertIn(":latest", self.text)

    def test_never_fetches_client_assets(self):
        self.assertIn("WITH_BIN=0", self.text)
        self.assertIn("BAKE_TREES=0", self.text)
        self.assertNotIn("WITH_BIN=1", self.text)

    def test_builds_speedtree_dumper_from_public_sources(self):
        self.assertIn("WITH_SPEEDTREE=1", self.text)
        self.assertIn("BUILD_SPEEDTREE_DUMPER=1", self.text)

    def test_leak_gate_runs_before_the_push(self):
        gate = self.text.index("verify-no-proprietary.sh")
        push = self.text.index("docker push")
        self.assertLess(gate, push)


class ProprietaryGateTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, relative, text="x"):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_gate(self):
        return subprocess.run(
            ["bash", str(GATE), str(self.root)],
            text=True,
            capture_output=True,
        )

    def assert_rejected(self, relative):
        self.write(relative)
        result = self.run_gate()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(relative.split("/")[0], result.stdout + result.stderr)
        return result

    def test_clean_source_workspace_passes(self):
        self.write("scripts/build.sh", "#!/bin/sh\n")
        self.write("src/client/README.md", "source\n")
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_empty_directories_pass(self):
        (self.root / "bin").mkdir()
        (self.root / "dist").mkdir()
        (self.root / "treecache").mkdir()
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_gitignore_only_bin_passes(self):
        self.write("bin/.gitignore", "*\n")
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_client_assets_fail(self):
        self.assert_rejected("bin/pack/root.zip")

    def test_packaged_dist_fails(self):
        self.assert_rejected("dist/metin2client")

    def test_baked_treecache_fails(self):
        self.assert_rejected("treecache/0123abcd.tree")

    def test_pack_archives_outside_bin_fail(self):
        self.assert_rejected("artifacts/pack/root.zip")
        self.assert_rejected("artifacts/pack/Index.rdch")


if __name__ == "__main__":
    unittest.main()
