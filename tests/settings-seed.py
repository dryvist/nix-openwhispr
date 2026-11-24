"""Checks the settings apply script against a scratch LevelDB store.

Usage: settings-seed.py APPLY RUNNING
  APPLY    apply script built with the sample settings and a not-running check
  RUNNING  apply script built with the same settings and a running check
"""

import subprocess
import sys
import tempfile

import plyvel

PREFIX = b"_file://\x00\x01"
apply_bin, running_bin = sys.argv[1], sys.argv[2]


def fail(msg):
    sys.exit(f"settings-seed: FAIL: {msg}")


def run(binary, db):
    out = subprocess.run([binary, db], capture_output=True, text=True, check=True)
    return out.stdout


def read(db, name):
    store = plyvel.DB(db)
    try:
        return store.get(PREFIX + name.encode())
    finally:
        store.close()


def new_store():
    db = tempfile.mkdtemp() + "/leveldb"
    store = plyvel.DB(db, create_if_missing=True)
    store.put(PREFIX + b"cleanupModel", b"\x01")
    store.put(PREFIX + b"uiTheme", b"\x01dark")
    store.close()
    return db


# A running app leaves the store unchanged.
db = new_store()
if "skipped, OpenWhispr is running" not in run(running_bin, db):
    fail("running check did not skip")
if read(db, "cleanupModel") != b"\x01":
    fail("running check changed the store")

# A missing store is skipped without an error.
if "settings store not found" not in run(apply_bin, tempfile.mkdtemp() + "/none"):
    fail("missing store was not skipped")

# The apply writes the derived and raw settings and leaves other keys alone.
out = run(apply_bin, db)
if "applied, 9 changed" not in out:
    fail(f"unexpected first apply output: {out!r}")
want = {
    "cleanupMode": b"\x01self-hosted",
    "cleanupRemoteUrl": b"\x01http://127.0.0.1:4100/v1",
    "cleanupModel": b"\x01fast",
    "transcriptionMode": b"\x01self-hosted",
    "remoteTranscriptionType": b"\x01openai-compatible",
    "remoteTranscriptionModel": b"\x01speech",
    "noteLabel": b"\x00" + "Notiz ✓".encode("utf-16-le"),
    "uiTheme": b"\x01dark",
}
for name, value in want.items():
    if read(db, name) != value:
        fail(f"{name} is {read(db, name)!r}, want {value!r}")

# A key name outside Latin-1 is stored as UTF-16LE, like a value.
store = plyvel.DB(db)
try:
    utf16_key = b"_file://\x00\x00" + "label\u2713".encode("utf-16-le")
    if store.get(utf16_key) != b"\x01x":
        fail("non-Latin-1 key name was not stored as UTF-16LE")
finally:
    store.close()

# A second apply changes nothing.
out = run(apply_bin, db)
if "applied, 0 changed" not in out:
    fail(f"second apply was not idempotent: {out!r}")

print("settings-seed: ok")
