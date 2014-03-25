#!/bin/bash -ex

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

ROOT_PATH=`dirname "${0}"`/../
DEST_PATH=$1

AIRSHIP_PATH="${ROOT_PATH}/Airship"
AIRSHIP_LIB_PATH="${ROOT_PATH}/AirshipLib"

# Build the distribution binary
rm -rf "${AIRSHIP_LIB_PATH}/distribution_binaries"
bash "${AIRSHIP_LIB_PATH}/buildTarget.sh" AirshipLib
bash "${AIRSHIP_LIB_PATH}/buildTarget.sh" AirshipLib-iOS5
bash "${AIRSHIP_LIB_PATH}/update_library_reference.sh"

# Remove any old deploy
rm -rf "${DEST_PATH}/Airship"
mkdir -p "${DEST_PATH}/Airship"

# Prepare Airship
#################
echo "cp -R \"${AIRSHIP_PATH}\" \"${DEST_PATH}\""
cp -R "${AIRSHIP_PATH}" "${DEST_PATH}"

# Remove all non .h files from /Library and /Common
# Remove all non UA_ items & dirs from Airship/External
find "${DEST_PATH}/Airship/Common" \! -name "*.h" -type f -delete
find "${DEST_PATH}/Airship/Push" \! -name "*.h" -type f -delete
find "${DEST_PATH}/Airship/Inbox" \! -name "*.h" -type f -delete

# Delete internal test headers
rm -rf `find "${DEST_PATH}/Airship" -name "*+Internal.h" `

find "${DEST_PATH}/Airship/External" \! '(' -name "UA_*.h" -o -name "UA_" ')' -type f -delete
find "${DEST_PATH}/Airship/External" -type d -empty -delete
rm -rf "${DEST_PATH}/Airship/TestSamples"
rm -rf "${DEST_PATH}/Airship/Test"

# Remove the Appledoc documenation settings from the distribution
rm "${DEST_PATH}/Airship/AppledocSettings.plist"

find "${DEST_PATH}/Airship" -name "*.orig" -delete
