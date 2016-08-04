#!/bin/bash -ex

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../

VERSION=$(awk <${ROOT_PATH}/AirshipLib/Config.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

appledoc --project-name "Urban Airship iOS Library $VERSION" --templates "${ROOT_PATH}/docs/doc_templates" --output "${ROOT_PATH}/build/docs" --exit-threshold 2 ${ROOT_PATH}/Airship ${ROOT_PATH}/AirshipAppExtensions
