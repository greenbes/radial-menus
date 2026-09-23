#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before the lifecycle process tests.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
report_dir=$(mktemp -d "${TMPDIR:-/tmp}/radial-lifecycle.XXXXXX")
printf 'Lifecycle test artifacts: %s\n' "$report_dir"
python3 "$prototype_dir/scripts/verify-shutdown.py" \
    "$prototype_dir/build/RadialPrototype.app/Contents/MacOS/RadialPrototype" "$report_dir"
