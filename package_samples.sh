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

for sample in InboxSample PushSample StoreFrontSample SubscriptionSample; do
	if [ ! -d "$sample" ]; then
		echo "You need to run this script under root directory."
		exit -1
	fi
done

rm -rf Release
mkdir Release
cp -R *Sample Release

cd Release
rm -rf `find . -name "build"`
rm -rf `find . -name "*SampleLib.xcodeproj"`
rm -rf `find . -name "*Tests"`
rm -rf `find . -name "*Test*.plist"`
rm -rf `find . -name "*Test*.pch"`
rm -rf `find . -name "*.orig" `

#delete user-specific xcode files
rm -rf `find . -name "*.mode1v3" `
rm -rf `find . -name "*.pbxuser" `
rm -rf `find . -name "*.perspective*" `
rm -rf `find . -name "xcuserdata" `

#delete the testing config plist
rm -rf `find . -name "AirshipDevelopment.plist" `

# copy the sample plist into place
for sample in InboxSample PushSample StoreFrontSample SubscriptionSample; do
    cp ../CHANGELOG $sample
    cp ../LICENSE $sample
    cp ../README.rst $sample
    mv -f $sample/AirshipConfig.plist.sample $sample/AirshipConfig.plist
done

#rename packages for distribution
mv StoreFrontSample IAPSample
mv InboxSample RichPushSample
