"""Write string settings into OpenWhispr's renderer localStorage.

Usage: settings.py LEVELDB_DIR SETTINGS_JSON

Electron keeps localStorage in a Chromium LevelDB database. A key is
"_" + origin + "\\x00\\x01" + name, and a value is a format byte followed by
the text: 1 for Latin-1, 0 for UTF-16LE. The app loads its pages from file://.
"""

import json
import sys

import plyvel

PREFIX = b"_file://\x00\x01"


def encode(value):
    try:
        return b"\x01" + value.encode("latin-1")
    except UnicodeEncodeError:
        return b"\x00" + value.encode("utf-16-le")


def main(db_path, settings_path):
    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)
    db = plyvel.DB(db_path, create_if_missing=False)
    try:
        changed = 0
        # One batch, so a failure leaves every key as it was.
        with db.write_batch(transaction=True) as batch:
            for name, value in sorted(settings.items()):
                key = PREFIX + name.encode("latin-1")
                want = encode(value)
                if db.get(key) != want:
                    batch.put(key, want)
                    changed += 1
    finally:
        db.close()
    print(f"openwhispr settings: applied, {changed} changed")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
