#!/bin/bash
# release_attach.sh VERSION [--skip-build]
#  Stage 2 of the release. Builds the distribution zips, attaches them to the
#  draft release for VERSION, then publishes it.
#
#  This is the stage that needs the release Xcode and the signing certificate,
#  so it is the one to run locally when the CI image is behind. Pass --skip-build
#  to attach zips already sitting in ./build.

set -euo pipefail

VERSION="${1:?usage: release_attach.sh VERSION [--skip-build]}"
SKIP_BUILD="${2:-}"
ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${AIRSHIP_RELEASE_REPO:-urbanairship/ios-library}"

bash "$ROOT_PATH/scripts/check_version.sh" "$VERSION"

if ! gh release view "$VERSION" --repo "$REPO" >/dev/null 2>&1; then
  echo "No release for $VERSION — run scripts/release_create.sh first." >&2
  exit 1
fi

if [ "$SKIP_BUILD" != "--skip-build" ]; then
  echo "Building packages with $(xcrun xcodebuild -version | head -1)"
  make -C "$ROOT_PATH" build-package
fi

ASSETS=(
  "$ROOT_PATH/build/Airship.zip"
  "$ROOT_PATH/build/Airship.xcframeworks.zip"
  "$ROOT_PATH/build/Airship.dotnet.xcframeworks.zip"
)

for asset in "${ASSETS[@]}"; do
  if [ ! -f "$asset" ]; then
    echo "Missing $asset — build did not produce the expected zips." >&2
    exit 1
  fi
done

# --clobber so a re-run after a partial upload replaces assets instead of failing.
gh release upload "$VERSION" --repo "$REPO" --clobber "${ASSETS[@]}"

gh release edit "$VERSION" --repo "$REPO" --draft=false

echo "Published: https://github.com/$REPO/releases/tag/$VERSION"
