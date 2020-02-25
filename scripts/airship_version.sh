#!/bin/bash

set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..
echo $(awk <"$ROOT_PATH/Airship/AirshipConfig.xcconfig" "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")
