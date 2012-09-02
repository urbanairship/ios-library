# Version 2.0 (updated for Xcode 4, with some fixes)

# Author: Adam Martin - http://twitter.com/redglassesapps
# Based on: original script from Eonil (main changes: Eonil's script WILL NOT WORK in Xcode GUI - it WILL CRASH YOUR COMPUTER)
#
# More info: see this Stack Overflow question: http://stackoverflow.com/questions/3520977/build-fat-static-library-device-simulator-using-xcode-and-sdk-4

#################[ Tests: helps workaround any future bugs in Xcode ]########
#
DEBUG_THIS_SCRIPT="true"

CONFIGURATION="Release"
TARGET_NAME=$1

SDK_NAME=$(xcodebuild -showBuildSettings -target $TARGET_NAME | awk '$1 == "SDK_NAME" { print $3 }')
EXECUTABLE_NAME=$(xcodebuild -showBuildSettings -target $TARGET_NAME | awk '$1 == "EXECUTABLE_NAME" { print $3 }')
BUILT_PRODUCTS_DIR=$(xcodebuild -showBuildSettings -target $TARGET_NAME | awk '$1 == "BUILT_PRODUCTS_DIR" { print $3 }')
DEPLOY_DIR="${BUILT_PRODUCTS_DIR}/Distribution"

SYMROOT="/tmp/build"
OBJROOT="/tmp/build/obj"
BUILD_ROOT="/tmp/build"
BUILD_DIR="/tmp/build"
BUILD_LOGS="/tmp/build/logs"
TARGET_BUILD_DIR="/tmp/build"

mkdir ${DEPLOY_DIR}
mkdir ${BUILD_ROOT}
mkdir ${BUILD_LOGS}
mkdir ${TARGET_BUILD_DIR}

# First, work out the BASESDK version number
#    (incidental: searching for substrings in sh is a nightmare! Sob)
SDK_VERSION=$(echo ${SDK_NAME} | grep -o '.\{3\}$')

ACTION="build"

ARM_SDK_TO_BUILD=iphoneos${SDK_VERSION}
ARM_ARCH_TO_BUILD="armv6 armv7"

SIMULATOR_SDK_TO_BUILD=iphonesimulator${SDK_VERSION}
SIMULATOR_ARCH_TO_BUILD="i386"

# Calculate where the (multiple) built files are coming from:
CURRENTCONFIG_DEVICE_DIR=${TARGET_BUILD_DIR}/${CONFIGURATION}-iphoneos
CURRENTCONFIG_SIMULATOR_DIR=${TARGET_BUILD_DIR}/${CONFIGURATION}-iphonesimulator

if [ $DEBUG_THIS_SCRIPT = "true" ]
then
echo "########### TESTS #############"
echo "Use the following variables when debugging this script; note that they may change on recursions"
echo "Executable name is $EXECUTABLE_NAME"
echo "DEPLOY_DIR = $DEPLOY_DIR"
echo "BUILD_DIR = $BUILD_DIR"
echo "BUILD_ROOT = $BUILD_ROOT"
echo "BUILT_PRODUCTS_DIR = $BUILT_PRODUCTS_DIR"
echo "TARGET_BUILD_DIR = $TARGET_BUILD_DIR"
fi

echo "xcodebuild -configuration \"${CONFIGURATION}\" -target \"${TARGET_NAME}\" -sdk \"${ARM_SDK_TO_BUILD}\" -arch \"${ARM_ARCH_TO_BUILD}\" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO"
xcodebuild -configuration "${CONFIGURATION}" -target "${TARGET_NAME}" -sdk "${ARM_SDK_TO_BUILD}" -arch "${ARM_ARCH_TO_BUILD}" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO BUILD_DIR="${BUILD_DIR}" SYMROOT="${SYMROOT}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" TARGET_BUILD_DIR="$CURRENTCONFIG_DEVICE_DIR" > "${BUILD_LOGS}/${TARGET_NAME}.build_output_arm"

echo "xcodebuild -configuration \"${CONFIGURATION}\" -target \"${TARGET_NAME}\" -sdk \"${SIMULATOR_SDK_TO_BUILD}\" -arch \"${SIMULATOR_ARCH_TO_BUILD}\" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO"
xcodebuild -configuration "${CONFIGURATION}" -target "${TARGET_NAME}" -sdk "${SIMULATOR_SDK_TO_BUILD}" -arch "${SIMULATOR_ARCH_TO_BUILD}" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO BUILD_DIR="${BUILD_DIR}" SYMROOT="${SYMROOT}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" TARGET_BUILD_DIR="$CURRENTCONFIG_SIMULATOR_DIR" > "${BUILD_LOGS}/${TARGET_NAME}.build_output_i386"

# Merge all platform binaries as a fat binary for each configurations.

echo "Taking device build from: ${CURRENTCONFIG_DEVICE_DIR}"
echo "Taking simulator build from: ${CURRENTCONFIG_SIMULATOR_DIR}"

CREATING_UNIVERSAL_DIR=${TARGET_BUILD_DIR}/${CONFIGURATION}-universal
echo "...outputing a universal arm6/arm7/i386 build to: ${CREATING_UNIVERSAL_DIR}"

# ... remove the products of previous runs of this script
#      NB: this directory is only created by this script - it should be safe to delete

rm -rf "${CREATING_UNIVERSAL_DIR}"
mkdir "${CREATING_UNIVERSAL_DIR}"

#
echo "lipo: for current configuration (${CONFIGURATION}) creating output file: ${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME}"
lipo -create -output "${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME}" "${CURRENTCONFIG_DEVICE_DIR}/${EXECUTABLE_NAME}" "${CURRENTCONFIG_SIMULATOR_DIR}/${EXECUTABLE_NAME}"

cp ${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME} ${DEPLOY_DIR}/
