#!/bin/bash -ex

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=$SCRIPT_DIRECTORY/..

if [[ $# -lt 2 ]]; then
    echo "Usage: $1 common OS-SPECIFIER"
    echo "  where: OS-SPECIFIER = ios, tvos, macos, etc."
    exit 1
fi

echo "$ROOT_PATH"
SOURCE_LIB_HEADER="$ROOT_PATH/AirshipKit/$2/AirshipLib.h"

# Find all public headers, excluding AirshipLib and UI
# Collect all headers as obj-c import statments into an umbrella header
rm "$SOURCE_LIB_HEADER" 2>/dev/null || true
touch "$SOURCE_LIB_HEADER"

echo "Generated file: ${SOURCE_LIB_HEADER}"

for headerSubfolder in "$@"
do
    if [[ -d "$ROOT_PATH"/AirshipKit/${headerSubfolder} ]]; then
        find "$ROOT_PATH"/AirshipKit/${headerSubfolder} -type f -name '*.h' ! -name 'AirshipLib.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h' ! -path './UI/*' \
    -exec basename {} \; | awk '{print "#import \"" $1"\""}' >> "$SOURCE_LIB_HEADER"
    fi
done
