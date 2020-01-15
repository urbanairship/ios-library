#!/bin/bash -ex
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

VERSION=$(awk <$ROOT_PATH/Airship/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

gsutil cp $ROOT_PATH/build/Documentation.tar.gz gs://ua-web-ci-prod-docs-transfer/libraries/ios/$VERSION.tar.gz