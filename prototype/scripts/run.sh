#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before rebuilding and launching.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
open "$prototype_dir/build/RadialPrototype.app" --args "$@"
