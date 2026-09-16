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

# Two taps cannot own the same formula name at once, and the runner images
# already carry some of these from homebrew-core (openjdk). Drop whatever holds
# the name so the pinned copy can take it; anything depending on it is about to
# be pointed at the replacement.
if brew list --formula "$FORMULA_NAME" >/dev/null 2>&1; then
  brew uninstall --ignore-dependencies --force "$FORMULA_NAME" >/dev/null 2>&1 || true
fi

brew install "${TAP}/${FORMULA_NAME}"
