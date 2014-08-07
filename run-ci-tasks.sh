#!/bin/bash -ex
set -o pipefail

# Available Xcode Apps (Aug 6 2014)
# XCODE_5_0_2_APP
# XCODE_5_1_1_APP
# XCODE_6_BETA_5_APP

# Additional versions should be set up on the build machine, and your own for testing
# Your ~/.bash_profile might look soemthing like:
# export XCODE_5_0_2_APP=/Applications/Xcode-5.0.2.app
# export XCODE_5_1_1_APP=/Applications/Xcode-5.1.1.app
# export XCODE_6_BETA_5_APP=/Applications/Xcode6-Beta5.app

XCODE_APP=$XCODE_5_1_1_APP

if [ -z "$XCODE_APP" ]; then
  echo "Looks like you're missing Xcode!"
  exit
fi

export DEVELOPER_DIR=$XCODE_APP/Contents/Developer

echo "Switching Xcode versions for the build..."
xcode-select --print-path

./Deploy/distribute.sh

./build_docs.sh

./mock_setup.sh

rm -rf test-output
mkdir -p test-output

# Run our Logic Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=7.0,name=iPhone Retina (4-inch)' -project AirshipLib/AirshipLib.xcodeproj -scheme AirshipLib test | tee test-output/XCTEST-LOGIC.out

# Run our Application Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=7.0,name=iPhone Retina (4-inch)' -project PushSample/PushSampleLib.xcodeproj -scheme PushSample test | tee test-output/XCTEST-APPLICATION.out
