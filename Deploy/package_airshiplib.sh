#!/bin/bash -ex

# Copyright 2009-2012 Urban Airship Inc. All rights reserved.
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

# TODO: make this configurable?
buildConfig="Release"

rootPath=`dirname "${0}"`/../
destPath=$1

airshipPath="${rootPath}/Airship"

# Build the distribution binary
cd "${rootPath}/AirshipLib"
rm -rf distribution_binaries
./buildTarget.sh AirshipLib
./update_library_reference.sh
cd -

# Remove any old deploy
rm -rf "${destPath}/Airship"
mkdir -p "${destPath}/Airship"

# Prepare Airship
#################
echo "cp -R \"${airshipPath}\" \"${destPath}\""
cp -R "${airshipPath}" "${destPath}"

# Remove all non .h files from /Library and /Common
# Remove all non UA_ items & dirs from Airship/External
find "${destPath}/Airship/Library" \! -name "*.h" -type f -delete
find "${destPath}/Airship/Common" \! -name "*.h" -type f -delete

# Delete internal test headers
rm -rf `find "${destPath}/Airship" -name "*+Internal.h" `

find "${destPath}/Airship/External" \! '(' -name "UA_*.h" -o -name "UA_" ')' -type f -delete
find "${destPath}/Airship/External" -type d -empty -delete
rm -rf "${destPath}/Airship/TestSamples"
rm -rf "${destPath}/Airship/Test"

# Remove the Appledoc documenation settings from the distribution
rm "${destPath}/Airship/AppledocSettings.plist"

find "${destPath}/Airship" -name "*.orig" -delete

# Copy LICENSE, README and CHANGELOG
cp "${rootPath}/CHANGELOG" "${destPath}/Airship"
cp "${rootPath}/README.rst" "${destPath}/Airship"
cp "${rootPath}/LICENSE" "${destPath}/Airship"