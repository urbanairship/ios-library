#!/bin/bash
#
# build.sh [XCODE_PATH]
#  - XCODE_PATH: Used to override the Xcode version. Defaults to the version in config.sh.

set -o pipefail
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..
AIRSHIP_VERSION=$(bash "$ROOT_PATH/scripts/airship_version.sh")

source "$ROOT_PATH/scripts/config.sh"
DEVELOPER_DIR=$(bash "$ROOT_PATH/scripts/get_xcode_path.sh" $2)

TEMP_DIR=$(mktemp -d /tmp/build-XXXXX)
DESTINATION="$ROOT_PATH/build"
STAGING="$DESTINATION/staging"

# Flags for debugging
DOCS=true
PACKAGE=true
FRAMEWORK=true

# Clean up output directory
rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"
mkdir -p "$STAGING"

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
    -archivePath "$TEMP_DIR/xcarchive/$project/$scheme/mac.xcarchive" \
    -derivedDataPath "$TEMP_DIR/derivedData/$project" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
  else
    xcrun xcodebuild archive -quiet \
    -project "$ROOT_PATH/$project/$project.xcodeproj" \
    -scheme "$scheme" \
    -sdk "$sdk" \
    -destination="$destination" \
    -archivePath "$TEMP_DIR/xcarchive/$project/$scheme/$sdk.xcarchive" \
    -derivedDataPath "$TEMP_DIR/derivedData/$project" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

    xcrun xcodebuild archive -quiet \
    -project "$ROOT_PATH/$project/$project.xcodeproj" \
    -scheme "$scheme" \
    -sdk "$simulatorSdk" \
    -destination="$simulatorDestination" \
    -archivePath "$TEMP_DIR/xcarchive/$project/$scheme/$simulatorSdk.xcarchive" \
    -derivedDataPath "$TEMP_DIR/derivedData/$project" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
  fi
}

if $FRAMEWORK
then
  echo -ne "\n\n *********** BUILDING XCFRAMEWORKS *********** \n\n"

  bash $ROOT_PATH/scripts/install_pods.sh

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
  build_archive "Airship" "AirshipExtendedActions" "iOS"
  build_archive "Airship" "AirshipExtendedActions" "maccatalyst"
  build_archive "AirshipExtensions" "AirshipNotificationServiceExtension" "iOS"
  build_archive "AirshipExtensions" "AirshipNotificationServiceExtension" "maccatalyst"
  build_archive "AirshipExtensions" "AirshipNotificationContentExtension" "iOS"
  build_archive "AirshipExtensions" "AirshipNotificationContentExtension" "maccatalyst"
  build_archive "Airship" "Airship" "iOS"
  build_archive "Airship" "Airship" "maccatalyst"
  build_archive "Airship" "Airship tvOS" "tvOS"

  # Package Airship
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/Airship/Airship/iphoneos.xcarchive/Products/Library/Frameworks/Airship.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/Airship/iphonesimulator.xcarchive/Products/Library/Frameworks/Airship.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/Airship/mac.xcarchive/Products/Library/Frameworks/Airship.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/Airship tvOS/appletvos.xcarchive/Products/Library/Frameworks/Airship.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/Airship tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/Airship.framework" \
  -output "$STAGING/Airship.xcframework"

  # Package AirshipCore
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipCore/iphoneos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipCore/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipCore/mac.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipCore tvOS/appletvos.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipCore tvOS/appletvsimulator.xcarchive/Products/Library/Frameworks/AirshipCore.framework" \
  -output "$STAGING/AirshipCore.xcframework"

  # Package AirshipLocation
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipLocation/iphoneos.xcarchive/Products/Library/Frameworks/AirshipLocation.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipLocation/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipLocation.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipLocation/mac.xcarchive/Products/Library/Frameworks/AirshipLocation.framework" \
  -output "$STAGING/AirshipLocation.xcframework"

  # Package AirshipMessageCenter
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipMessageCenter/iphoneos.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipMessageCenter/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipMessageCenter/mac.xcarchive/Products/Library/Frameworks/AirshipMessageCenter.framework" \
  -output "$STAGING/AirshipMessageCenter.xcframework"

  # Package AirshipExtendedActions
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipExtendedActions/iphoneos.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipExtendedActions/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipExtendedActions/mac.xcarchive/Products/Library/Frameworks/AirshipExtendedActions.framework" \
  -output "$STAGING/AirshipExtendedActions.xcframework"

  # Package AirshipAccengage
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipAccengage/iphoneos.xcarchive/Products/Library/Frameworks/AirshipAccengage.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipAccengage/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipAccengage.framework" \
  -framework "$TEMP_DIR/xcarchive/Airship/AirshipAccengage/mac.xcarchive/Products/Library/Frameworks/AirshipAccengage.framework" \
  -output "$STAGING/AirshipAccengage.xcframework"

  # Package AirshipNotificationServiceExtension
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/AirshipExtensions/AirshipNotificationServiceExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -framework "$TEMP_DIR/xcarchive/AirshipExtensions/AirshipNotificationServiceExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -framework "$TEMP_DIR/xcarchive/AirshipExtensions/AirshipNotificationServiceExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationServiceExtension.framework" \
  -output "$STAGING/AirshipNotificationServiceExtension.xcframework"

  # Package AirshipNotificationContentExtension
  xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/xcarchive/AirshipExtensions/AirshipNotificationContentExtension/iphoneos.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
  -framework "$TEMP_DIR/xcarchive/AirshipExtensions/AirshipNotificationContentExtension/iphonesimulator.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
  -framework "$TEMP_DIR/xcarchive/AirshipExtensions/AirshipNotificationContentExtension/mac.xcarchive/Products/Library/Frameworks/AirshipNotificationContentExtension.framework" \
  -output "$STAGING/AirshipNotificationContentExtension.xcframework"

fi

############
# Build docs
############

function build_docs {
  # $1 Project
  # $2 Module
  # $3 Umbrella header path

   bundle exec jazzy \
  --objc \
  --clean \
  --module $2  \
  --module-version $AIRSHIP_VERSION \
  --framework-root "$ROOT_PATH/$1" \
  --umbrella-header "$ROOT_PATH/$1/$2/$3" \
  --output "$STAGING/Documentation/$2" \
  --sdk iphonesimulator \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config Documentation/.jazzy.json
}

if $DOCS
then
  echo -ne "\n\n *********** BUILDING DOCS *********** \n\n"
  build_docs "Airship" "Airship" "Source/Airship.h"
  build_docs "Airship" "AirshipCore" "Source/common/AirshipCore.h"
  build_docs "Airship" "AirshipLocation"  "Source/AirshipLocation.h"
  build_docs "Airship" "AirshipAutomation"  "Source/AirshipAutomation.h"
  build_docs "Airship" "AirshipMessageCenter"  "Source/AirshipMessageCenter.h"
  build_docs "Airship" "AirshipExtendedActions"  "Source/AirshipExtendedActions.h"
  build_docs "Airship" "AirshipAccengage"  "Source/AirshipAccengage.h"
  build_docs "AirshipExtensions" "AirshipNotificationServiceExtension" "Source/AirshipNotificationServiceExtension.h"
  build_docs "AirshipExtensions" "AirshipNotificationContentExtension" "Source/AirshipNotificationContentExtension.h"
fi

######################
# Package distribution
######################

if $PACKAGE
then
  echo -ne "\n\n *********** PACKAGING RELEASE *********** \n\n"
  mkdir -p "$STAGING"

  # Copy LICENSE, README and CHANGELOG
  cp "$ROOT_PATH/CHANGELOG.md" "$STAGING"
  cp "$ROOT_PATH/README.md" "$STAGING"
  cp "$ROOT_PATH/LICENSE" "$STAGING"

  # Build info
  BUILD_INFO=$STAGING/BUILD_INFO
  echo "Airship SDK v${AIRSHIP_VERSION}" >> $BUILD_INFO
  echo "Build time: `date`" >> $BUILD_INFO
  echo "SDK commit: `git log -n 1 --format='%h'`" >> $BUILD_INFO
  echo "Xcode version: $(xcrun xcodebuild -version | tr '\r\n' ' ')" >> $BUILD_INFO

  # Additional build info
  if test -f "$ROOT_PATH/BUILD_INFO";
  then
    cat "$ROOT_PATH/BUILD_INFO" >> $BUILD_INFO
  fi

  # Generate the ZIP
  cd $STAGING
  zip -r -X Airship.zip .
  cd -

  # Move zip
  mv "$STAGING/Airship.zip" "$DESTINATION"

  cd "$STAGING/Documentation"
  tar -czf ../../Documentation.tar.gz *
  cd -
fi
