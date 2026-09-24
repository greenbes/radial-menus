#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before the native smoke test.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
report_dir=$(mktemp -d "${TMPDIR:-/tmp}/radial-native.XXXXXX")
printf 'Native test artifacts: %s\n' "$report_dir"
open -W -n "$prototype_dir/build/RadialPrototype.app" --args \
    --smoke-test "$report_dir/report.json" --record "$report_dir/events.log" "$@"
python3 - "$report_dir/report.json" <<'PY'
import json
import sys
from pathlib import Path

result = json.loads(Path(sys.argv[1]).read_text())
for check in result["checks"]:
    print("PASS:", check)
print("Controllers:", result["controllers"])
if not result["passed"]:
    print("FAIL:", result["error"], file=sys.stderr)
    raise SystemExit(1)
PY
