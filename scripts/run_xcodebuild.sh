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

EXTRA_TEST_FLAGS=()

# Test parallelization is off for two independent reasons.
#
# Some targets (e.g. AirshipCore) exercise the process-global `Airship` singleton
# via `TestAirshipInstance.makeShared()`, and race on it under Swift Testing's
# default parallel execution.
#
# On top of that, parallel testing deadlocks on the Xcode 27 simulator runtime:
# tests stall in a ~20-30s band and release together, then xcodebuild never exits
# and the runner kills the job with no test having failed. See
# actions/runner-images#13143 and #13264. Nothing about that is scheme-specific --
# automation and message-center hit it first only because they have the most
# tests -- so this applies to every scheme rather than an allowlist.
#
# The second reason goes away once the runner image is fixed; the first does not.
EXTRA_TEST_FLAGS+=(-parallel-testing-enabled NO)

if [[ "$TARGET_TYPE" == "test" ]]; then
    echo -ne "\n\n *********** RUNNING TESTS $SCHEME *********** \n\n"
    
    xcrun xcodebuild \
    -destination "${TEST_DESTINATION}" \
    -workspace "${ROOT_PATH}/Airship.xcworkspace" \
    -scheme $SCHEME \
    -derivedDataPath $DERIVED_DATA_PATH \
    "${EXTRA_TEST_FLAGS[@]}" \
    test | xcbeautify --renderer $XCBEAUTIFY_RENDERER
else
    echo -ne "\n\n *********** BUILDING $SCHEME *********** \n\n"
    
    xcrun xcodebuild \
    -destination "${TEST_DESTINATION}" \
    -workspace "${ROOT_PATH}/Airship.xcworkspace" \
    -scheme $SCHEME \
    -derivedDataPath $DERIVED_DATA_PATH | xcbeautify --renderer $XCBEAUTIFY_RENDERER
fi
