#!/bin/sh

# Copyright 2009-2014 Urban Airship Inc. All rights reserved.
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


SCRIPT_DIRECTORY=`dirname $0`
OUTPUT_PATH=$SCRIPT_DIRECTORY/output
ROOT_PATH=`dirname "${0}"`/../
XCSCHEME_PATH=`dirname $0`/../AirshipLib/AirshipLib.xcodeproj/xcshareddata/xcschemes/
PBXPROJ_PATH=`dirname $0`/../AirshipLib/AirshipLib.xcodeproj/

# Grab the release version
VERSION=$(awk <$SCRIPT_DIRECTORY/../AirshipLib/Config.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

# Update AirshipLib.xcscheme with the release version
sed "s/-[0-9].[0-9].[0-9].a/-$VERSION.a/g" $XCSCHEME_PATH/AirshipLib.xcscheme > AirshipLib.xcscheme.tmp && mv -f AirshipLib.xcscheme.tmp $XCSCHEME_PATH/AirshipLib.xcscheme

# Update project.pbxproj with the realease version
sed "s/-[0-9].[0-9].[0-9].a/-$VERSION.a/g" $PBXPROJ_PATH/project.pbxproj > project.pbxproj.tmp && mv -f project.pbxproj.tmp $PBXPROJ_PATH/project.pbxproj

# Clean up output directory
rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

./$SCRIPT_DIRECTORY/package_airshiplib.sh $OUTPUT_PATH
./$SCRIPT_DIRECTORY/package_sample.sh $SCRIPT_DIRECTORY/../InboxSample $OUTPUT_PATH
./$SCRIPT_DIRECTORY/package_sample.sh $SCRIPT_DIRECTORY/../PushSample $OUTPUT_PATH

# Rename InboxSample to RichPushSample
mv "${OUTPUT_PATH}/InboxSample" "${OUTPUT_PATH}/RichPushSample"

# Copy LICENSE, README and CHANGELOG
cp "${ROOT_PATH}/CHANGELOG" "${OUTPUT_PATH}"
cp "${ROOT_PATH}/README.rst" "${OUTPUT_PATH}"
cp "${ROOT_PATH}/LICENSE" "${OUTPUT_PATH}"

cd $OUTPUT_PATH
for PACKAGE in RichPushSample PushSample Airship LICENSE CHANGELOG README.rst; do
	zip -r libUAirship-latest.zip $PACKAGE
done
cd -

# Create a versioned zip file
cp $OUTPUT_PATH/libUAirship-latest.zip $OUTPUT_PATH/libUAirship-$VERSION.zip

