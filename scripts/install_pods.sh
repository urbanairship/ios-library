#!/bin/bash

ROOT_PATH=`dirname "${0}"`/..

source "$ROOT_PATH/scripts/config.sh"
bundle exec xcversion select $XCODE_VERSION


# Verify pod version matches the version in the Gemfile.lock
PODFILE_POD_VERSION=$(awk <"$ROOT_PATH/Podfile.lock" "\$1 == \"COCOAPODS:\" { print \$2 }")
GEMFILE_POD_VERSION=$(bundle exec pod --version)

if [ ! $PODFILE_POD_VERSION = $GEMFILE_POD_VERSION ]; then
 echo "Podfile.lock version does not match the Gemfile.lock version. Make sure to update pods with bundle exec pod update."
 exit 1
fi

# Install pods
bundle exec pod install --project-directory="$ROOT_PATH"
