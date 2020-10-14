#!/bin/bash
# get_xcode_path.sh ARG
#  - ARG: The version number or path

set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..

XCODE_APPS_FINDER=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'")
XCODE_APPS_FALLBACK=$(find /Applications -iname 'Xcode*.app' -maxdepth 1)
XCODE_APPS=$(echo -e "$XCODE_APPS_FINDER\n$XCODE_APPS_FALLBACK" | sort | uniq)
PLIST_BUDDY="/usr/libexec/PlistBuddy"
XCODE_ARG=$1

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

if [ -d "$XCODE_ARG" ]
then
  echo $2
  exit 0
fi

for APP in $XCODE_APPS; do
  APP_VERSION=$(get_version $APP)
  if [ $XCODE_ARG = $APP_VERSION ]; then
    echo $APP
    exit 0
  fi
done

echo "Failed to find $XCODE_ARG. Available versions: " 1>&2

for APP in $XCODE_APPS; do
  APP_VERSION=$(get_version $APP)
  echo "$APP_VERSION: $APP" 1>&2
done

exit 1