#!/bin/bash
set -euo pipefail

ROOT_PATH="$(dirname "$0")/.."
AIRSHIP_VERSION="$(bash "$ROOT_PATH/scripts/airship_version.sh")"

if [ "${1:-}" = "$AIRSHIP_VERSION" ]; then
  exit 0
fi

echo "Version mismatch: tag does not match AirshipConfig.xcconfig ($AIRSHIP_VERSION)" >&2
exit 1
