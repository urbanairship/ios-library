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
FULL_ARCHIVE_PATH="$(pwd -P)/$ARCHIVE_PATH"

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
  elif [ $2 == "visionOS" ]
  then
    sdk="xros"
    destination="generic/platform=visionOS"
    simulatorSdk="xrsimulator"
    simulatorDestination="generic/platform=visionOS Simulator"
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
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES | xcbeautify --renderer $XCBEAUTIY_RENDERER
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
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES | xcbeautify --renderer $XCBEAUTIY_RENDERER
  fi
}

echo -ne "\n\n *********** BUILDING XCFRAMEWORKS *********** \n\n"

# tvOS
build_archive "AirshipRelease tvOS" "tvOS"

# iOS
build_archive "AirshipRelease" "iOS"
build_archive "AirshipNotificationServiceExtension" "iOS"

# Catalyst
build_archive "AirshipRelease" "maccatalyst"
build_archive "AirshipNotificationServiceExtension" "maccatalyst"

# visionOS
build_archive "AirshipRelease" "visionOS"

# Package AirshipBasement
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipBasement.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/dSYMs/AirshipBasement.framework.dSYM" \
  -output "$OUTPUT/AirshipBasement.xcframework"

# Package AirshipCore
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/dSYMs/AirshipCore.framework.dSYM" \
  -output "$OUTPUT/AirshipCore.xcframework"


  # Package AirshipAutomation
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipAutomation.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipAutomation.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipAutomation.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipAutomation.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipAutomation.framework.dSYM" \
  -output "$OUTPUT/AirshipAutomation.xcframework"

# Package AirshipMessageCenter
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipMessageCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipMessageCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipMessageCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipMessageCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipMessageCenter.framework.dSYM" \
  -output "$OUTPUT/AirshipMessageCenter.xcframework"

# Package AirshipPreferenceCenter
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipPreferenceCenter.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/dSYMs/AirshipPreferenceCenter.framework.dSYM" \
  -output "$OUTPUT/AirshipPreferenceCenter.xcframework"

# Package AirshipFeatureFlags
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvos.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipFeatureFlags.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease tvOS/appletvsimulator.xcarchive/dSYMs/AirshipFeatureFlags.framework.dSYM" \
  -output "$OUTPUT/AirshipFeatureFlags.xcframework"

# Package AirshipObjectiveC
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/Products/Library/Frameworks/AirshipObjectiveC.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphoneos.xcarchive/dSYMs/AirshipObjectiveC.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipObjectiveC.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/iphonesimulator.xcarchive/dSYMs/AirshipObjectiveC.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/Products/Library/Frameworks/AirshipObjectiveC.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xros.xcarchive/dSYMs/AirshipObjectiveC.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/Products/Library/Frameworks/AirshipObjectiveC.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/xrsimulator.xcarchive/dSYMs/AirshipObjectiveC.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/Products/Library/Frameworks/AirshipObjectiveC.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipRelease/mac.xcarchive/dSYMs/AirshipObjectiveC.framework.dSYM" \
  -output "$OUTPUT/AirshipObjectiveC.xcframework"
  
# Package AirshipNotificationServiceExtension
xcrun xcodebuild -create-xcframework \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/iphoneos.xcarchive/dSYMs/AirshipNotificationServiceExtension.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/mac.xcarchive/dSYMs/AirshipNotificationServiceExtension.framework.dSYM" \
  -framework "$ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -debug-symbols "$FULL_ARCHIVE_PATH/xcarchive/AirshipNotificationServiceExtension/iphonesimulator.xcarchive/dSYMs/AirshipNotificationServiceExtension.framework.dSYM" \
  -output "$OUTPUT/AirshipNotificationServiceExtension.xcframework"


# Sign the frameworks
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipBasement.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipCore.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipMessageCenter.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipPreferenceCenter.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipNotificationServiceExtension.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipFeatureFlags.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipAutomation.xcframework"
codesign --timestamp -v --sign "Apple Distribution: Urban Airship Inc. (PGJV57GD94)" "$OUTPUT/AirshipObjectiveC.xcframework"
