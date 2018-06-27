#!/bin/bash -ex

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH="${SCRIPT_DIRECTORY}/.."

if [[ $# -lt 2 ]]; then
    echo "Usage: $1 common OS-SPECIFIER"
    echo "  where: OS-SPECIFIER = ios, tvos, macos, etc."
    exit 1
fi

echo "${ROOT_PATH}"
TMP_LIB="${DERIVED_FILE_DIR}/GeneratedHeader/$2"
TMP_LIB_HEADER="${TMP_LIB}/AirshipLib.h"
SOURCE_LIB_HEADER="${ROOT_PATH}/AirshipKit/$2/AirshipLib.h"

# Find all public headers, excluding AirshipLib and UI
# Collect all headers as obj-c import statments into an umbrella header
rm "${TMP_LIB_HEADER}" 2>/dev/null || true
mkdir -p "${TMP_LIB}" && touch "${TMP_LIB_HEADER}"

echo "Generated file: ${TMP_LIB_HEADER}"

for headerSubfolder in "$@"
do
    if [[ -d "${ROOT_PATH}"/AirshipKit/${headerSubfolder} ]]; then
        find -s "${ROOT_PATH}"/AirshipKit/${headerSubfolder} -type f -name '*.h' ! -name 'AirshipLib.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h' ! -path './UI/*' \
    -exec basename {} \; | awk '{print "#import \"" $1"\""}' >> "${TMP_LIB_HEADER}"
    fi
done

# If there's already an AirshipLib.h in the framework headers directory
if [ -a "${SOURCE_LIB_HEADER}" ]; then
    # If the contents haven't changed, exit early
    if diff -q "${SOURCE_LIB_HEADER}" "${TMP_LIB_HEADER}" > /dev/null; then
        exit 0
    fi
fi

echo "Generated file: ${SOURCE_LIB_HEADER}"

cp "${TMP_LIB_HEADER}" "${SOURCE_LIB_HEADER}"

