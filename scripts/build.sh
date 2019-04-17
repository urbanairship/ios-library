#!/bin/bash

set -o pipefail
set -e
set -x

JAZZY_VERSION=0.7.5
SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/..
TEMP_DIR=$(mktemp -d /tmp/build-XXXXX)
DESTINATION=$ROOT_PATH/build
STAGING=$DESTINATION/staging

VERSION=$(awk <$ROOT_PATH/AirshipKit/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

DOCS=false
STATIC_LIB=false
PACKAGE=false
FRAMEWORK=false

OPTS=`getopt hadlpf $*`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

while true; do
  case "$1" in
    -h  ) echo -ne " -a for all \n-d for docs \n -l for static lib \n -p to package the release. This option includes all. \n"; exit 0;;
    -a  ) DOCS=true;STATIC_LIB=true;PACKAGE=true;FRAMEWORK=true;;
    -d  ) DOCS=true;;
    -l  ) STATIC_LIB=true;;
    -f  ) FRAMEWORK=true;;
    -p  ) DOCS=true;STATIC_LIB=true;PACKAGE=true;FRAMEWORK=true;;
    --  ) ;;
    *   ) break ;;
  esac
  shift
done

echo -ne "Build with options - docs:${DOCS} static-lib:${STATIC_LIB} package:${PACKAGE} framework:${FRAMEWORK}\n\n"

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
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -target "AirshipKit" \
  -sdk "iphoneos" \
  BUILD_DIR="${TEMP_DIR}/AirshipKit" \
  SYMROOT="${TEMP_DIR}/AirshipKit" \
  OBJROOT="${TEMP_DIR}/AirshipKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipKit"
  # tvOS
  xcrun xcodebuild -configuration "Release" \
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
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -target "AirshipLocationKit" \
  -sdk "iphoneos" \
  BUILD_DIR="${TEMP_DIR}/AirshipLocationKit" \
  SYMROOT="${TEMP_DIR}/AirshipLocationKit" \
  OBJROOT="${TEMP_DIR}/AirshipLocationKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLocationKit"
  # tvOS
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -target "AirshipLocationKit tvOS" \
  -sdk "appletvos" \
  BUILD_DIR="${TEMP_DIR}/AirshipLocationKit" \
  SYMROOT="${TEMP_DIR}/AirshipLocationKit" \
  OBJROOT="${TEMP_DIR}/AirshipLocationKit/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLocationKit"
fi

######################
# Build static library
######################

if [ $STATIC_LIB = true ]
then
  echo -ne "\n\n *********** BUILDING LIBUAIRSHIP *********** \n\n"

  # REVISIT - Xcode 10 betas have a bug where "clean" fails when not using DERIVED-DATA
  # The 3 static library builds should probably have "clean" added back once bug is fixed.

  # Resource bundle
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -target "AirshipResources" \
  -sdk "iphoneos" \
  build \
  ONLY_ACTIVE_ARCH=NO \
  BUILD_DIR="${TEMP_DIR}/AirshipResources" \
  SYMROOT="${TEMP_DIR}/AirshipResources" \
  OBJROOT="${TEMP_DIR}/AirshipResources/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipResources" \
  TARGET_BUILD_DIR="${TEMP_DIR}/AirshipResources/Release-iphoneos"

  # iphoneOS
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -target "AirshipLib" \
  -sdk "iphoneos" \
  build \
  ONLY_ACTIVE_ARCH=NO \
  RUN_CLANG_STATIC_ANALYZER=NO \
  BUILD_DIR="${TEMP_DIR}/AirshipLib" \
  SYMROOT="${TEMP_DIR}/AirshipLib" \
  OBJROOT="${TEMP_DIR}/AirshipLib/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLib" \
  TARGET_BUILD_DIR="${TEMP_DIR}/AirshipLib/iphoneos"

  # iphonesimulator
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
  -target "AirshipLib" \
  -sdk "iphonesimulator" \
  -arch i386 -arch x86_64 \
  build \
  ONLY_ACTIVE_ARCH=NO \
  RUN_CLANG_STATIC_ANALYZER=NO \
  BUILD_DIR="${TEMP_DIR}/AirshipLib" \
  SYMROOT="${TEMP_DIR}/AirshipLib" \
  OBJROOT="${TEMP_DIR}/AirshipLib/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLib" \
  TARGET_BUILD_DIR="${TEMP_DIR}/AirshipLib/iphonesimulator"

  # Verify the iOS resource bundle does not contain an executable
  IOS_BUNDLE_EXECUTABLE="${TEMP_DIR}/AirshipResources/Release-iphoneos/AirshipResources.bundle/AirshipResources"
  if [ -f $IOS_BUNDLE_EXECUTABLE ]; then
    echo "Error: iOS AirshipResources.bundle executable exists."
    exit 1
  fi

  # Create a universal static library the two static libraries
  xcrun -sdk iphoneos lipo -create -output "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" "${TEMP_DIR}/AirshipLib/iphoneos/libUAirship.a" "${TEMP_DIR}/AirshipLib/iphonesimulator/libUAirship.a"

  # Verify architectures in the fat binary
  echo "☠️ ⛑ If the build fails at this step, it means one of the architectures is missing. 👉 Run 'xcrun -sdk iphoneos lipo \"${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a\" -detailed_info' for more info. 👈 ⛑ ☠️"
  xcrun -sdk iphoneos lipo "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" -verify_arch armv7 i386 x86_64 arm64

  # Verify bitcode is enabled in the fat binary
  otool -l "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" | grep __LLVM

  echo -ne "\n\n *********** BUILDING LIBUALocation *********** \n\n"

  # iphoneOS
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -target "AirshipLocationLib" \
  -sdk "iphoneos" \
  build \
  ONLY_ACTIVE_ARCH=NO \
  RUN_CLANG_STATIC_ANALYZER=NO \
  BUILD_DIR="${TEMP_DIR}/AirshipLocationLib" \
  SYMROOT="${TEMP_DIR}/AirshipLocationLib" \
  OBJROOT="${TEMP_DIR}/AirshipLocationLib/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLocationLib" \
  TARGET_BUILD_DIR="${TEMP_DIR}/AirshipLocationLib/iphoneos"

  # iphonesimulator
  xcrun xcodebuild -configuration "Release" \
  -project "${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit.xcodeproj" \
  -target "AirshipLocationLib" \
  -sdk "iphonesimulator" \
  -arch i386 -arch x86_64 \
  build \
  ONLY_ACTIVE_ARCH=NO \
  RUN_CLANG_STATIC_ANALYZER=NO \
  BUILD_DIR="${TEMP_DIR}/AirshipLocationLib" \
  SYMROOT="${TEMP_DIR}/AirshipLocationLib" \
  OBJROOT="${TEMP_DIR}/AirshipLocationLib/obj" \
  BUILD_ROOT="${TEMP_DIR}/AirshipLocationLib" \
  TARGET_BUILD_DIR="${TEMP_DIR}/AirshipLocationLib/iphonesimulator"

  # Create a universal static library the two static libraries
  xcrun -sdk iphoneos lipo -create -output "${TEMP_DIR}/AirshipLocationLib/libUALocation-${VERSION}.a" "${TEMP_DIR}/AirshipLocationLib/iphoneos/libUALocation.a" "${TEMP_DIR}/AirshipLocationLib/iphonesimulator/libUALocation.a"

  # Verify architectures in the fat binary
  echo "☠️ ⛑ If the build fails at this step, it means one of the architectures is missing. 👉 Run 'xcrun -sdk iphoneos lipo \"${TEMP_DIR}/AirshipLocationLib/libUALocation-${VERSION}.a\" -detailed_info' for more info. 👈 ⛑ ☠️"
  xcrun -sdk iphoneos lipo "${TEMP_DIR}/AirshipLocationLib/libUALocation-${VERSION}.a" -verify_arch i386 x86_64 arm64

  # Verify bitcode is enabled in the fat binary
  otool -l "${TEMP_DIR}/AirshipLocationLib/libUALocation-${VERSION}.a" | grep __LLVM
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

    # AirshipKit
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

  # Copy images for documents
  cp -r Documentation/Migration/images $STAGING/Documentation/AirshipKit
  cp -r Documentation/Migration/images $STAGING/Documentation/AirshipAppExtensions
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

  # Stage Static Library
  
  echo "Staging Airship"
  mkdir -p ${STAGING}/Airship/Headers
  find ${ROOT_PATH}/AirshipKit/AirshipKit/common -type f -name '*.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h'  -exec cp {} ${STAGING}/Airship/Headers \;
  find ${ROOT_PATH}/AirshipKit/AirshipKit/ios -type f -name '*.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h'  -exec cp {} ${STAGING}/Airship/Headers \;
  find ${ROOT_PATH}/AirshipLocationKit/AirshipLocationKit -type f -name '*.h' ! -name 'AirshipLocationKit.h' ! -name '*+Internal*.h'  -exec cp {} ${STAGING}/Airship/Headers \;
  cp "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" "${STAGING}/Airship"
  cp "${TEMP_DIR}/AirshipLib/libUALocation-${VERSION}.a" "${STAGING}/Airship"
  cp -R "${TEMP_DIR}/AirshipResources/Release-iphoneos/AirshipResources.bundle" "${STAGING}/Airship"

  # Copy LICENSE, README and CHANGELOG
  cp "${ROOT_PATH}/CHANGELOG.md" "${STAGING}"
  cp "${ROOT_PATH}/README.md" "${STAGING}"
  cp "${ROOT_PATH}/LICENSE" "${STAGING}"

  # Build info
  BUILD_INFO=$STAGING/BUILD_INFO
  echo "Urban Airship SDK v${VERSION}" >> $BUILD_INFO
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
