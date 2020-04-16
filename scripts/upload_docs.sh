#!/bin/bash -ex
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..
AIRSHIP_VERSION=$(bash "$ROOT_PATH/scripts/airship_version.sh")

gsutil cp $ROOT_PATH/build/Documentation.tar.gz gs://ua-web-ci-prod-docs-transfer/libraries/ios/$AIRSHIP_VERSION.tar.gz