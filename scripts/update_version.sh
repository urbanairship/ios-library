#!/bin/bash
VERSION=$1
ROOT_PATH=`dirname "${0}"`/../

if [ -z "$1" ]
  then
    echo "No version number supplied"
    exit 1
fi

# Initialize counters
FAILED_COUNT=0
SUCCESS_COUNT=0

echo "Updating version to $VERSION"
echo ""

# Pods
if sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/Airship.podspec 2>/dev/null; then
  echo "✓ Airship.podspec"
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
else
  echo "✗ Airship.podspec"
  FAILED_COUNT=$((FAILED_COUNT+1))
fi

if sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/AirshipDebug.podspec 2>/dev/null; then
  echo "✓ AirshipDebug.podspec"
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
else
  echo "✗ AirshipDebug.podspec"
  FAILED_COUNT=$((FAILED_COUNT+1))
fi

if sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/AirshipServiceExtension.podspec 2>/dev/null; then
  echo "✓ AirshipServiceExtension.podspec"
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
else
  echo "✗ AirshipServiceExtension.podspec"
  FAILED_COUNT=$((FAILED_COUNT+1))
fi

# Airship Config
if sed -i '' "s/\CURRENT_PROJECT_VERSION.*/CURRENT_PROJECT_VERSION = $VERSION/g" $ROOT_PATH/Airship/AirshipConfig.xcconfig 2>/dev/null; then
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
