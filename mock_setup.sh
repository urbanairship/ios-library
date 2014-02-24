#!/bin/sh
 
# In short, this script downloads the OCMockLibrary from https://github.com/erikdoe/ocmock.git, builds the project
# and copies the appropriate files to the test directory. The library is built  The libOCMock.a file and the headers are all that's 
# required.
 
url="https://github.com/erikdoe/ocmock.git"
temp_dir="/tmp/objectClone"
library_source_dir="/tmp/objectClone/Source"
library_build_dir="/tmp/objectClone/Source/build/Release-iphoneos"
library_name="libOCMock.a"
test_dir="TestCommon"
mock_library_dir="OCMockLibrary"
mock_headers="/tmp/objectClone/Source/build/Release-iphoneos/OCMock"
headers_dir="Headers"
device_build="./build/Release-iphoneos/libOCMock.a"
simulator_build="./build/Release-iphonesimulator/libOCMock.a"
 
 
if [ -d "$test_dir/$mock_library_dir" ]
 then 
  echo "Erasing directory"
  rm -r "$test_dir/$mock_library_dir"
  mkdir -v "$test_dir/$mock_library_dir"
fi
 
if [ -d "$temp_dir" ]
 then
  rm -rf "$temp_dir"
fi
 
mkdir -pv "$temp_dir" 
git clone $url "$temp_dir"
 
current_dir=`pwd`
cd "$library_source_dir"
/usr/bin/xcodebuild clean -target OCMockLib 
/usr/bin/xcodebuild -target OCMockLib -sdk iphoneos -arch armv7 -arch armv7s -arch arm64 IPHONEOS_DEPLOYMENT_TARGET=7.0
/usr/bin/xcodebuild -target OCMockLib -sdk iphonesimulator -arch i386 -arch x86_64 
lipo -create -output $library_name $device_build $simulator_build
cd "$current_dir"
 
if [ ! -d "$test_dir/$mock_library_dir" ]
  then
  mkdir -v "$test_dir/$mock_library_dir"
fi
 
mkdir -v "$test_dir/$mock_library_dir/$headers_dir"
cp -rv "$mock_headers" "$test_dir/$mock_library_dir/$headers_dir"
cp -v "$library_source_dir/$library_name" "./$test_dir/$mock_library_dir"
