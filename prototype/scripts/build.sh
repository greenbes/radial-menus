#!/bin/sh
set -eu
prototype_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
swift build --package-path "$prototype_dir" --product RadialPrototype
binary_dir=$(swift build --package-path "$prototype_dir" --show-bin-path)
bundle_dir="$prototype_dir/build/RadialPrototype.app"
mkdir -p "$bundle_dir/Contents/MacOS"
cp "$binary_dir/RadialPrototype" "$bundle_dir/Contents/MacOS/RadialPrototype"
cp "$prototype_dir/Support/Info.plist" "$bundle_dir/Contents/Info.plist"
codesign --force --sign - "$bundle_dir"
printf '%s\n' "$bundle_dir"
