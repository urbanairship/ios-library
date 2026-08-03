#!/bin/bash

set -o pipefail
set -e

# Fetches the pinned Thomas *Scene* layout fixtures from the shared
# urbanairship/thomas-layouts repo into the DevApp resources directory.
#
# The web-maintained thomas-layouts repo organizes scenes as top-level
# `modal/`, `banner/` and `embedded/` directories. We remap those into the
# structure the DevApp expects: Resources/Scenes/{Modal,Banner,Embedded}.
# The in-app *Message* fixtures (Resources/Messages) are tracked directly in
# this repo and are NOT fetched here.
#
# Behavior differs by environment so we never block a build on repo access:
#   * Local dev  -> best effort. If the repo can't be reached, print a warning
#                   and exit 0. DevApp still builds (Scene list just shows
#                   empty until the fetch succeeds).
#   * CI         -> strict. When CI=true (GitHub Actions sets this) any failure
#                   is fatal, so a bad pin or missing access fails the job fast.
#
# Environment overrides:
#   LAYOUTS_REPO_URL    - clone URL (default: the org https URL below)
#   LAYOUTS_REPO_TOKEN  - token with read access, used for private/CI fetches
#   CI                  - "true" enables strict mode

ROOT_PATH=`dirname "${0}"`/..

LAYOUTS_REPO_URL="${LAYOUTS_REPO_URL:-https://github.com/urbanairship/thomas-layouts.git}"
VERSION_FILE="${ROOT_PATH}/layouts.version"
DEST="${ROOT_PATH}/DevApp/Dev App/Thomas/Resources"
MARKER="${DEST}/.layouts.version"

# Map each source directory in thomas-layouts to its destination under Scenes/.
SRC_DIRS=("modal" "banner" "embedded")
DEST_DIRS=("Scenes/Modal" "Scenes/Banner" "Scenes/Embedded")

IS_CI="${CI:-false}"

fail_or_warn() {
  local msg="$1"
  if [ "$IS_CI" = "true" ]; then
    echo "error: fetch-layouts: ${msg}" >&2
    exit 1
  fi
  echo "warning: fetch-layouts: ${msg}" >&2
  echo "warning: fetch-layouts: DevApp will still build, but the Thomas Scene list may be empty. Re-run 'make fetch-layouts' once you have access." >&2
  exit 0
}

# --- read pinned ref -------------------------------------------------------
if [ ! -f "$VERSION_FILE" ]; then
  fail_or_warn "layouts.version not found at ${VERSION_FILE}"
fi

REF="$(grep -v '^[[:space:]]*#' "$VERSION_FILE" | grep -v '^[[:space:]]*$' | head -n1 | tr -d '[:space:]' || true)"
if [ -z "$REF" ]; then
  fail_or_warn "no ref found in layouts.version"
fi

# --- skip if already at the pinned ref (local cache) -----------------------
if [ -f "$MARKER" ] && [ "$(cat "$MARKER" 2>/dev/null)" = "$REF" ]; then
  echo "fetch-layouts: already at ${REF}, skipping."
  exit 0
fi

# --- build the (optionally authenticated) clone URL ------------------------
CLONE_URL="$LAYOUTS_REPO_URL"
if [ -n "${LAYOUTS_REPO_TOKEN:-}" ]; then
  CLONE_URL="https://x-access-token:${LAYOUTS_REPO_TOKEN}@${LAYOUTS_REPO_URL#https://}"
fi

echo "fetch-layouts: fetching Thomas scenes @ ${REF} ..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Redacts the token from any text before it is logged (GitHub also masks
# registered secrets, but never rely on that alone).
redact() {
  local text="$1"
  if [ -n "${LAYOUTS_REPO_TOKEN:-}" ]; then
    text="${text//${LAYOUTS_REPO_TOKEN}/***}"
  fi
  printf '%s' "$text"
}

# Fetch the pinned ref. thomas-layouts publishes no tags, so layouts.version is
# normally a commit SHA. --branch accepts tags and branch names; for a bare SHA
# it fails, so we fall back to init + fetch of that SHA. We capture git's stderr
# (with the token redacted) so auth/ref failures are diagnosable.
export GIT_TERMINAL_PROMPT=0
GIT_ERR=""
if ! GIT_ERR="$(git clone --quiet --depth 1 --branch "$REF" "$CLONE_URL" "$TMP_DIR" 2>&1)"; then
  rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
  if ! GIT_ERR="$( ( git init --quiet "$TMP_DIR" \
         && cd "$TMP_DIR" \
         && git remote add origin "$CLONE_URL" \
         && git fetch --quiet --depth 1 origin "$REF" \
         && git checkout --quiet FETCH_HEAD ) 2>&1 )"; then
    fail_or_warn "could not fetch ref '${REF}' from ${LAYOUTS_REPO_URL}: $(redact "$GIT_ERR")"
  fi
fi

# --- copy each source subtree into its Scenes/ destination -----------------
# Scenes/ subdirectories are part of an Xcode folder reference in the DevApp
# Copy Bundle Resources phase, so each directory must always exist (a missing
# folder reference is a hard build error). We keep each directory and its
# tracked .gitkeep, clear only the fetched contents, then copy the new ones in.
mkdir -p "$DEST"
for i in "${!SRC_DIRS[@]}"; do
  src="${SRC_DIRS[$i]}"
  dst="${DEST_DIRS[$i]}"
  if [ ! -d "${TMP_DIR}/${src}" ]; then
    fail_or_warn "fetched layouts are missing '${src}/' (wrong ref or repo layout changed)"
  fi
  mkdir -p "${DEST}/${dst}"
  find "${DEST}/${dst}" -mindepth 1 ! -name '.gitkeep' -delete 2>/dev/null || true
  cp -R "${TMP_DIR}/${src}/." "${DEST}/${dst}/"
done

# --- guard against a silently-empty result ---------------------------------
COUNT="$(find "${DEST}/Scenes" -type f ! -name '.gitkeep' 2>/dev/null | wc -l | tr -d '[:space:]')"
if [ "${COUNT:-0}" -eq 0 ]; then
  fail_or_warn "no scene files present after fetch"
fi

echo "$REF" > "$MARKER"
echo "fetch-layouts: fetched ${COUNT} Thomas scene files @ ${REF}."
