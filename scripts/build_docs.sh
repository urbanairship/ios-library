#!/bin/bash
# build_docs.sh OUTPUT
#  - OUTPUT: The output directory.


set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..
OUTPUT="$1"

function build_docs {
  # $1 Project
  # $2 Module
  # $3 Umbrella header path

   bundle exec jazzy \
  --objc \
  --clean \
  --module $2  \
  --module-version $AIRSHIP_VERSION \
  --framework-root "$ROOT_PATH/$1" \
  --umbrella-header "$ROOT_PATH/$1/$2/$3" \
  --output "$OUTPUT/$2" \
  --sdk iphonesimulator \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config "$ROOT_PATH/Documentation/.jazzy.json"
}

echo -ne "\n\n *********** BUILDING DOCS *********** \n\n"
build_docs "Airship" "Airship" "Source/Airship.h"
build_docs "Airship" "AirshipCore" "Source/common/AirshipCore.h"
build_docs "Airship" "AirshipLocation"  "Source/AirshipLocation.h"
build_docs "Airship" "AirshipAutomation"  "Source/AirshipAutomation.h"
build_docs "Airship" "AirshipMessageCenter"  "Source/AirshipMessageCenter.h"
build_docs "Airship" "AirshipExtendedActions"  "Source/AirshipExtendedActions.h"
build_docs "Airship" "AirshipAccengage"  "Source/AirshipAccengage.h"
build_docs "AirshipExtensions" "AirshipNotificationServiceExtension" "Source/AirshipNotificationServiceExtension.h"
build_docs "AirshipExtensions" "AirshipNotificationContentExtension" "Source/AirshipNotificationContentExtension.h"
