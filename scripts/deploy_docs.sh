#!/bin/bash
  
set -o pipefail
set -e
set -x

LIB_VERSION=$(awk <./AirshipKit/AirshipConfig.xcconfig "\$1 == \"CURRENT_PROJECT_VERSION\" { print \$3 }")

git clone git@github.com:urbanairship/mobile-docs.git
cd mobile-docs

bash add.sh ios ../build/staging/Documentation/AirshipKit $LIB_VERSION
bash add.sh ios-extensions ../build/staging/Documentation/AirshipAppExtensions $LIB_VERSION

git add .
git commit -a -m "Added docs for ios & ios-extensions ${LIB_VERSION}"
git push origin master
