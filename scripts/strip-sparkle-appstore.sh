#!/bin/bash
# Strip Sparkle.framework from App Store builds.
# Added as a Run Script build phase for the PasteShelf target.

if [ "${CONFIGURATION}" = "Release-AppStore" ]; then
    SPARKLE_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sparkle.framework"
    if [ -d "${SPARKLE_PATH}" ]; then
        echo "Stripping Sparkle.framework from App Store build"
        rm -rf "${SPARKLE_PATH}"
    fi
fi
