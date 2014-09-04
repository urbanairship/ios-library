#!/bin/bash -ex

# Available Xcode Apps (Aug 26 2014)
# XCODE_5_0_2_APP
# XCODE_5_1_1_APP
# XCODE_6_BETA_4_APP
# XCODE_6_BETA_5_APP (doesn't appear to work for headless tests - times out)
# XCODE_6_BETA_6_APP (same caveat for headless tests)
# XCODE_6_BETA_7_APP (same caveat for headless tests)

# Additional versions should be set up on the build machine, and your own for testing
# Your ~/.bash_profile might look something like:
# export XCODE_5_0_2_APP=/Applications/Xcode-5.0.2.app
# export XCODE_5_1_1_APP=/Applications/Xcode-5.1.1.app
# export XCODE_6_BETA_5_APP=/Applications/Xcode6-Beta5.app

XCODE_APP=$XCODE_6_BETA_4_APP

if [ -z "$XCODE_APP" ]; then
  echo "Looks like you're missing Xcode!"
  exit
fi

export DEVELOPER_DIR=$XCODE_APP/Contents/Developer

echo "Switching Xcode versions for the build..."
xcode-select --print-path
