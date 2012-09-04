# Version 2.0 (updated for Xcode 4, with some fixes)

# Author: Adam Martin - http://twitter.com/redglassesapps
# Based on: original script from Eonil (main changes: Eonil's script WILL NOT WORK in Xcode GUI - it WILL CRASH YOUR COMPUTER)
#
# More info: see this Stack Overflow question: http://stackoverflow.com/questions/3520977/build-fat-static-library-device-simulator-using-xcode-and-sdk-4

[ "$#" -eq 1 ] || { echo "1 argument (Build Target) required, $# provided" >&2; exit 1; }

#################[ Tests: helps workaround any future bugs in Xcode ]########
#
DEBUG_THIS_SCRIPT="true"

CONFIGURATION="Release"
TARGET_NAME=$1

XCODE_SETTINGS="/tmp/${TARGET_NAME}.settings"

# Query the Xcode Project for the current settings, based on the current target
# Dump the settings output as an awkdb into /tmp
xcodebuild -showBuildSettings -target $TARGET_NAME > ${XCODE_SETTINGS}
xcode_setting() {
    echo $(cat ${XCODE_SETTINGS} | awk "\$1 == \"${1}\" { print \$3 }")
}

SDK_NAME=$(xcode_setting "SDK_NAME")
EXECUTABLE_NAME=$(xcode_setting "EXECUTABLE_NAME")
BUILT_PRODUCTS_DIR=$(xcode_setting "BUILT_PRODUCTS_DIR")
DEPLOY_DIR="${BUILT_PRODUCTS_DIR}/distribution_binaries/"

echo $DEPLOY_DIR

BASE_DIR="/tmp/build"
TARGET_BUILD_DIR="$BASE_DIR/$TARGET_NAME"
SYMROOT="$BASE_DIR/$TARGET_NAME"
OBJROOT="$BASE_DIR/$TARGET_NAME/obj"
BUILD_ROOT="$BASE_DIR/$TARGET_NAME"
BUILD_DIR="$BASE_DIR/$TARGET_NAME"
BUILD_LOGS="$BASE_DIR/$TARGET_NAME/logs"

rm -rf $TARGET_BUILD_DIR

mkdir -p ${DEPLOY_DIR}
mkdir -p ${BUILD_ROOT}
mkdir -p ${BUILD_LOGS}
mkdir -p ${TARGET_BUILD_DIR}

# First, work out the BASESDK version number
#    (incidental: searching for substrings in sh is a nightmare! Sob)
SDK_VERSION=$(echo ${SDK_NAME} | grep -o '.\{3\}$')

ACTION="clean build"

ARM_SDK_TO_BUILD=iphoneos${SDK_VERSION}
ARM_ARCH_TO_BUILD="armv6 armv7"
ARM_LOG_FILE="${BUILD_LOGS}/${TARGET_NAME}.build_output_arm"

SIMULATOR_SDK_TO_BUILD=iphonesimulator${SDK_VERSION}
SIMULATOR_ARCH_TO_BUILD="i386"
SIMULATOR_LOG_FILE="${BUILD_LOGS}/${TARGET_NAME}.build_output_i386"

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

echo "ARM Build: xcodebuild -configuration \"${CONFIGURATION}\" -target \"${TARGET_NAME}\" -sdk \"${ARM_SDK_TO_BUILD}\" -arch \"${ARM_ARCH_TO_BUILD}\" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO"
echo "Build log: ${ARM_LOG_FILE}"

xcodebuild -configuration "${CONFIGURATION}" -target "${TARGET_NAME}" -sdk "${ARM_SDK_TO_BUILD}" -arch "${ARM_ARCH_TO_BUILD}" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO BUILD_DIR="${BUILD_DIR}" SYMROOT="${SYMROOT}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" TARGET_BUILD_DIR="$CURRENTCONFIG_DEVICE_DIR" > ${ARM_LOG_FILE}

echo "Simulator Build: xcodebuild -configuration \"${CONFIGURATION}\" -target \"${TARGET_NAME}\" -sdk \"${SIMULATOR_SDK_TO_BUILD}\" -arch \"${SIMULATOR_ARCH_TO_BUILD}\" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO"
echo "Build log: ${SIMULATOR_LOG_FILE}"

xcodebuild -configuration "${CONFIGURATION}" -target "${TARGET_NAME}" -sdk "${SIMULATOR_SDK_TO_BUILD}" -arch "${SIMULATOR_ARCH_TO_BUILD}" ${ACTION} RUN_CLANG_STATIC_ANALYZER=NO BUILD_DIR="${BUILD_DIR}" SYMROOT="${SYMROOT}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" TARGET_BUILD_DIR="$CURRENTCONFIG_SIMULATOR_DIR" > ${SIMULATOR_LOG_FILE}

# Merge all platform binaries as a fat binary for each configurations.

echo "Taking device build from: ${CURRENTCONFIG_DEVICE_DIR}"
echo "Taking simulator build from: ${CURRENTCONFIG_SIMULATOR_DIR}"

CREATING_UNIVERSAL_DIR=${TARGET_BUILD_DIR}/${CONFIGURATION}-universal
echo "...outputing a universal armv6/armv7/i386 build to: ${CREATING_UNIVERSAL_DIR}"

# ... remove the products of previous runs of this script
#      NB: this directory is only created by this script - it should be safe to delete

rm -rf "${CREATING_UNIVERSAL_DIR}"
mkdir -p "${CREATING_UNIVERSAL_DIR}"

echo "lipo: for current configuration (${CONFIGURATION}) creating output file: ${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME}"
lipo -create -output "${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME}" "${CURRENTCONFIG_DEVICE_DIR}/${EXECUTABLE_NAME}" "${CURRENTCONFIG_SIMULATOR_DIR}/${EXECUTABLE_NAME}"

echo "Copying ${EXECUTABLE_NAME} to ${DEPLOY_DIR}"
cp ${CREATING_UNIVERSAL_DIR}/${EXECUTABLE_NAME} ${DEPLOY_DIR}
