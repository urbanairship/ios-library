#!/bin/bash -ex

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 common OS-SPECIFIER"
    echo "  where: OS-SPECIFIER = ios, tvos, macos, etc."
    exit 1
fi

SOURCE_LIB_HEADER="${SRCROOT}/AirshipKit/common/AirshipLib.h"

# Find all public headers, excluding AirshipLib and UI
# Collect all headers as obj-c import statments into an umbrella header
rm "$SOURCE_LIB_HEADER" 2>/dev/null || true
touch "$SOURCE_LIB_HEADER"

for headerSubfolder in "$@"
do
    if [[ -d "${SRCROOT}"/AirshipKit/${headerSubfolder} ]]; then
        find "${SRCROOT}"/AirshipKit/${headerSubfolder} -type f -name '*.h' ! -name 'AirshipLib.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h' ! -path './UI/*' \
    -exec basename {} \; | awk '{print "#import \"" $0"\""}' >> "$SOURCE_LIB_HEADER"
    fi
done
