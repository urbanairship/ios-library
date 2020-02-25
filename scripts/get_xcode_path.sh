#!/bin/bash
set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..
source "$ROOT_PATH/scripts/config.sh"

XCODE_APPS=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'")
PLIST_BUDDY="/usr/libexec/PlistBuddy"

function get_plist_value() {
  "$PLIST_BUDDY" -c "Print :$2" "$1/Contents/Info.plist"
}

function get_version() {
  APP_NAME=$(get_plist_value "$1" "CFBundleName")
  if [[ "$APP_NAME" == "Xcode" ]]; then
    echo $(get_plist_value "$1" "CFBundleShortVersionString")
  else
    echo ""
  fi
}

if [ ! -z "$1" ]; then
  if [ ! -d "$1" ]; then
      echo "Path does not exist: $1" 1>&2
      exit 1
  fi
  echo $1
fi

for APP in $XCODE_APPS; do
  APP_VERSION=$(get_version $APP)
  if [ $XCODE_VERSION = $APP_VERSION ]; then
    echo $APP
    exit 0
  fi
done

echo "Failed to find version $1. Available versions: " 1>&2

for APP in $XCODE_APPS; do
  APP_VERSION=$(get_version $APP)
  echo "$APP $APP_VERSION" 1>&2
done

exit 1
