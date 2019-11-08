#!/bin/bash

set -o pipefail
set -e
set -x

JAZZY_VERSION=0.10.0
SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/..
TEMP_DIR=$(mktemp -d /tmp/build-XXXXX)
DESTINATION=$ROOT_PATH/build
STAGING=$DESTINATION/staging
CORE_DESTINATION=$STAGING/core
LOCATION_DESTINATION=$STAGING/location
EXTENSIONS_DESTINATION=$STAGING/extensions

VERSION=$(awk <$ROOT_PATH/AirshipKit/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

DOCS=false
PACKAGE=false
FRAMEWORK=false
XC_FRAMEWORK=false

# Parameters must be added this OPTS string
OPTS=`getopt hadlpfx $*`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

while true; do
  case "$1" in
    -h  ) echo -ne " -a for all \n -d for docs \n -f for framework \n -x for xcframework \n -p to package the release. This option includes all. \n"; exit 0;;
    -a  ) DOCS=true;PACKAGE=true;FRAMEWORK=true;XC_FRAMEWORK=true;;
    -d  ) DOCS=true;;
    -f  ) FRAMEWORK=true;;
    -x  ) XC_FRAMEWORK=true;;
    -p  ) DOCS=true;PACKAGE=true;FRAMEWORK=true;XC_FRAMEWORK=true;;
    --  ) ;;
    *   ) break ;;
  esac
  shift
done

echo -ne "Build with options - docs:${DOCS} package:${PACKAGE} framework:${FRAMEWORK}\n\n"

# Clean up output directory
rm -rf $DESTINATION
mkdir -p $DESTINATION
mkdir -p $STAGING

##################
# Build frameworks
##################

if [ $FRAMEWORK = true ]
then
  echo -ne "\n\n *********** BUILDING AIRSHIPKIT *********** \n\n"

  # iphoneOS
  xcrun xcodebuild -quiet -configuration "Release" \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -target "AirshipKit" \
  -sdk "iphoneos" \
  BUILD_DIR="${TEMP_DIR}/AirshipKit" \
  SYMROOT="${TEMP_DIR}/AirshipKit" \
  OBJROOT="${TEMP_DIR}/AirshipKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipKit"
  # tvOS
  xcrun xcodebuild -quiet -configuration "Release" \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -target "AirshipKit tvOS" \
  -sdk "appletvos" \
  BUILD_DIR="${TEMP_DIR}/AirshipKit" \
  SYMROOT="${TEMP_DIR}/AirshipKit" \
  OBJROOT="${TEMP_DIR}/AirshipKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipKit"

  # Verify the iOS resource bundle does not contain an executable
  IOS_BUNDLE_EXECUTABLE="${TEMP_DIR}/AirshipKit/Release-iphoneos/AirshipResources.bundle/AirshipResources"
  if [ -f $IOS_BUNDLE_EXECUTABLE ]; then
    echo "Error: iOS AirshipResources.bundle executable exists."
    exit 1
  fi

  # Verify the tvOS resource bundle does not contain an executable
  TV_BUNDLE_EXECUTABLE="${TEMP_DIR}/AirshipKit/Release-appletvos/AirshipResources tvOS.bundle/AirshipResources"
  if [ -f "${TV_BUNDLE_EXECUTABLE}" ]; then
    echo "Error: tvOS AirshipResources.bundle executable exists."
    exit 1
  fi

  echo -ne "\n\n *********** BUILDING AIRSHIPLOCATIONKIT *********** \n\n"

  # iphoneOS
  xcrun xcodebuild -quiet -configuration "Release" \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -target "AirshipLocationKit" \
  -sdk "iphoneos" \
  BUILD_DIR="${TEMP_DIR}/AirshipLocationKit" \
  SYMROOT="${TEMP_DIR}/AirshipLocationKit" \
  OBJROOT="${TEMP_DIR}/AirshipLocationKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLocationKit"
  # tvOS
  xcrun xcodebuild -quiet -configuration "Release" \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -target "AirshipLocationKit tvOS" \
  -sdk "appletvos" \
  BUILD_DIR="${TEMP_DIR}/AirshipLocationKit" \
  SYMROOT="${TEMP_DIR}/AirshipLocationKit" \
  OBJROOT="${TEMP_DIR}/AirshipLocationKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLocationKit"
fi

####################
# Build XC Framework
####################

if [ $XC_FRAMEWORK = true ]
then
  echo -ne "\n\n *********** BUILDING XCFRAMEWORK ARCHIVES *********** \n\n"

  # iphoneOS
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -scheme AirshipKit \
  -destination="iOS" \
  -archivePath "${TEMP_DIR}/ios.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/iphoneos" \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # iphoneOS simulator
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -scheme AirshipKit \
  -destination="iOS Simulator" \
  -archivePath "${TEMP_DIR}/iossimulator.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/iphoneos" \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # iphoneOS location
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -scheme AirshipLocationKit \
  -destination="iOS" \
  -archivePath "${TEMP_DIR}/ioslocation.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/iphoneos" \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # iphoneOS simulator location
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -scheme AirshipLocationKit \
  -destination="iOS Simulator" \
  -archivePath "${TEMP_DIR}/iossimulatorlocation.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/iphoneos" \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # iphoneOS extensions
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipAppExtensions/AirshipAppExtensions.xcodeproj" \
  -scheme AirshipAppExtensions \
  -destination="iOS" \
  -archivePath "${TEMP_DIR}/iosextensions.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/iphoneos" \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # iphoneOS simulator extensions
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipAppExtensions/AirshipAppExtensions.xcodeproj" \
  -scheme AirshipAppExtensions \
  -destination="iOS Simulator" \
  -archivePath "${TEMP_DIR}/iossimulatorextensions.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/iphoneos" \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # tvOS
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -scheme "AirshipKit tvOS" \
  -destination="tvOS" \
  -archivePath "${TEMP_DIR}/tvos.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/appletvos" \
  -sdk appletvos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # tvOS Simulator
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -scheme "AirshipKit tvOS" \
  -destination="tvOS Simulator" \
  -archivePath "${TEMP_DIR}/tvossimulator.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/appletvos" \
  -sdk appletvsimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # tvOS location
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -scheme "AirshipLocationKit tvOS" \
  -destination="tvOS" \
  -archivePath "${TEMP_DIR}/appletvoslocation.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/appletvos" \
  -sdk appletvos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

  # tvOS simulator location
  xcrun xcodebuild archive -quiet \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -scheme "AirshipLocationKit tvOS" \
  -destination="tvOS Simulator" \
  -archivePath "${TEMP_DIR}/appletvsimulatorlocation.xcarchive" \
  -derivedDataPath "${TEMP_DIR}/appletvos" \
  -sdk appletvsimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

#  # macOS
#  xcrun xcodebuild archive \
#  -scheme AirshipKit macOS \
#  -destination="macOS" \
#  -archivePath "${TEMP_DIR}/macos.xcarchive" \
#  -derivedDataPath "${TEMP_DIR}/macos" \
#  -sdk macosx \
#  SKIP_INSTALL=NO \
#  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

#  # watchOS
#  xcrun xcodebuild archive \
#  -scheme AirshipKit watchOS \
#  -destination="watchOS" \
#  -archivePath "${TEMP_DIR}/watchos.xcarchive" \
#  -derivedDataPath "${TEMP_DIR}/watchos" \
#  -sdk watchos \
#  SKIP_INSTALL=NO \
#  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

#  # watchOS Simulator
#  xcrun xcodebuild archive \
#  -scheme AirshipKit watchOS \
#  -destination="watchOS" \
#  -archivePath "${TEMP_DIR}/watchossimulator.xcarchive" \
#  -derivedDataPath "${TEMP_DIR}/watchos" \
#  -sdk watchsimulator \
#  SKIP_INSTALL=NO \
#  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \

echo -ne "\n\n *********** BUILDING XCFRAMEWORK *********** \n\n"

  # Wrap up into XCFramework
  xcodebuild -create-xcframework \
  -framework "${TEMP_DIR}/ios.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \
  -framework "${TEMP_DIR}/iossimulator.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \
  -framework "${TEMP_DIR}/tvos.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \
  -framework "${TEMP_DIR}/tvossimulator.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \
  -output "${TEMP_DIR}/AirshipKit.xcframework" \

  # To add when macOS and watchOS compatibility is added
  #-framework "${TEMP_DIR}/macos.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \
  #-framework "${TEMP_DIR}/watchos.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \
  #-framework "${TEMP_DIR}/watchsimulator.xcarchive/Products/Library/Frameworks/AirshipKit.framework" \

  # Wrap up Location XCFramework
  xcodebuild -create-xcframework \
  -framework "${TEMP_DIR}/ioslocation.xcarchive/Products/Library/Frameworks/AirshipLocationKit.framework" \
  -framework "${TEMP_DIR}/iossimulatorlocation.xcarchive/Products/Library/Frameworks/AirshipLocationKit.framework" \
  -framework "${TEMP_DIR}/appletvoslocation.xcarchive/Products/Library/Frameworks/AirshipLocationKit.framework" \
  -framework "${TEMP_DIR}/appletvsimulatorlocation.xcarchive/Products/Library/Frameworks/AirshipLocationKit.framework" \
  -output "${TEMP_DIR}/AirshipKitLocation.xcframework" \

  # Wrap up Extensions XCFramework
  xcodebuild -create-xcframework \
  -framework "${TEMP_DIR}/iosextensions.xcarchive/Products/Library/Frameworks/AirshipAppExtensions.framework" \
  -framework "${TEMP_DIR}/iossimulatorextensions.xcarchive/Products/Library/Frameworks/AirshipAppExtensions.framework" \
  -output "${TEMP_DIR}/AirshipAppExtensions.xcframework" \

fi

######################
# Package distribution
######################

if [ $PACKAGE = true ]
then
  echo -ne "\n\n *********** PACKAGING RELEASE *********** \n\n"

  # Stage AirshipKit
  echo "Staging AirshipKit"
  cp -R "${ROOT_PATH}/AirshipKit" "${STAGING}"

  # Stage AirshipLocationKit
  echo "Staging AirshipLocationKit"
  cp -R "${ROOT_PATH}/AirshipLocationKit" "${STAGING}"

  # Stage AirshipAppExtensions
  echo "Staging AirshipAppExtensions"
  cp -R "${ROOT_PATH}/AirshipAppExtensions" "${STAGING}"

  # Stage Sample
  echo "Staging Sample"
  cp -R "${ROOT_PATH}/Sample" "${STAGING}"

  # Stage SwiftSample
  echo "Staging SwiftSample"
  cp -R "${ROOT_PATH}/SwiftSample" "${STAGING}"

  # Stage Core XCFramework
  echo "Staging Core XCFramework"
  mkdir -p "${CORE_DESTINATION}/AirshipKit.xcframework"
  cp -a "${TEMP_DIR}/AirshipKit.xcframework/." "${CORE_DESTINATION}/AirshipKit.xcframework/"

  # Stage Location XCFramework
  echo "Staging Location XCFramework"
  mkdir -p "${LOCATION_DESTINATION}/AirshipKitLocation.xcframework"
  cp -a "${TEMP_DIR}/AirshipKitLocation.xcframework/." "${LOCATION_DESTINATION}/AirshipKitLocation.xcframework/"

  # Stage Extensions XCFramework
  echo "Staging Extensions XCFramework"
  mkdir -p "${EXTENSIONS_DESTINATION}/AirshipAppExtensions.xcframework"
  cp -a "${TEMP_DIR}/AirshipAppExtensions.xcframework/." "${EXTENSIONS_DESTINATION}/AirshipAppExtensions.xcframework/"

  # Copy LICENSE, README and CHANGELOG
  cp "${ROOT_PATH}/CHANGELOG.md" "${STAGING}"
  cp "${ROOT_PATH}/README.md" "${STAGING}"
  cp "${ROOT_PATH}/LICENSE" "${STAGING}"

  # Build info
  BUILD_INFO=$STAGING/BUILD_INFO
  echo "Airship SDK v${VERSION}" >> $BUILD_INFO
  echo "Build time: `date`" >> $BUILD_INFO
  echo "SDK commit: `git log -n 1 --format='%h'`" >> $BUILD_INFO
  echo "Xcode version: `xcrun xcodebuild -version | tr '\r\n' ' '`" >> $BUILD_INFO

  # Additional build info
  if test -f $ROOT_PATH/BUILD_INFO;
  then cat $ROOT_PATH/BUILD_INFO >> $BUILD_INFO;
  fi

  # Clean up any unwanted files
  rm -rf `find ${STAGING} -name "*.orig" `
  rm -rf `find ${STAGING} -name "*KIF-Info.plist" `
  rm -rf `find ${STAGING} -name "*.mode1v3" `
  rm -rf `find ${STAGING} -name "*.pbxuser" `
  rm -rf `find ${STAGING} -name "*.perspective*" `
  rm -rf `find ${STAGING} -name "xcuserdata" `
  rm -rf `find ${STAGING} -name "AirshipConfig.plist" `

  # Rename sample plists
  mv -f ${STAGING}/Sample/AirshipConfig.plist.sample ${STAGING}/Sample/AirshipConfig.plist
  mv -f ${STAGING}/SwiftSample/AirshipConfig.plist.sample ${STAGING}/SwiftSample/AirshipConfig.plist

  # Generate the ZIP
  cd $STAGING
  zip -r -X libUAirship-$VERSION.zip .
  cd -

  # Move zip
  mv $STAGING/libUAirship-$VERSION.zip $DESTINATION
fi

############
# Build docs
############

if [ $DOCS = true ]
then
  echo -ne "\n\n *********** BUILDING DOCS *********** \n\n"

  # Make sure Jazzy is installed
  if [ `gem list -i jazzy --version ${JAZZY_VERSION}` == 'false' ]; then
  echo "Installing jazzy"
  gem install jazzy -v $JAZZY_VERSION
  fi

  ruby -S jazzy _${JAZZY_VERSION}_ -v

  # AirshipKit
  ruby -S jazzy _${JAZZY_VERSION}_ \
  --objc \
  --clean \
  --module AirshipKit  \
  --module-version $VERSION \
  --framework-root $ROOT_PATH/AirshipKit \
  --umbrella-header $ROOT_PATH/AirshipKit/AirshipKit/ios/AirshipLib.h \
  --output $STAGING/Documentation/AirshipKit \
  --sdk iphonesimulator \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config Documentation/.jazzy.json

  # AirshipLocationKit
  ruby -S jazzy _${JAZZY_VERSION}_ \
  --objc \
  --clean \
  --module AirshipLocationKit  \
  --module-version $VERSION \
  --framework-root $ROOT_PATH/AirshipLocationKit \
  --umbrella-header $ROOT_PATH/AirshipLocationKit/AirshipLocationKit/AirshipLocationLib.h \
  --output $STAGING/Documentation/AirshipLocationKit \
  --sdk iphonesimulator \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config Documentation/.jazzy.json

  # AirshipAppExtensions
  ruby -S jazzy _${JAZZY_VERSION}_ \
  --objc \
  --clean \
  --module-version $VERSION \
  --umbrella-header $ROOT_PATH/AirshipAppExtensions/AirshipAppExtensions/AirshipAppExtensions.h \
  --framework-root $ROOT_PATH/AirshipAppExtensions \
  --module AirshipAppExtensions  \
  --output $STAGING/Documentation/AirshipAppExtensions \
  --sdk iphonesimulator \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config Documentation/.jazzy.json

  # Workaround the missing module version
  find $STAGING/Documentation -name '*.html' -print0 | xargs -0 sed -i "" "s/\$AIRSHIP_VERSION/${VERSION}/g"
fi
