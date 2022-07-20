#!/bin/bash
# build_xcframeworks.sh OUTPUT DERIVED_DATA_PATH ARCHIVE_PATH
#  - OUTPUT: The output directory.
#  - DERIVED_DATA_PATH: The derived data path
#  - ARCHIVE_PATH: The archive path

set -o pipefail
set -ex

ROOT_PATH=`dirname "${0}"`/..
OUTPUT="$1"
DERIVED_DATA="$2"
ARCHIVE_PATH="$3"

mkdir -p "$OUTPUT"

##################
# Build Frameworks
##################

function build_archive {
  # $1 Project
  # $2 iOS or tvOS

  local scheme=$1
  local sdk=""
  local simulatorSdk=""
  local destination=""
  local simulatorDestination=""

  if [ $2 == "iOS" ]
  then
    sdk="iphoneos"
    destination="generic/platform=iOS"
    simulatorSdk="iphonesimulator"
    simulatorDestination="generic/platform=iOS Simulator"
  elif [ $2 == "maccatalyst" ]
  then
    destination="generic/platform=macOS,variant=Mac Catalyst,name=Any Mac"
  else
    sdk="appletvos"
    simulatorSdk="appletvsimulator"
    destination="generic/platform=tvOS"
    simulatorDestination="generic/platform=tvOS Simulator"
  fi

  if [ $2 == "maccatalyst" ]
  then
    xcrun xcodebuild archive -quiet \
    -workspace "$ROOT_PATH/Airship.xcworkspace" \
    -scheme "$scheme" \
    -destination "$destination" \
    -archivePath "$ARCHIVE_PATH/xcarchive/$scheme/mac.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
  else
    xcrun xcodebuild archive -quiet \
    -workspace "$ROOT_PATH/Airship.xcworkspace" \
    -scheme "$scheme" \
    -sdk "$sdk" \
    -destination "$destination" \
    -archivePath "$ARCHIVE_PATH/xcarchive/$scheme/$sdk.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

    xcrun xcodebuild archive -quiet \
    -workspace "$ROOT_PATH/Airship.xcworkspace" \
    -scheme "$scheme" \
    -sdk "$simulatorSdk" \
    -destination "$simulatorDestination" \
    -archivePath "$ARCHIVE_PATH/xcarchive/$scheme/$simulatorSdk.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
  fi
}

echo -ne "\n\n *********** BUILDING XCFRAMEWORKS *********** \n\n"

# tvOS
build_archive "AirshipRelease tvOS" "tvOS"

# iOS
build_archive "AirshipRelease" "iOS"
build_archive "AirshipNotificationServiceExtension" "iOS"
build_archive "AirshipNotificationContentExtension" "iOS"

# Catalyst
build_archive "AirshipRelease" "maccatalyst"
build_archive "AirshipNotificationServiceExtension" "maccatalyst"
build_archive "AirshipNotificationContentExtension" "maccatalyst"

# Package AirshipBasement
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -output "$OUTPUT/AirshipBasement.xcframework"

# Package AirshipCore
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -output "$OUTPUT/AirshipCore.xcframework"

# Package AirshipAutomation
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -output "$OUTPUT/AirshipAutomation.xcframework"

# Package AirshipMessageCenter
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -output "$OUTPUT/AirshipMessageCenter.xcframework"

# Package AirshipPreferenceCenter
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -output "$OUTPUT/AirshipPreferenceCenter.xcframework"

# Package AirshipExtendedActions
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
  -output "$OUTPUT/AirshipExtendedActions.xcframework"

# Package AirshipNotificationServiceExtension
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -output "$OUTPUT/AirshipNotificationServiceExtension.xcframework"

# Package AirshipNotificationContentExtension
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationContentExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationContentExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationContentExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
  -output "$OUTPUT/AirshipNotificationContentExtension.xcframework"