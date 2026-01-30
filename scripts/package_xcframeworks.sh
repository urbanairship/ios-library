#!/bin/bash
# package_xcframeworks.sh OUTPUT INPUT_DIR [ZIP_ROOT]
#  - OUTPUT: The output zip.
#  - INPUT_DIR: A path to the xcframeworks directory to package
#  - ZIP_ROOT: Optional root folder inside the zip (default: xcframeworks)

set -o pipefail
set -e

ZIP_ROOT="${3:-xcframeworks}"
TEMP="$(mktemp -d)"
mkdir -p "$TEMP/$ZIP_ROOT"

cp -R "$2" "$TEMP/$ZIP_ROOT"
cd "$TEMP"

zip -r --symlinks xcframeworks.zip "${ZIP_ROOT%%/}" -x "*.DS_Store"
cd -

cp "$TEMP/xcframeworks.zip" "$1"
