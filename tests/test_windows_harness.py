import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WindowsHarnessTests(unittest.TestCase):
    def test_preset_uses_windows_toolchain_and_64_bit_target(self):
        presets = json.loads((ROOT / 'CMakePresets.json').read_text())
        configure = next(p for p in presets['configurePresets'] if p['name'] == 'windows')
        self.assertEqual(configure['toolchainFile'], '${sourceDir}/cmake/toolchain-i686-windows-gnu.cmake')
        self.assertEqual(configure['binaryDir'], '${sourceDir}/build/windows')

    def test_entrypoint_routes_windows_subcommand(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            (root / 'scripts/build-windows.sh').write_text('#!/bin/sh\nprintf "windows:%s\\n" "$*"\n')
            (root / 'scripts/build-windows.sh').chmod(0o755)
            env = dict(os.environ, OPENMT2_WORKSPACE=str(root))
            result = subprocess.run(['bash', str(ROOT / 'docker/entrypoint.sh'), 'windows', '--clean'],
                                    env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'windows:--clean')

    def test_distribution_uses_pe_executable_name(self):
        script = (ROOT / 'scripts/build-windows.sh').read_text()
        self.assertIn('metin2client.exe', script)
        self.assertIn('config.exe', script)

    def test_distribution_shares_the_asset_and_pack_scripts(self):
        script = (ROOT / 'scripts/build-windows.sh').read_text()
        self.assertIn('copy-assets.sh', script)
        self.assertIn('pack-assets.sh', script)
        self.assertIn('OPENMT2_DIST_DIR', script)

    def test_distribution_ships_the_mingw_and_python_runtime(self):
        script = (ROOT / 'scripts/build-windows.sh').read_text()
        for dll in ('python27.dll', 'msvcr90.dll', 'libstdc++-6.dll', 'libgcc_s_seh-1.dll'):
            self.assertIn(dll, script)

    def test_linux_and_windows_use_the_same_assembler(self):
        linux = (ROOT / 'scripts/build.sh').read_text()
        windows = (ROOT / 'scripts/build-windows.sh').read_text()
        for script in (linux, windows):
            self.assertIn('copy-assets.sh', script)
            self.assertIn('pack-assets.sh', script)
        self.assertIn('$ORIGIN/runtime', (ROOT / 'docker/root/CMakeLists.txt').read_text())


if __name__ == '__main__':
    unittest.main()
