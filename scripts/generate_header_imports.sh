#!/bin/bash -ex

AIRSHIP_DIR="${SRCROOT}/../Airship"
FRAMEWORK_HEADERS_DIR="${BUILT_PRODUCTS_DIR}/AirshipKit.framework/Headers"

# Navigate to the public headers directory of the framework target and remove any existing headers
#cd $FRAMEWORK_HEADERS_DIR
#rm -r *.h

# Navigate to the Airship directory
cd $AIRSHIP_DIR

# Find all public headers, excluding AirshipLib, internal classes, and UI
# Copy headers to the framework headers directory
# Collect all headers as obj-c import statments into an umbrella header named AirshipLib.h
find . -type f -name '*.h' ! -name 'AirshipLib.h' ! -name '*+Internal.h' ! -path './UI/*'\
  -exec cp {} $FRAMEWORK_HEADERS_DIR/ \; \
  -exec basename {} \; | awk '{print "#import \"" $0"\""}' > $FRAMEWORK_HEADERS_DIR/AirshipLib.h

