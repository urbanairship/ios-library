#!/bin/bash -ex
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

VERSION=$(awk <$ROOT_PATH/Airship/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

upload() {
  echo -e "Uploading $1 into ${VERSION}"
  curl -T $1 -H "X-Bintray-Package:urbanairship-sdk" -H "X-Bintray-Version:${VERSION}" \
    -H "X-Bintray-Publish:0" -u $BINTRAY_AUTH https://api.bintray.com/content/urbanairship/iOS/urbanairship-sdk/${VERSION}/
}

# Upload to bintray
upload "$ROOT_PATH/build/Airship.zip"

# Fix version release date and description
VERSION_PATCH="{ \"desc\": \"Urban Airship SDK for iOS\", \"released\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}"
curl --request PATCH -H "Content-Type: application/json" -u $BINTRAY_AUTH --data "$VERSION_PATCH" https://api.bintray.com/packages/urbanairship/iOS/urbanairship-sdk/versions/${VERSION}

# Publish
curl -X POST -u $BINTRAY_AUTH https://api.bintray.com/content/urbanairship/iOS/urbanairship-sdk/${VERSION}/publish

# Needed or show in download list fails because bintray thinks the release is not published yet
sleep 30

# Show in download list
curl -X PUT -H "Content-Type: application/json" -u $BINTRAY_AUTH --data '{"list_in_downloads":true}' https://api.bintray.com/file_metadata/urbanairship/iOS/urbanairship-sdk/${VERSION}/Airship.zip
