#!/bin/bash
# release_notes.sh VERSION
#  Prints the CHANGELOG.md section for VERSION to stdout.
#  Exits non-zero when the version has no section.

set -euo pipefail

VERSION="${1:?usage: release_notes.sh VERSION}"
ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"

# Match a line starting with '## Version [VERSION]', allowing the date suffix
# that follows, and stop at the next '## Version' heading.
NOTES=$(awk -v ver="$VERSION" '
  $0 ~ "^## Version " ver "($|[ ]-)" {flag=1; next}
  $0 ~ "^## Version " {flag=0}
  flag
' "$ROOT_PATH/CHANGELOG.md")

NOTES="$(printf '%s' "$NOTES" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$NOTES" ]; then
  echo "Could not find notes for Version $VERSION in CHANGELOG.md" >&2
  exit 1
fi

printf '%s\n' "$NOTES"
