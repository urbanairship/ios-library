# Version 2.0 (updated for Xcode 4, with some fixes)

# Author: Adam Martin - http://twitter.com/redglassesapps
# Based on: original script from Eonil (main changes: Eonil's script WILL NOT WORK in Xcode GUI - it WILL CRASH YOUR COMPUTER)
#
# More info: see this Stack Overflow question: http://stackoverflow.com/questions/3520977/build-fat-static-library-device-simulator-using-xcode-and-sdk-4

#################[ Tests: helps workaround any future bugs in Xcode ]########
#
DEBUG_THIS_SCRIPT="false"

if [ $DEBUG_THIS_SCRIPT = "true" ]
then
echo "########### TESTS #############"
echo "Use the following variables when debugging this script; note that they may change on recursions"
echo "BUILD_DIR = $BUILD_DIR"
echo "BUILD_ROOT = $BUILD_ROOT"
echo "CONFIGURATION_BUILD_DIR = $CONFIGURATION_BUILD_DIR"
echo "BUILT_PRODUCTS_DIR = $BUILT_PRODUCTS_DIR"
echo "CONFIGURATION_TEMP_DIR = $CONFIGURATION_TEMP_DIR"
echo "TARGET_BUILD_DIR = $TARGET_BUILD_DIR"
fi

#####################[ part 1 ]##################
# First, work out the BASESDK version number
#    (incidental: searching for substrings in sh is a nightmare! Sob)

SDK_VERSION=$(echo ${SDK_NAME} | grep -o '.\{3\}$')

# Next, work out if we're in SIM or DEVICE

if [ ${PLATFORM_NAME} = "iphonesimulator" ]
then
OTHER_SDK_TO_BUILD=iphoneos${SDK_VERSION}
else
OTHER_SDK_TO_BUILD=iphonesimulator${SDK_VERSION}
fi

echo "XCode has selected SDK: ${PLATFORM_NAME} with version: ${SDK_VERSION} (although back-targetting: ${IPHONEOS_DEPLOYMENT_TARGET})"
echo "...therefore, OTHER_SDK_TO_BUILD = ${OTHER_SDK_TO_BUILD}"
#
#####################[ end of part 1 ]##################

#####################[ part 2 ]##################
#
# IF this is the original invocation, invoke whatever other builds are required
#
# Xcode is already building ONE target... build ONLY the missing platforms/configurations.

if [ "true" == ${ALREADYINVOKED:-false} ]
then
echo "RECURSION: Not the root invocation, don't recurse"
else
# Prevent recursion
export ALREADYINVOKED="true"

echo "RECURSION: I am the root... recursing all missing build targets..."
echo "RECURSION: ...about to invoke: xcodebuild -configuration \"${CONFIGURATION}\" -target \"${TARGET_NAME}\" -sdk \"${OTHER_SDK_TO_BUILD}\" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO"
xcodebuild -configuration "${CONFIGURATION}" -target "${TARGET_NAME}" -sdk "${OTHER_SDK_TO_BUILD}" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" > "${BUILD_ROOT}.build_output"

ACTION="build"

# Merge all platform binaries as a fat binary for each configurations.

# Calculate where the (multiple) built files are coming from:
CURRENTCONFIG_DEVICE_DIR=${SYMROOT}/${CONFIGURATION}-iphoneos
CURRENTCONFIG_SIMULATOR_DIR=${SYMROOT}/${CONFIGURATION}-iphonesimulator

echo "Taking device build from: ${CURRENTCONFIG_DEVICE_DIR}"
echo "Taking simulator build from: ${CURRENTCONFIG_SIMULATOR_DIR}"

CREATING_UNIVERSAL_DIR=${SYMROOT}/${CONFIGURATION}-universal
echo "...outputing a universal arm6/arm7/i386 build to: ${CREATING_UNIVERSAL_DIR}"

# ... remove the products of previous runs of this script
#      NB: this directory is only created by this script - it should be safe to delete

rm -rf "${CREATING_UNIVERSAL_DIR}"
mkdir "${CREATING_UNIVERSAL_DIR}"

#
echo "lipo: for current configuration (${CONFIGURATION}) creating output file: ${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME}"
lipo -create -output "${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME}" "${CURRENTCONFIG_DEVICE_DIR}/${EXECUTABLE_NAME}" "${CURRENTCONFIG_SIMULATOR_DIR}/${EXECUTABLE_NAME}"
fi