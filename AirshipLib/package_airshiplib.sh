#!/bin/sh

# Copyright 2009-2011 Urban Airship Inc. All rights reserved.
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

buildConfig="$BUILD_STYLE"
srcRoot="$SRCROOT"

srcPath="${srcRoot}/../Airship"
destPath="${srcRoot}/../${buildConfig}/Airship"

if [ -z "$buildConfig" ]; then
	echo "Error: This script is only meant to be run within AirshipLib build phase."
	exit -1
fi

rm -rf "${destPath}"
mkdir -p "${destPath}"
echo "cp -R \"${srcPath}\" \"${srcRoot}/../${buildConfig}\""
cp -R "${srcPath}" "${srcRoot}/../${buildConfig}"

cd "${destPath}"

# Remove all non .h files from /Library and /Common
# Remove all non UA_ items & dirs from Airship/External

find Library \! '(' -name "*.h" -o -name "CHANGELOG*" -o -name "README*" ')' -type f -delete
find Common \! -name "*.h" -type f -delete
find External \! '(' -name "UA_*" -o -name "LICENSE*" -o -name "README*" ')' -type f -delete
find External -type d -empty -delete
rm -rf External/GHUnitIOS.framework
rm -rf External/asi-http-request
rm -rf External/fmdb
rm -rf External/json-framework
rm -rf Test

find . -name "*.orig" -delete

