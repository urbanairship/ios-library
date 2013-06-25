#!/bin/sh

# Copyright 2009-2013 Urban Airship Inc. All rights reserved.
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

ROOT_PATH=`dirname "${0}"`/../
SRC_PATH=$1
DEST_PATH=$2
TARGET_PATH="${DEST_PATH}/`basename ${SRC_PATH}`"

# Remvove old package
rm -rf $TARGET_PATH

# Create parent directories
mkdir -p $DEST_PATH
cp -R $SRC_PATH $DEST_PATH

# Delete unwanted files
rm -rf `find ${TARGET_PATH} -name "build"`
rm -rf `find ${TARGET_PATH} -name "*SampleLib.xcodeproj"`
rm -rf `find ${TARGET_PATH} -name "*Tests"`
rm -rf `find ${TARGET_PATH} -name "*Test*.plist"`
rm -rf `find ${TARGET_PATH} -name "*Test*.pch"`
rm -rf `find ${TARGET_PATH} -name "*.orig" `

# Delete user-specific xcode files
rm -rf `find ${TARGET_PATH} -name "*.mode1v3" `
rm -rf `find ${TARGET_PATH} -name "*.pbxuser" `
rm -rf `find ${TARGET_PATH} -name "*.perspective*" `
rm -rf `find ${TARGET_PATH} -name "xcuserdata" `

# Delete the testing config plist
rm -rf `find ${TARGET_PATH} -name "AirshipDevelopment.plist" `

# Copy common change log, license, and readme
cp "${ROOT_PATH}/CHANGELOG" $TARGET_PATH
cp "${ROOT_PATH}/LICENSE" $TARGET_PATH
cp "${ROOT_PATH}/README.rst" $TARGET_PATH

mv -f $TARGET_PATH/AirshipConfig.plist.sample $TARGET_PATH/AirshipConfig.plist
