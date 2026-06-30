#!/bin/bash
VERSION=$1
ROOT_PATH=`dirname "${0}"`/../

if [ -z "$1" ]
  then
    echo "No version number supplied"
    exit 1
fi

# Strip any pre-release suffix (e.g. 21.0.0-beta.1 -> 21.0.0) for the numeric
# build version. CURRENT_PROJECT_VERSION feeds CFBundleVersion, which must be
# period-separated integers. The full version (with suffix) lives in
# AirshipVersion.swift.
BUILD_VERSION="${VERSION%%-*}"

# Initialize counters
FAILED_COUNT=0
SUCCESS_COUNT=0

echo "Updating version to $VERSION (build version $BUILD_VERSION)"
echo ""

# Airship Config
if sed -i '' "s/\CURRENT_PROJECT_VERSION.*/CURRENT_PROJECT_VERSION = $BUILD_VERSION/g" $ROOT_PATH/Airship/AirshipConfig.xcconfig 2>/dev/null; then
  echo "✓ Airship/AirshipConfig.xcconfig"
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
else
  echo "✗ Airship/AirshipConfig.xcconfig"
  FAILED_COUNT=$((FAILED_COUNT+1))
fi

# AirshipVersion.swift
if sed -i '' "s/\(public static let version *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/Airship/AirshipCore/Source/AirshipVersion.swift 2>/dev/null; then
  echo "✓ Airship/AirshipCore/Source/AirshipVersion.swift"
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
else
  echo "✗ Airship/AirshipCore/Source/AirshipVersion.swift"
  FAILED_COUNT=$((FAILED_COUNT+1))
fi

# Summary
echo ""
if [ $FAILED_COUNT -gt 0 ]; then
  echo "⚠️  $SUCCESS_COUNT succeeded, $FAILED_COUNT failed"
  exit 1
else
  echo "✓ All $SUCCESS_COUNT files updated successfully"
  exit 0
fi
