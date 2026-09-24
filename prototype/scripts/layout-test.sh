#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before native layout checks.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
report_dir=$(mktemp -d "${TMPDIR:-/tmp}/radial-layout.XXXXXX")
printf 'Layout test artifacts: %s\n' "$report_dir"
open -W -n "$prototype_dir/build/RadialPrototype.app" --args --layout-test "$report_dir" "$@"
if [ -f "$report_dir/error.txt" ]; then
    cat "$report_dir/error.txt" >&2
    exit 1
fi
python3 "$prototype_dir/scripts/verify-layout.py" "$report_dir/report.json" \
    --output "$report_dir/analysis.json"
