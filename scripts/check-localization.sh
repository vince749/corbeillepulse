#!/bin/bash
# Fails if a string used in the code has no English translation (or a translation is unused).
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'command rm -rf "$out"' EXIT
swift build -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$out" >/dev/null
python3 - "$out" Resources/en.lproj/Localizable.strings <<'PY'
import glob, json, plistlib, subprocess, sys
used = set()
for path in glob.glob(sys.argv[1] + "/*.stringsdata"):
    for entries in json.load(open(path)).get("tables", {}).values():
        used.update(entry["key"] for entry in entries)
xml = subprocess.run(["plutil", "-convert", "xml1", "-o", "-", sys.argv[2]], check=True, capture_output=True).stdout
translated = set(plistlib.loads(xml))
missing, unused = sorted(used - translated), sorted(translated - used)
for key in missing: print("missing English:", key)
for key in unused: print("unused English:", key)
print(f"{len(used)} strings, {len(missing)} missing, {len(unused)} unused")
sys.exit(1 if missing or unused else 0)
PY
