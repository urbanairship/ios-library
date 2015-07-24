#!/bin/bash -ex

AIRSHIP_DIR="${SRCROOT}/../Airship"

# Navigate to the Airship directory
cd "$AIRSHIP_DIR"

# Find all public headers, excluding AirshipLib and UI
# Collect all headers as obj-c import statments into an umbrella header named AirshipLib.h
find . -type f -name '*.h' ! -name 'AirshipLib.h' ! -name '*+Internal.h' ! -path './UI/*'\
  -exec basename {} \; | awk '{print "#import \"" $0"\""}' > AirshipLib.h

