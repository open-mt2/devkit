import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/spike-windows.sh'

class SpikeTests(unittest.TestCase):
    def test_missing_tool_reports_every_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'map').write_text('pkg_a=A\npkg_b=B\n')
            for name in ('A', 'B'):
                (root / 'src' / name).mkdir(parents=True)
                (root / 'src' / name / 'CMakeLists.txt').write_text('project(test)')
            env = dict(os.environ, SPIKE_CMAKE='nonexistent-cross-cmake',
                       SPIKE_MAP=str(root / 'map'))
            result = subprocess.run(['bash', str(SCRIPT), str(root / 'src'), str(root / 'out')],
                                    env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('A\ttool-missing', result.stdout)
            self.assertIn('B\ttool-missing', result.stdout)
            self.assertIn('nonexistent-cross-cmake', result.stdout)

    def test_configure_failure_does_not_skip_later_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'map').write_text('pkg_a=A\npkg_b=B\n')
            for name in ('A', 'B'):
                (root / 'src' / name).mkdir(parents=True)
                (root / 'src' / name / 'CMakeLists.txt').write_text('project(test)')
            tool = root / 'cross-cmake'
            tool.write_text('#!/bin/sh\necho "compiler unavailable: $2"\nexit 1\n')
            tool.chmod(0o755)
            result = subprocess.run(['bash', str(SCRIPT), str(root / 'src'), str(root / 'out')],
                env=dict(os.environ, SPIKE_CMAKE=str(tool), SPIKE_MAP=str(root / 'map')),
                text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('A\tconfigure-failed', result.stdout)
            self.assertIn('B\tconfigure-failed', result.stdout)
            self.assertEqual(result.stdout.count('compiler unavailable:'), 2)

    def test_real_build_failure_and_success_are_distinguished(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'map').write_text('pkg_a=A\npkg_b=B\n')
            for name, action in (('A', 'false'), ('B', 'true')):
                directory = root / 'src' / name
                directory.mkdir(parents=True)
                (directory / 'CMakeLists.txt').write_text(
                    'cmake_minimum_required(VERSION 3.20)\nproject(probe NONE)\n'
                    f'add_custom_target(check ALL COMMAND "${{CMAKE_COMMAND}}" -E {action})\n')
            result = subprocess.run(['bash', str(SCRIPT), str(root / 'src'), str(root / 'out')],
                env=dict(os.environ, SPIKE_CMAKE='cmake', SPIKE_MAP=str(root / 'map')),
                text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('A\tbuild-failed', result.stdout)
            self.assertIn('B\tbuild-passed', result.stdout)

if __name__ == '__main__':
    unittest.main()
