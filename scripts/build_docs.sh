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

   bundle exec jazzy \
  --module $2  \
  --module-version $AIRSHIP_VERSION \
  --build-tool-arguments -scheme,$2 \
  --framework-root "$ROOT_PATH/$1" \
  --output "$OUTPUT/$2" \
  --sdk iphoneos \
  --skip-undocumented \
  --hide-documentation-coverage \
  --config "$ROOT_PATH/Documentation/.jazzy.json"
}

echo -ne "\n\n *********** BUILDING DOCS *********** \n\n"
build_docs_swift "Airship" "AirshipCore"
build_docs_swift "Airship" "AirshipPreferenceCenter"
build_docs_swift "Airship" "AirshipMessageCenter"
build_docs_swift "Airship" "AirshipAutomation"
build_docs_swift "Airship" "AirshipFeatureFlags"
build_docs_swift "Airship" "AirshipObjectiveC"
build_docs_swift "AirshipExtensions" "AirshipNotificationServiceExtension"
