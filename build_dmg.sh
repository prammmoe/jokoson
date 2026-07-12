#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BUILD_ROOT="${BUILD_ROOT:-${PROJECT_ROOT}/.build/DMG}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${BUILD_ROOT}/DerivedData}"
STAGING_PATH="${BUILD_ROOT}/staging"
OUTPUT_PATH="${OUTPUT_PATH:-${PROJECT_ROOT}/Jokoson.dmg}"
CONFIGURATION="${CONFIGURATION:-Release}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

PROVISIONING_ARGS=""
if [ "${ALLOW_PROVISIONING_UPDATES:-NO}" = "YES" ]; then
    PROVISIONING_ARGS="-allowProvisioningUpdates"
fi

rm -rf "${STAGING_PATH}"
mkdir -p "${STAGING_PATH}"

xcodebuild \
    -project "${PROJECT_ROOT}/Jokoson.xcodeproj" \
    -scheme Jokoson \
    -configuration "${CONFIGURATION}" \
    -sdk macosx \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED}" \
    ${PROVISIONING_ARGS} \
    build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/Jokoson.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Expected app was not produced at ${APP_PATH}" >&2
    exit 1
fi

cp -R "${APP_PATH}" "${STAGING_PATH}/Jokoson.app"
ln -s /Applications "${STAGING_PATH}/Applications"
rm -f "${OUTPUT_PATH}"

hdiutil create \
    -volname "Jokoson" \
    -srcfolder "${STAGING_PATH}" \
    -ov \
    -format UDZO \
    "${OUTPUT_PATH}"

echo "Created ${OUTPUT_PATH}"
