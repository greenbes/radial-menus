#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before native choice-list checks.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
report_dir=$(mktemp -d "${TMPDIR:-/tmp}/radial-choices.XXXXXX")
printf 'Choice test artifacts: %s\n' "$report_dir"
open -W -n "$prototype_dir/build/RadialPrototype.app" --args --choices-test "$report_dir"
if [ -f "$report_dir/error.txt" ]; then
    cat "$report_dir/error.txt" >&2
    exit 1
fi
cat "$report_dir/report.json"
