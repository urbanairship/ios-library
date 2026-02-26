#!/bin/bash

set -o pipefail
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

# Usage: run_xcodebuild.sh <scheme> <derived_data_path> [test|build]
# If no third parameter is provided, defaults to 'test'

SCHEME=$1
DERIVED_DATA_PATH=$2
TARGET_TYPE=${3:-test}

# Validate target type
if [[ "$TARGET_TYPE" != "test" && "$TARGET_TYPE" != "build" ]]; then
    echo "Error: Target type must be 'test' or 'build'"
    echo "Usage: run_xcodebuild.sh <scheme> <derived_data_path> [test|build]"
    exit 1
fi

# Validate required parameters
if [[ -z "$SCHEME" || -z "$DERIVED_DATA_PATH" ]]; then
    echo "Error: Missing required parameters"
    echo "Usage: run_xcodebuild.sh <scheme> <derived_data_path> [test|build]"
    exit 1
fi

if [[ "$TARGET_TYPE" == "test" ]]; then
    echo -ne "\n\n *********** RUNNING TESTS $SCHEME *********** \n\n"
    
    xcrun xcodebuild \
    -destination "${TEST_DESTINATION}" \
    -workspace "${ROOT_PATH}/Airship.xcworkspace" \
    -scheme $SCHEME \
    -derivedDataPath $DERIVED_DATA_PATH \
    test | xcbeautify --renderer $XCBEAUTIFY_RENDERER
else
    echo -ne "\n\n *********** BUILDING $SCHEME *********** \n\n"
    
    xcrun xcodebuild \
    -destination "${TEST_DESTINATION}" \
    -workspace "${ROOT_PATH}/Airship.xcworkspace" \
    -scheme $SCHEME \
    -derivedDataPath $DERIVED_DATA_PATH | xcbeautify --renderer $XCBEAUTIFY_RENDERER
fi
