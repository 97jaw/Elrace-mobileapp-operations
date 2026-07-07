#!/bin/sh
# Re-sign Flutter native-asset frameworks (e.g. objective_c.framework) for device installs.
set -e

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ ! -d "${FRAMEWORKS_DIR}" ]; then
  exit 0
fi

if [ -z "${EXPANDED_CODE_SIGN_IDENTITY}" ] || [ "${EXPANDED_CODE_SIGN_IDENTITY}" = "-" ]; then
  echo "warning: Skipping embedded framework re-sign (no signing identity)"
  exit 0
fi

find "${FRAMEWORKS_DIR}" -type d -name '*.framework' | while read -r framework; do
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    --preserve-metadata=identifier,entitlements,flags \
    "${framework}"
done
