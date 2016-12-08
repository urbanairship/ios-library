#!/bin/bash -ex

SOURCE_LIB_HEADER="${SRCROOT}/AirshipKit/AirshipLib.h"

# Find all public headers, excluding AirshipLib and UI
# Collect all headers as obj-c import statments into an umbrella header
find ${SRCROOT}/AirshipKit -type f -name '*.h' ! -name 'AirshipLib.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h' ! -path './UI/*'\
  -exec basename {} \; | awk '{print "#import \"" $0"\""}' > $SOURCE_LIB_HEADER


