#!/bin/bash -ex

# Copyright 2009-2016 Urban Airship Inc. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# 2. Redistributions in binaryform must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided withthe distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../
OUTPUT_PATH=$ROOT_PATH/build/distribution
XCSCHEME_PATH=$ROOT_PATH/AirshipLib/AirshipLib.xcodeproj/xcshareddata/xcschemes/
PBXPROJ_PATH=$ROOT_PATH/AirshipLib/AirshipLib.xcodeproj/

AIRSHIP_PATH="${ROOT_PATH}/Airship"
AIRSHIP_LIB_PATH="${ROOT_PATH}/AirshipLib"
AIRSHIP_KIT_PATH="${ROOT_PATH}/AirshipKit"
AIRSHIP_APP_EXTENSIONS_PATH="${ROOT_PATH}/AirshipAppExtensions"

# Set the appropriate xcode version

source "${SCRIPT_DIRECTORY}"/configure_xcode_version.sh

# Grab the release version
VERSION=$(awk <$SCRIPT_DIRECTORY/../AirshipLib/Config.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

function package_airship {
    # Build the distribution binary
    rm -rf "${AIRSHIP_LIB_PATH}/distribution_binaries"
    bash "${SCRIPT_DIRECTORY}/build_target.sh" "${PBXPROJ_PATH}" "AirshipLib"
    bash "${SCRIPT_DIRECTORY}/build_target.sh" "${PBXPROJ_PATH}" "AirshipResources"
    bash "${SCRIPT_DIRECTORY}/update_library_reference.sh"

    # Prepare Airship
    #################
    echo "cp -R \"${AIRSHIP_PATH}\" \"${OUTPUT_PATH}\""
    cp -R "${AIRSHIP_PATH}" "${OUTPUT_PATH}"

    # Copy AirshipKit
    #################
    echo "cp -R \"${AIRSHIP_KIT_PATH}\" \"${OUTPUT_PATH}\""
    cp -R "${AIRSHIP_KIT_PATH}" "${OUTPUT_PATH}"

    # Copy AirshipAppExtensions
    ###########################
    echo "cp -R \"${AIRSHIP_APP_EXTENSIONS_PATH}\" \"${OUTPUT_PATH}\""
    cp -R "${AIRSHIP_APP_EXTENSIONS_PATH}" "${OUTPUT_PATH}"

    # Remove all non .h files from /Library and /Common
    # Remove all non UA_ items & dirs from Airship/External
    find "${OUTPUT_PATH}/Airship/Common" \! -name "*.h" -type f -delete
    find "${OUTPUT_PATH}/Airship/Push" \! -name "*.h" -type f -delete
    find "${OUTPUT_PATH}/Airship/Inbox" \! -name "*.h" -type f -delete

    # Delete internal test headers
    rm -rf `find "${OUTPUT_PATH}/Airship" -name "*+Internal.h" `


    find "${OUTPUT_PATH}/Airship/External" \! '(' -name "UA_*.h" -o -name "UA_" ')' -type f -delete
    find "${OUTPUT_PATH}/Airship/External" -type d -empty -delete
    rm -rf "${OUTPUT_PATH}/Airship/TestSamples"
    rm -rf "${OUTPUT_PATH}/Airship/Test"

    # Remove unwanted files
    rm "${OUTPUT_PATH}/Airship/AppledocSettings.plist"
    rm -rf "${OUTPUT_PATH}/AirshipKit/AirshipKitSource.xcodeproj"

    find "${OUTPUT_PATH}/Airship" -name "*.orig" -delete
}

function package_sample {
    if [[ $# -ne 1 ]] ; then
        echo 'Need to specify target'
        exit 0
    fi

    SAMPLE_PATH="${1}"
    TARGET_PATH="${OUTPUT_PATH}/`basename ${SAMPLE_PATH}`"

    cp -R $SAMPLE_PATH $TARGET_PATH
    
    # Delete unwanted files
    rm -rf `find ${TARGET_PATH} -name "build"`
    rm -rf `find ${TARGET_PATH} -name "*SampleLib.xcodeproj"`
    rm -rf `find ${TARGET_PATH} -name "*Tests"`
    rm -rf `find ${TARGET_PATH} -name "*Test*.plist"`
    rm -rf `find ${TARGET_PATH} -name "*Test*.pch"`
    rm -rf `find ${TARGET_PATH} -name "*KIFTest*"`
    rm -rf `find ${TARGET_PATH} -name "*.orig" `
    rm -rf `find ${TARGET_PATH} -name "*KIF-Info.plist" `

    # Delete user-specific xcode files
    rm -rf `find ${TARGET_PATH} -name "*.mode1v3" `
    rm -rf `find ${TARGET_PATH} -name "*.pbxuser" `
    rm -rf `find ${TARGET_PATH} -name "*.perspective*" `
    rm -rf `find ${TARGET_PATH} -name "xcuserdata" `

    # Delete the testing config plist
    rm -rf `find ${TARGET_PATH} -name "AirshipDevelopment.plist" `

    mv -f $TARGET_PATH/AirshipConfig.plist.sample $TARGET_PATH/AirshipConfig.plist
}

# Update AirshipLib.xcscheme with the release version
sed "s/-[0-9].[0-9].[0-9].a/-$VERSION.a/g" $XCSCHEME_PATH/AirshipLib.xcscheme > AirshipLib.xcscheme.tmp && mv -f AirshipLib.xcscheme.tmp $XCSCHEME_PATH/AirshipLib.xcscheme

# Update project.pbxproj with the release version
sed "s/-[0-9].[0-9].[0-9].a/-$VERSION.a/g" $PBXPROJ_PATH/project.pbxproj > project.pbxproj.tmp && mv -f project.pbxproj.tmp $PBXPROJ_PATH/project.pbxproj

# Clean up output directory
rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

package_airship
package_sample $ROOT_PATH/SwiftSample
package_sample $ROOT_PATH/Sample

# Verify architectures in the fat binary
lipo "${OUTPUT_PATH}/Airship/libUAirship-$VERSION.a" -verify_arch armv7 armv7s i386 x86_64 arm64

# Verify bitcode is enabled in the fat binary
otool -l "${OUTPUT_PATH}/Airship/libUAirship-$VERSION.a" | grep __LLVM 

bash "${SCRIPT_DIRECTORY}/build_docs.sh"

# Copy the generated docs
mkdir -p "${OUTPUT_PATH}/reference-docs/"
cp -R "${ROOT_PATH}/build/docs/html/" "${OUTPUT_PATH}/reference-docs/"

# Copy LICENSE, README and CHANGELOG
cp "${ROOT_PATH}/CHANGELOG" "${OUTPUT_PATH}"
cp "${ROOT_PATH}/README.md" "${OUTPUT_PATH}"
cp "${ROOT_PATH}/LICENSE" "${OUTPUT_PATH}"

# Build info
BUILD_INFO=$OUTPUT_PATH/BUILD_INFO
echo "Urban Airship SDK v${VERSION}" >> $BUILD_INFO
echo "Build time: `date`" >> $BUILD_INFO
echo "SDK commit: `git log -n 1 --format='%h'`" >> $BUILD_INFO
echo "Xcode version: `xcrun xcodebuild -version | tr '\r\n' ' '`" >> $BUILD_INFO

# Additional build info
if test -f $ROOT_PATH/BUILD_INFO;
    then cat $ROOT_PATH/BUILD_INFO >> $BUILD_INFO;
fi

cd $OUTPUT_PATH
for PACKAGE in SwiftSample Sample Airship AirshipKit AirshipAppExtensions reference-docs LICENSE CHANGELOG README.md BUILD_INFO; do
    zip -r libUAirship-latest.zip $PACKAGE --exclude=*.DS_Store*
done
cd -

# Create a versioned zip file
cp $OUTPUT_PATH/libUAirship-latest.zip $OUTPUT_PATH/libUAirship-$VERSION.zip

