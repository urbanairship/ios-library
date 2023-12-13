#!/bin/bash
# build_docs.sh OUTPUT
#  - OUTPUT: The output directory.


set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..
OUTPUT="$1"


function build_docs_swift {
  # $1 Project
  # $2 Module
  # $3 Umbrella header path

   bundle exec jazzy \
  --module $2  \
  --module-version $AIRSHIP_VERSION \
  --build-tool-arguments -scheme,$2 \
  --framework-root "$ROOT_PATH/$1" \
  --output "$OUTPUT/$2" \
  --sdk iphonesimulator \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config "$ROOT_PATH/Documentation/.jazzy.json"
}


function build_docs {
  # $1 Project
  # $2 Module
  # $3 Umbrella header path

   bundle exec jazzy \
  --objc \
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

build_docs "Airship" "AirshipBasement"  "Source/Public/AirshipBasement.h"

build_docs_swift "Airship" "AirshipCore"
build_docs_swift "Airship" "AirshipPreferenceCenter"
build_docs_swift "Airship" "AirshipMessageCenter"  "Source/AirshipMessageCenter.h"
build_docs_swift "Airship" "AirshipAutomationSwift"  "Source/AirshipAutomationSwift.h"

build_docs "Airship" "AirshipAutomation"  "Source/AirshipAutomation.h"
build_docs "AirshipExtensions" "AirshipNotificationServiceExtension" "Source/AirshipNotificationServiceExtension.h"
build_docs "AirshipExtensions" "AirshipNotificationContentExtension" "Source/AirshipNotificationContentExtension.h"
