import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER_SCRIPT = ROOT / "scripts" / "server.sh"
SET_SERVER = ROOT / "scripts" / "set-server.py"

SERVERINFO = """SERVER_NAME\t\t\t= "Metin2"
SERVER_IP\t\t\t= "127.0.0.1"
PORT_1\t\t\t\t= 13000
PORT_AUTH\t\t\t= 11000

REGION_AUTH_SERVER_DICT = {
\t0: {
\t\t1: {"ip": SERVER_IP, "port": PORT_AUTH},
\t}
}
"""

ENV_EXAMPLE = """GAME_IMAGE=git.old-metin2.com/metin2/server:latest
MYSQL_PASSWORD=metin2
MYSQL_EXTERNAL_PORT=3306
WEB_APP_URL=http://metin2.local
WEB_APP_KEY=
WEB_EXTERNAL_PORT=80
PUBLIC_IP=127.0.0.1
"""


def read_env(path: Path) -> dict:
    values = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key] = value
    return values


class SetServerTests(unittest.TestCase):
    def make_dist(self, root: Path) -> Path:
        dist = root / "dist"
        (dist / "pack").mkdir(parents=True)
        with zipfile.ZipFile(dist / "pack" / "root.zip", "w") as archive:
            archive.writestr("serverinfo.py", SERVERINFO)
            archive.writestr("localeinfo.py", "LOCALE = 1\n")
        return dist

    def run_set_server(self, *args):
        return subprocess.run(
            [sys.executable, str(SET_SERVER), *args],
            text=True,
            capture_output=True,
        )

    def test_rewrites_server_ip_and_keeps_other_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            dist = self.make_dist(Path(tmp))

            result = self.run_set_server(str(dist), "192.168.1.20")
            self.assertEqual(result.returncode, 0, result.stderr)

            with zipfile.ZipFile(dist / "pack" / "root.zip") as archive:
                names = archive.namelist()
                info = archive.read("serverinfo.py").decode()
                locale = archive.read("localeinfo.py").decode()
            self.assertEqual(sorted(names), ["localeinfo.py", "serverinfo.py"])
            self.assertIn('SERVER_IP\t\t\t= "192.168.1.20"', info)
            self.assertNotIn("127.0.0.1", info)
            self.assertIn("PORT_AUTH\t\t\t= 11000", info)
            self.assertEqual(locale, "LOCALE = 1\n")

    def test_rejects_an_invalid_address(self):
        with tempfile.TemporaryDirectory() as tmp:
            dist = self.make_dist(Path(tmp))

            result = self.run_set_server(str(dist), 'x"; import os')
            self.assertNotEqual(result.returncode, 0)
            with zipfile.ZipFile(dist / "pack" / "root.zip") as archive:
                self.assertIn('"127.0.0.1"', archive.read("serverinfo.py").decode())

    def test_server_client_command_retargets_the_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            dist = self.make_dist(Path(tmp))
            env = dict(os.environ, SERVER_PUBLIC_IP="10.0.0.5")

            result = subprocess.run(
                ["bash", str(SERVER_SCRIPT), "client", str(dist)],
                text=True,
                capture_output=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with zipfile.ZipFile(dist / "pack" / "root.zip") as archive:
                self.assertIn('"10.0.0.5"', archive.read("serverinfo.py").decode())

    def test_fails_without_a_packed_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_set_server(tmp, "10.0.0.1")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("root.zip", result.stderr)


class ServerConfigureTests(unittest.TestCase):
    def run_configure(self, server_dir: Path, **env):
        full_env = dict(os.environ)
        full_env.update(env)
        full_env["SERVER_DIR"] = str(server_dir)
        return subprocess.run(
            ["bash", str(SERVER_SCRIPT), "configure"],
            text=True,
            capture_output=True,
            env=full_env,
        )

    def make_deploy(self, root: Path) -> Path:
        server_dir = root / "server"
        server_dir.mkdir()
        (server_dir / ".env.example").write_text(ENV_EXAMPLE)
        (server_dir / "docker-compose.yml").write_text("services: {}\n")
        return server_dir

    def test_creates_env_with_devkit_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            server_dir = self.make_deploy(Path(tmp))

            result = self.run_configure(server_dir, SERVER_APP_KEY="base64:test")
            self.assertEqual(result.returncode, 0, result.stderr)

            env = read_env(server_dir / ".env")
            self.assertEqual(env["WEB_APP_KEY"], "base64:test")
            self.assertEqual(env["WEB_EXTERNAL_PORT"], "8080")
            self.assertEqual(env["WEB_APP_URL"], "http://localhost:8080")
            self.assertEqual(env["PUBLIC_IP"], "127.0.0.1")
            self.assertEqual(env["MYSQL_EXTERNAL_PORT"], "3306")
            self.assertEqual(env["GAME_IMAGE"], "git.old-metin2.com/metin2/server:latest")

    def test_applies_overrides_and_keeps_the_existing_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            server_dir = self.make_deploy(Path(tmp))
            first = self.run_configure(server_dir, SERVER_APP_KEY="base64:first")
            self.assertEqual(first.returncode, 0, first.stderr)

            result = self.run_configure(
                server_dir,
                SERVER_APP_KEY="base64:second",
                SERVER_PUBLIC_IP="192.168.1.20",
                SERVER_WEB_PORT="9090",
                SERVER_MYSQL_PORT="3307",
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            env = read_env(server_dir / ".env")
            self.assertEqual(env["WEB_APP_KEY"], "base64:first")
            self.assertEqual(env["PUBLIC_IP"], "192.168.1.20")
            self.assertEqual(env["WEB_EXTERNAL_PORT"], "9090")
            self.assertEqual(env["WEB_APP_URL"], "http://localhost:9090")
            self.assertEqual(env["MYSQL_EXTERNAL_PORT"], "3307")

    def test_fails_when_the_deploy_checkout_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_configure(Path(tmp) / "missing", SERVER_APP_KEY="k")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("server.sh fetch", result.stderr)


if __name__ == "__main__":
    unittest.main()
