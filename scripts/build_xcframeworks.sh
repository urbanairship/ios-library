#!/bin/bash
# build_xcframeworks.sh OUTPUT DERIVED_DATA_PATH ARCHIVE_PATH
#  - OUTPUT: The output directory.
#  - DERIVED_DATA_PATH: The derived data path
#  - ARCHIVE_PATH: The archive path

set -o pipefail
set -e

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
  # $2 Scheme
  # $3 iOS or tvOS

  local project=$1
  local scheme=$2
  local sdk=""
  local simulatorSdk=""
  local destination=""
  local simulatorDestination=""

  if [ $3 == "iOS" ]
  then
    sdk="iphoneos"
    simulatorSdk="iphonesimulator"
    destination="iOS"
    simulatorDestination="iOS Simulator"
  elif [ $3 == "maccatalyst" ]
  then
    destination="platform=macOS, arch=x86_64, variant=Mac Catalyst"
  else
    sdk="appletvos"
    simulatorSdk="appletvsimulator"
    destination="tvOS"
    simulatorDestination="tvOS Simulator"
  fi

  if [ $3 == "maccatalyst" ]
  then
    xcrun xcodebuild archive -quiet \
    -project "$ROOT_PATH/$project/$project.xcodeproj" \
    -scheme "$scheme" \
    -destination="$destination" \
    -archivePath "$ARCHIVE_PATH/xcarchive/$project/$scheme/mac.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
  else
    xcrun xcodebuild archive -quiet \
    -project "$ROOT_PATH/$project/$project.xcodeproj" \
    -scheme "$scheme" \
    -sdk "$sdk" \
    -destination="$destination" \
    -archivePath "$ARCHIVE_PATH/xcarchive/$project/$scheme/$sdk.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

    xcrun xcodebuild archive -quiet \
    -project "$ROOT_PATH/$project/$project.xcodeproj" \
    -scheme "$scheme" \
    -sdk "$simulatorSdk" \
    -destination="$simulatorDestination" \
    -archivePath "$ARCHIVE_PATH/xcarchive/$project/$scheme/$simulatorSdk.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
  fi
}

echo -ne "\n\n *********** BUILDING XCFRAMEWORKS *********** \n\n"

build_archive "Airship" "AirshipCore" "iOS"
build_archive "Airship" "AirshipCore" "maccatalyst"
build_archive "Airship" "AirshipCore tvOS" "tvOS"
build_archive "Airship" "AirshipLocation" "iOS"
build_archive "Airship" "AirshipLocation" "maccatalyst"
build_archive "Airship" "AirshipDebug" "iOS"
build_archive "Airship" "AirshipDebug" "maccatalyst"
build_archive "Airship" "AirshipAutomation" "iOS"
build_archive "Airship" "AirshipAutomation" "maccatalyst"
build_archive "Airship" "AirshipAccengage" "iOS"
build_archive "Airship" "AirshipAccengage" "maccatalyst"
build_archive "Airship" "AirshipMessageCenter" "iOS"
build_archive "Airship" "AirshipMessageCenter" "maccatalyst"
build_archive "Airship" "AirshipChat" "iOS"
build_archive "Airship" "AirshipChat" "maccatalyst"
build_archive "Airship" "AirshipExtendedActions" "iOS"
build_archive "Airship" "AirshipExtendedActions" "maccatalyst"
build_archive "AirshipExtensions" "AirshipNotificationServiceExtension" "iOS"
build_archive "AirshipExtensions" "AirshipNotificationServiceExtension" "maccatalyst"
build_archive "AirshipExtensions" "AirshipNotificationContentExtension" "iOS"
build_archive "AirshipExtensions" "AirshipNotificationContentExtension" "maccatalyst"

# Package AirshipCore
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipCore/iphoneos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipCore/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipCore/mac.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipCore tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipCore tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
-output "$OUTPUT/AirshipCore.xcframework"

# Package AirshipLocation
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipLocation/iphoneos.xcarchive/Products/Library/Frameworks/AirshipLocation.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipLocation/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipLocation.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipLocation/mac.xcarchive/Products/Library/Frameworks/AirshipLocation.framework" \
-output "$OUTPUT/AirshipLocation.xcframework"

# Package AirshipAutomation
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipAutomation/iphoneos.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipAutomation/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipAutomation/mac.xcarchive/Products/Library/Frameworks/AirshipAutomation.framework" \
-output "$OUTPUT/AirshipAutomation.xcframework"

# Package AirshipMessageCenter
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipMessageCenter/iphoneos.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipMessageCenter/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipMessageCenter/mac.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
-output "$OUTPUT/AirshipMessageCenter.xcframework"

# Package AirshipChat
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipChat/iphoneos.xcarchive/Products/Library/Frameworks/AirshipChat.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipChat/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipChat.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipChat/mac.xcarchive/Products/Library/Frameworks/AirshipChat.framework" \
-output "$OUTPUT/AirshipChat.xcframework"

# Package AirshipExtendedActions
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipExtendedActions/iphoneos.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipExtendedActions/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipExtendedActions/mac.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
-output "$OUTPUT/AirshipExtendedActions.xcframework"

# Package AirshipAccengage
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipAccengage/iphoneos.xcarchive/Products/Library/Frameworks/AirshipAccengage.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipAccengage/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipAccengage.framework" \
-framework "$ARCHIVE_PATH/xcarchive/Airship/AirshipAccengage/mac.xcarchive/Products/Library/Frameworks/AirshipAccengage.framework" \
-output "$OUTPUT/AirshipAccengage.xcframework"

# Package AirshipNotificationServiceExtension
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/AirshipExtensions/AirshipNotificationServiceExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
-framework "$ARCHIVE_PATH/xcarchive/AirshipExtensions/AirshipNotificationServiceExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
-framework "$ARCHIVE_PATH/xcarchive/AirshipExtensions/AirshipNotificationServiceExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
-output "$OUTPUT/AirshipNotificationServiceExtension.xcframework"

# Package AirshipNotificationContentExtension
xcodebuild -create-xcframework \
-framework "$ARCHIVE_PATH/xcarchive/AirshipExtensions/AirshipNotificationContentExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
-framework "$ARCHIVE_PATH/xcarchive/AirshipExtensions/AirshipNotificationContentExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
-framework "$ARCHIVE_PATH/xcarchive/AirshipExtensions/AirshipNotificationContentExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
-output "$OUTPUT/AirshipNotificationContentExtension.xcframework"