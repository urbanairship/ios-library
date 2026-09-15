#!/bin/bash
set -euo pipefail

# Installs a Homebrew formula pinned to a specific homebrew-core commit.
#
# Homebrew no longer installs a formula directly from a URL or local path
# (https://github.com/orgs/Homebrew/discussions/4454) - it insists on a
# formula name resolved through a tap. This fetches the pinned formula file
# into a scratch local tap and installs it from there instead.
#
# Usage: brew_install_pinned.sh <formula-name> <raw-formula-url>

FORMULA_NAME="$1"
FORMULA_URL="$2"

TAP="airship/pinned"

brew tap-new "$TAP" >/dev/null 2>&1 || true
curl -fsSL "$FORMULA_URL" -o "$(brew --repository "$TAP")/Formula/${FORMULA_NAME}.rb"
brew install "${TAP}/${FORMULA_NAME}"
