#!/bin/bash -ex

VERSION=$(awk <AirshipLib/Config.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

appledoc --project-name "Urban Airship iOS Library $VERSION" --exit-threshold 2 Airship
