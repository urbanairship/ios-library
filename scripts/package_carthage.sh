#!/bin/bash
# build_docs.sh OUTPUT [PATHS...]
#  - OUTPUT: The output zip.
#  - Path: A path to the xcframeworks

set -o pipefail
set -e


TEMP="$(mktemp -d)"
mkdir -p "$TEMP/Carthage/build"

cp -R $2 "$TEMP/Carthage/build"
cd  $TEMP

zip -r --symlinks xcframeworks.zip Carthage -x "*.DS_Store"
cd - 

cp "$TEMP/xcframeworks.zip" $1
