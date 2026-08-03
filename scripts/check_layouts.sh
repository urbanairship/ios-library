#!/bin/bash

# Warning-only guard, intended as a DevApp Xcode pre-build run-script phase.
#
# It reminds developers to fetch the Thomas Scene fixtures if they are missing,
# but NEVER fails the build: the DevApp must build even without access to the
# shared urbanairship/thomas-layouts repo (the Scene list just shows empty).
#
# Fetching itself is intentionally NOT done here (no network / writes in the
# build sandbox); run `make fetch-layouts` from the repo root instead.

RES="${SRCROOT}/Dev App/Thomas/Resources"

# Only Scenes are fetched from the shared repo; Messages are tracked in-repo.
COUNT="$(find "${RES}/Scenes" -type f ! -name '.gitkeep' 2>/dev/null | wc -l | tr -d '[:space:]')"

if [ "${COUNT:-0}" -eq 0 ]; then
  echo "warning: Thomas Scene fixtures not found. Run 'make fetch-layouts' from the repo root to populate them. DevApp will still build, but the Thomas Scene list will be empty."
fi

exit 0
