#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
swift test --package-path "$prototype_dir"
python3 -m unittest discover -s "$prototype_dir/Tests/RecordingTests"
