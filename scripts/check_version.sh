#!/bin/bash
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

VERSION=$(awk <$ROOT_PATH/Airship/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

if [ $1 = $VERSION ]; then
 exit 0
else
 exit 1
fi
