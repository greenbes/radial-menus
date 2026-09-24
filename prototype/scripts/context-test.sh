#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if pgrep -x RadialPrototype >/dev/null; then
    printf '%s\n' 'Quit the running prototype before native context checks.' >&2
    exit 2
fi
"$prototype_dir/scripts/build.sh"
report_dir=$(mktemp -d "${TMPDIR:-/tmp}/radial-context.XXXXXX")
printf 'Context test artifacts: %s\n' "$report_dir"
open -W -n "$prototype_dir/build/RadialPrototype.app" --args --context-test "$report_dir"
if [ -f "$report_dir/error.txt" ]; then
    cat "$report_dir/error.txt" >&2
    exit 1
fi
python3 - "$report_dir/report.json" <<'PY'
import json
import sys
from pathlib import Path
report = json.loads(Path(sys.argv[1]).read_text())
assert report["passed"] is True
assert len(report["scenes"]) == 18
assert {scene["appearance"] for scene in report["scenes"]} == {
    "NSAppearanceNameAqua", "NSAppearanceNameDarkAqua", "NSAppearanceNameAqua-reduced-motion"
}
assert all(len(scene["states"]) == 5 for scene in report["scenes"])
assert sum("12 recurring context labels shrink" in check for check in report["checks"]) == 3
assert sum("returning restores" in check for check in report["checks"]) == 3
assert sum(scene["inertHistoryClicks"] for scene in report["scenes"]) == 108
for scene in report["scenes"]:
    assert len(scene["arcs"]) == len(scene["path"]) - 1
    assert [arc["distance"] for arc in scene["arcs"]] == list(range(1, len(scene["path"])))
    for near, far in zip(scene["arcs"], scene["arcs"][1:]):
        assert far["radius"] > near["radius"]
        assert far["length"] < near["length"]
print(f'{len(report["scenes"])} native scenes and {sum(len(scene["states"]) for scene in report["scenes"])} selection states passed')
print('36 native label comparisons shrink with depth; returning restores their sizes in all three presentations')
print('108 history-label clicks are inert; each earlier level occupies a separate, shorter outer arc')
PY
