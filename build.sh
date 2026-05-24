#!/usr/bin/env bash
set -euo pipefail

PROJECT="simple-alt-tab-app.xcodeproj"
SCHEME="simple-alt-tab-app"
CONFIGURATION="Release"
DERIVED_DATA=".build/DerivedData"
DIST_DIR="dist"
APP_NAME="simple-alt-tab-app.app"
BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}"
DIST_APP="${DIST_DIR}/${APP_NAME}"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  ENABLE_APP_SANDBOX=NO \
  build

rm -rf "${DIST_APP}"
mkdir -p "${DIST_DIR}"
ditto "${BUILT_APP}" "${DIST_APP}"
codesign --force --deep --sign - "${DIST_APP}"

echo "Built: ${DIST_APP}"
