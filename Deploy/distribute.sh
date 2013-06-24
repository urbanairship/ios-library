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

outputPath="./output"
originalPath=`pwd`

cd `dirname $0`

# Grab the release version
version=$(cat ../AirshipLib/Config.xcconfig | awk "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

# Clean up ouput directory
rm -rf $outputPath
mkdir -p $outputPath

./package_sample.sh "../InboxSample" $outputPath
./package_sample.sh "../PushSample" $outputPath
./package_airshiplib.sh $outputPath

# Rename InboxSample to RichPushSample
mv "${outputPath}/InboxSample" "${outputPath}/RichPushSample"

cd $outputPath

for package in RichPushSample PushSample Airship; do
	zip -r libUAirship-latest.zip $package
	zip -r "libUAirship-${version}.zip" $package
done

cd $originalPath

