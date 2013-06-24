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

rootPath=`dirname "${0}"`/../
srcPath=$1
destPath=$2
targetPath="${destPath}/`basename ${srcPath}`"

# Remvove old package
rm -rf $targetPath

# Create parent directories
mkdir -p $destPath
cp -R $srcPath $destPath

# Delete unwanted files
rm -rf `find ${targetPath} -name "build"`
rm -rf `find ${targetPath} -name "*SampleLib.xcodeproj"`
rm -rf `find ${targetPath} -name "*Tests"`
rm -rf `find ${targetPath} -name "*Test*.plist"`
rm -rf `find ${targetPath} -name "*Test*.pch"`
rm -rf `find ${targetPath} -name "*.orig" `

# Delete user-specific xcode files
rm -rf `find ${targetPath} -name "*.mode1v3" `
rm -rf `find ${targetPath} -name "*.pbxuser" `
rm -rf `find ${targetPath} -name "*.perspective*" `
rm -rf `find ${targetPath} -name "xcuserdata" `

# Delete the testing config plist
rm -rf `find ${targetPath} -name "AirshipDevelopment.plist" `

# Copy common change log, license, and readme
cp "${rootPath}/CHANGELOG" $targetPath
cp "${rootPath}/LICENSE" $targetPath
cp "${rootPath}/README.rst" $targetPath

mv -f $targetPath/AirshipConfig.plist.sample $targetPath/AirshipConfig.plist
