#!/usr/bin/env python3
"""Point a packaged client at a game server.

The client reads the auth, channel and mark server addresses from
serverinfo.py inside pack/root.zip; every entry uses SERVER_IP. This rewrites
that one assignment in place, so the ports keep matching the old-metin2 deploy
stack (auth 11000, CH1 13000).

Usage: set-server.py <dist> <ip-or-hostname>
"""

import os
import re
import shutil
import sys
import tempfile
import zipfile

ADDRESS = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.\-]*$")
SERVER_IP = re.compile(r'^(SERVER_IP\s*=\s*)"[^"]*"', re.MULTILINE)


def fail(message):
    sys.stderr.write("set-server: %s\n" % message)
    sys.exit(1)


def main(argv):
    if len(argv) != 3:
        fail("usage: set-server.py <dist> <ip-or-hostname>")
    dist, address = argv[1], argv[2]
    if not ADDRESS.match(address):
        fail("invalid server address: %r" % address)

    archive_path = os.path.join(dist, "pack", "root.zip")
    if not os.path.isfile(archive_path):
        fail("%s not found; package the client with its packs first" % archive_path)

    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
        names = [e.filename for e in entries]
        if "serverinfo.py" not in names:
            fail("serverinfo.py is missing from %s" % archive_path)
        source = archive.read("serverinfo.py").decode("latin-1")
        updated, count = SERVER_IP.subn(r'\g<1>"%s"' % address, source)
        if count != 1:
            fail("expected one SERVER_IP assignment in serverinfo.py, found %d" % count)

        fd, tmp_path = tempfile.mkstemp(suffix=".zip", dir=os.path.dirname(archive_path))
        os.close(fd)
        try:
            with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as out:
                for entry in entries:
                    data = archive.read(entry.filename)
                    if entry.filename == "serverinfo.py":
                        data = updated.encode("latin-1")
                    out.writestr(entry, data)
        except Exception:
            os.remove(tmp_path)
            raise

    shutil.move(tmp_path, archive_path)
    print("set-server: %s now points at %s" % (archive_path, address))


if __name__ == "__main__":
    main(sys.argv)
