#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before native desktop checks.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
report_dir=$(mktemp -d "${TMPDIR:-/tmp}/radial-desktop.XXXXXX")
printf 'Desktop test artifacts: %s\n' "$report_dir"
open -W -n "$prototype_dir/build/RadialPrototype.app" --args --desktop-test "$report_dir" "$@"
python3 - "$report_dir/report.json" <<'PY'
import json
import sys
from pathlib import Path
report = json.loads(Path(sys.argv[1]).read_text())
assert report["passed"], report.get("error")
assert len(report["checks"]) == 4
assert len({s["screen"] for s in report["samples"]}) >= 2
for check in report["checks"]:
    print("PASS:", check)
print(f'{len(report["samples"])} native movement observations across displays')
PY
