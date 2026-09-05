#!/bin/bash
# release_prebuilt.sh [VERSION]
#  Stage 3 of the release. Kicks off the prebuilt repo's release workflow.
#
#  Requires a token with workflow scope on urbanairship/ios-library-prebuilt
#  (GITHUB_TOKEN in CI, or your own gh auth locally).

set -euo pipefail

VERSION="${1:-}"
PREBUILT_REPO="${AIRSHIP_PREBUILT_REPO:-urbanairship/ios-library-prebuilt}"

if [ -n "$VERSION" ]; then
  ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
  bash "$ROOT_PATH/scripts/check_version.sh" "$VERSION"
fi

gh --repo "$PREBUILT_REPO" workflow run release.yml

echo "Kicked off release.yml in $PREBUILT_REPO"
