#!/bin/bash -ex
FRAMEWORK_HEADERS_DIR="${BUILT_PRODUCTS_DIR}/AirshipKit.framework/Headers"
SOURCE_LIB_HEADER="${SRCROOT}/AirshipKit/AirshipLib.h"
TARGET_LIB_HEADER="${FRAMEWORK_HEADERS_DIR}/AirshipLib.h"

# If there's already an AirshipLib.h in the framework headers directory
if [ -a "${FRAMEWORK_HEADERS_DIR}/AirshipLib.h" ]; then
    # If the contents haven't changed, exit early
    if diff -q "${SOURCE_LIB_HEADER}" "${TARGET_LIB_HEADER}" > /dev/null; then
        exit 0
    fi
fi

# Navigate to the public headers directory of the framework target and remove any existing headers
rm -rf $FRAMEWORK_HEADERS_DIR/*.h

# Find all public headers
find ${SRCROOT}/AirshipKit -type f -name '*.h' ! -name '*+Internal*.h' ! -path './UI/*'\
  -exec cp {} "$FRAMEWORK_HEADERS_DIR/" \; \

