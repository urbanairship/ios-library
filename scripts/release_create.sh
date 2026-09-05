#!/bin/bash
# release_create.sh VERSION
#  Stage 1 of the release. Creates the GitHub release for VERSION as a *draft*,
#  with the notes for that version from CHANGELOG.md. No build, no Xcode.
#
#  Idempotent: re-running against an existing draft refreshes its notes. Refuses
#  to touch a release that has already been published — stage 2 does that flip,
#  and re-drafting a live release would pull it out from under consumers.

set -euo pipefail

VERSION="${1:?usage: release_create.sh VERSION}"
ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${AIRSHIP_RELEASE_REPO:-urbanairship/ios-library}"

bash "$ROOT_PATH/scripts/check_version.sh" "$VERSION"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
bash "$ROOT_PATH/scripts/release_notes.sh" "$VERSION" > "$NOTES_FILE"

if gh release view "$VERSION" --repo "$REPO" >/dev/null 2>&1; then
  IS_DRAFT="$(gh release view "$VERSION" --repo "$REPO" --json isDraft --jq .isDraft)"
  if [ "$IS_DRAFT" != "true" ]; then
    echo "Release $VERSION is already published — leaving it alone." >&2
    exit 1
  fi
  echo "Draft $VERSION already exists; refreshing notes."
  gh release edit "$VERSION" --repo "$REPO" --notes-file "$NOTES_FILE"
else
  gh release create "$VERSION" \
    --repo "$REPO" \
    --title "$VERSION" \
    --notes-file "$NOTES_FILE" \
    --draft \
    --verify-tag
fi

echo "Draft release ready: https://github.com/$REPO/releases/tag/$VERSION"
