#!/bin/bash -ex

JAZZY_VERSION=0.7.5
SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/..
TEMP_DIR=$(mktemp -d /tmp/build-XXXXX)
DESTINATION=$ROOT_PATH/build
STAGING=$DESTINATION/staging

VERSION=$(awk <$ROOT_PATH/AirshipKit/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

# Clean up output directory
rm -rf $DESTINATION
mkdir -p $DESTINATION
mkdir -p $STAGING

########################
# Build resource bundles
########################

xcrun xcodebuild -configuration "Release" \
-project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
-target "AirshipResources" \
-sdk "iphoneos" \
clean build \
ONLY_ACTIVE_ARCH=NO \
BUILD_DIR="${TEMP_DIR}/AirshipResources" \
SYMROOT="${TEMP_DIR}/AirshipResources" \
OBJROOT="${TEMP_DIR}/AirshipResources/obj" \
BUILD_ROOT="${TEMP_DIR}/AirshipResources" \
TARGET_BUILD_DIR="${TEMP_DIR}/AirshipResources/Release-iphoneos"

xcrun xcodebuild -configuration "Release" \
-project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
-target "AirshipResources tvOS" \
-sdk "appletvos" \
clean build \
ONLY_ACTIVE_ARCH=NO \
BUILD_DIR="${TEMP_DIR}/AirshipResources tvOS" \
SYMROOT="${TEMP_DIR}/AirshipResources tvOS" \
OBJROOT="${TEMP_DIR}/AirshipResources tvOS/obj" \
BUILD_ROOT="${TEMP_DIR}/AirshipResources tvOS" \
TARGET_BUILD_DIR="${TEMP_DIR}/AirshipResources tvOS/Release-appletvos"

##################
# Build frameworks
##################

# iphoneOS
xcrun xcodebuild -configuration "Release" \
-project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
-target "AirshipKit" \
-sdk "iphoneos" \

## tvOS
xcrun xcodebuild -configuration "Release" \
-project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
-target "AirshipKit tvOS" \
-sdk "appletvos" \

######################
# Build static library
######################

# iphoneOS
xcrun xcodebuild -configuration "Release" \
-project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" \
-target "AirshipLib" \
-sdk "iphoneos" \
clean build \
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
clean build \
ONLY_ACTIVE_ARCH=NO \
RUN_CLANG_STATIC_ANALYZER=NO \
BUILD_DIR="${TEMP_DIR}/AirshipLib" \
SYMROOT="${TEMP_DIR}/AirshipLib" \
OBJROOT="${TEMP_DIR}/AirshipLib/obj" \
BUILD_ROOT="${TEMP_DIR}/AirshipLib" \
TARGET_BUILD_DIR="${TEMP_DIR}/AirshipLib/iphonesimulator"

# Create a universal static library the two static libraries
xcrun -sdk iphoneos lipo -create -output "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" "${TEMP_DIR}/AirshipLib/iphoneos/libUAirship.a" "${TEMP_DIR}/AirshipLib/iphonesimulator/libUAirship.a"

# Verify architectures in the fat binary
xcrun -sdk iphoneos lipo "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" -verify_arch armv7 armv7s i386 x86_64 arm64

# Verify bitcode is enabled in the fat binary
otool -l "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" | grep __LLVM

############
# Build docs
############

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

######################
# Package distribution
######################

# Stage AirshipKit
echo "Staging AirshipKit"
cp -R "${ROOT_PATH}/AirshipKit" "${STAGING}"

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
find ${ROOT_PATH}/AirshipKit/AirshipKit -type f -name '*.h' ! -name 'AirshipKit.h' ! -name '*+Internal*.h'  -exec cp {} ${STAGING}/Airship/Headers \;
cp "${TEMP_DIR}/AirshipLib/libUAirship-${VERSION}.a" "${STAGING}/Airship"
cp -R "${TEMP_DIR}/AirshipResources/Release-iphoneos/AirshipResources.bundle" "${STAGING}/Airship"

# Copy LICENSE, README and CHANGELOG
cp "${ROOT_PATH}/CHANGELOG" "${STAGING}"
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
