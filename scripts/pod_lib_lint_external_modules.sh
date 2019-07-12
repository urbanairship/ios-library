#!/bin/bash

# pod lib lint for Debug and Location Libraries
set -o pipefail
set -e
set -x

# different paths on Bitrise and local build
if [[ $BITRISE_IO ]]; then
  SOURCE_ROOT="${BITRISE_SOURCE_DIR}"
  SPEC_REPO_LOCATION="${BITRISE_DEPLOY_DIR}/ci-repos"
  TEMP_PODSPEC_STORAGE="${BITRISE_DEPLOY_DIR}/podspecs"
else
  SOURCE_ROOT="$(pwd)"
  SPEC_REPO_LOCATION="${TMPDIR}/ci-repos"
  TEMP_PODSPEC_STORAGE="${TMPDIR}/podspecs"
fi

echo "create local cocoapods specs repo"
[ -d "${SPEC_REPO_LOCATION}" ] && rm -rf "${SPEC_REPO_LOCATION}"
mkdir "${SPEC_REPO_LOCATION}"
cd "${SPEC_REPO_LOCATION}"
git init --bare

echo "add local specs repo to cocoapods"
COCOAPODS_PATH="${HOME}/.cocoapods/repos"
COCOAPODS_CI_SPECS_REPO="$COCOAPODS_PATH/ci-specs/"
[ -d "${COCOAPODS_CI_SPECS_REPO}" ] && pod repo remove ci-specs
pod repo add ci-specs "${SPEC_REPO_LOCATION}"

# Cocoapods 1.7 requires a master branch in the remote before "pod repo push" is run.
git -C "${COCOAPODS_CI_SPECS_REPO}" commit --allow-empty -m "Create empty master branch"
git -C "${COCOAPODS_CI_SPECS_REPO}" push

echo "make a dev copy of UrbanAirship-iOS-SDK.podspec for local publishing"
[ -d "${TEMP_PODSPEC_STORAGE}" ] && rm -rf "${TEMP_PODSPEC_STORAGE}"
mkdir "${TEMP_PODSPEC_STORAGE}"

cd "${SOURCE_ROOT}"
GIT_COMMIT_HASH="$(git rev-parse HEAD)"
GIT_REPO_PATH="$(pwd)"

cat UrbanAirship-iOS-SDK.podspec | sed "s@s\.source .*@s.source = { :git => \"${GIT_REPO_PATH}\", :commit => \"${GIT_COMMIT_HASH}\" }@" > "${TEMP_PODSPEC_STORAGE}/UrbanAirship-iOS-SDK.podspec"

echo "publish UrbanAirship-iOS-SDK pod locally"
pod repo push ci-specs "${TEMP_PODSPEC_STORAGE}/UrbanAirship-iOS-SDK.podspec"

echo "lint UrbanAirship-iOS-Location against local UrbanAirship-iOS-SDK pod"
pod lib lint UrbanAirship-iOS-Location.podspec --sources=ci-specs

echo "lint UrbanAirship-iOS-DebugKit against local UrbanAirship-iOS-SDK pod"
pod lib lint UrbanAirship-iOS-DebugKit.podspec --sources=ci-specs

# cleanup
if [[ ! $BITRISE_IO ]]; then
  pod repo remove ci-specs
  [ -d "${SPEC_REPO_LOCATION}" ] && rm -rf "${SPEC_REPO_LOCATION}"
  [ -d "${TEMP_PODSPEC_STORAGE}" ] && rm -rf "${TEMP_PODSPEC_STORAGE}"
fi
