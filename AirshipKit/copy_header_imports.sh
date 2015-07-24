#!/bin/bash -ex

AIRSHIP_DIR="${SRCROOT}/../Airship"
FRAMEWORK_HEADERS_DIR="${BUILT_PRODUCTS_DIR}/AirshipKit.framework/Headers"

# Navigate to the public headers directory of the framework target and remove any existing headers

cd "$FRAMEWORK_HEADERS_DIR"
rm -rf *.h

# Find all public headers in the Airship directory, excluding UI
# Copy headers to the framework headers directory

cd "$AIRSHIP_DIR"
find . -type f -name '*.h' ! -name '*+Internal.h' ! -path './UI/*'\
  -exec cp {} "$FRAMEWORK_HEADERS_DIR/" \; \

