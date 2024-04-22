#!/bin/bash
# test_package.sh PACKAGE
#  - PACKAGE: The package type.

set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..
PACKAGE="$1"

TARGET_SDK='iphonesimulator'
TARGET='TestApp'
PROJECT="TestAPP.$PACKAGE"
YAML="$PACKAGE.yaml"

echo -ne "\n\n *********** GENERATING $PROJECT  *********** \n\n"
cd $ROOT_PATH/TestApps
xcodegen generate --spec $YAML
cd -

echo -ne "\n\n *********** BUILDING $TARGET *********** \n\n"

# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
xcrun xcodebuild \
-configuration Debug \
-project "${ROOT_PATH}/TestApps/$PROJECT.xcodeproj" \
-scheme $TARGET \
-sdk $TARGET_SDK \
-derivedDataPath "$DERIVED_DATA" | xcbeautify --renderer $XCBEAUTIY_RENDERER

# Clean up
rm -rf "${ROOT_PATH}/TestApps/$PROJECT.xcodeproj"

