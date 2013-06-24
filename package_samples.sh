#!/bin/sh

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
srcRoot=$(pwd)
destPath="${srcRoot}/${buildConfig}"

for expected in InboxSample PushSample Airship; do
	if [ ! -d "$expected" ]; then
		echo "You need to run this script under root directory."
		exit -1
	fi
done

# Remove any old deploy
rm -rf "${destPath}"
mkdir -p "${destPath}"

# Prepare Airship
#################
rm -rf distribution_binaries
./buildTarget.sh AirshipLib
./update_library_reference.sh
./package_airshiplib.sh

airshipPath="${srcRoot}/Airship"

echo "cp -R \"${airshipPath}\" \"${srcRoot}/${buildConfig}\""
cp -R "${airshipPath}" "${srcRoot}/${buildConfig}"

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
cp "${airshipPath}/../CHANGELOG" "${destPath}/Airship"
cp "${airshipPath}/../README.rst" "${destPath}/Airship"
cp "${airshipPath}/../LICENSE" "${destPath}/Airship"


# Prepare Samples
#################

cp -R InboxSample "${destPath}/RichPushSample" # Rename InboxSample to RichPushSample
cp -R PushSample "${destPath}"

# copy the sample plist into place
for sample in RichPushSample PushSample; do
	samplePath="${destPath}/${sample}"

	rm -rf `find ${samplePath} -name "build"`
	rm -rf `find ${samplePath} -name "*SampleLib.xcodeproj"`
	rm -rf `find ${samplePath} -name "*Tests"`
	rm -rf `find ${samplePath} -name "*Test*.plist"`
	rm -rf `find ${samplePath} -name "*Test*.pch"`
	rm -rf `find ${samplePath} -name "*.orig" `

	#delete user-specific xcode files
	rm -rf `find ${samplePath} -name "*.mode1v3" `
	rm -rf `find ${samplePath} -name "*.pbxuser" `
	rm -rf `find ${samplePath} -name "*.perspective*" `
	rm -rf `find ${samplePath} -name "xcuserdata" `

	#delete the testing config plist
	rm -rf `find ${samplePath} -name "AirshipDevelopment.plist" `

    cp CHANGELOG $samplePath
    cp LICENSE $samplePath
    cp README.rst $samplePath
    mv -f $samplePath/AirshipConfig.plist.sample $samplePath/AirshipConfig.plist
done

# Package Release
#################

#TODO: pull out version number from xcodeproject and create both files.
cd $destPath

for package in RichPushSample PushSample Airship; do
	zip -r libUAirship-latest.zip $package
done

cd ..





