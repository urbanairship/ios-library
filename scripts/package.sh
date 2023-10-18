#!/bin/bash
# build_docs.sh OUTPUT [PATHS...]
#  - OUTPUT: The output zip.
#  - PATHS: A list of directories or files to be included in the zip


set -o pipefail
set -e

ZIP=$(realpath "$1")

package() {
  if [ -d "$1" ]
  then
    pushd "${1}/.."
    zip -r --symlinks "${ZIP}" "./$(basename $1)"
    popd
  else
    if [ -f "$1" ]
    then
      echo "file: $1"
      zip -j "${ZIP}" "$1"
    else
      for file in $1
      do
        package "$file"
      done
    fi
  fi
}

BUILD_INFO=$(mktemp -d /tmp/build-XXXXX)/BUILD_INFO
echo "Airship SDK v${AIRSHIP_VERSION}" >> ${BUILD_INFO}
echo "Build time: `date`" >> ${BUILD_INFO}
echo "SDK commit: `git log -n 1 --format='%h'`" >> ${BUILD_INFO}
echo "Xcode version: $(xcrun xcodebuild -version | tr '\r\n' ' ')" >> ${BUILD_INFO}

package $BUILD_INFO

for var in "${@:2}"
do
  package "$var"
done