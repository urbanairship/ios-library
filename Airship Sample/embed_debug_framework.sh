#!/bin/sh
set -e
set -u
set -o pipefail

install_framework()
{
  echo "Installing framework $1"
  local source="${BUILT_PRODUCTS_DIR}/$(basename "$1")"
  local destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

  mkdir -p "$destination"

  # copy the framework
  cp -R "${source}" "${destination}"

  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" -a "${CODE_SIGNING_REQUIRED:-}" != "NO" -a "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
    # Use the current code_sign_identity
    local binary="${destination}/$(basename "$1")"
    echo "Code Signing ${binary} with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS:-} --preserve-metadata=identifier,entitlements "${binary}"
  fi
}

echo "CONFIGURATION = ${CONFIGURATION}"
if [[ "$CONFIGURATION" == "Debug" ]]; then
  index=0
  while [ $index -lt ${SCRIPT_INPUT_FILE_COUNT} ]; do
    scriptInputVar="SCRIPT_INPUT_FILE_$index"
    framework=${!scriptInputVar}
    if [[ -d $framework && ${framework: -10} == ".framework" ]]; then
      install_framework $framework
    fi
    let index=index+1
  done
fi

