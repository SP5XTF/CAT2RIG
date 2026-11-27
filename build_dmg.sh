#!/bin/bash
# Tworzy obraz dysku CAT2RIG-<wersja>.dmg z aplikacją i skrótem do folderu Programy.
#   bash build_dmg.sh               – buduje aplikację i DMG
#   SKIP_BUILD=1 bash build_dmg.sh  – użyj już zbudowanej CAT2RIG.app
set -euo pipefail
cd "$(dirname "$0")"

APP="CAT2RIG.app"
if [ "${SKIP_BUILD:-0}" != "1" ]; then
    bash build_app.sh
fi
[ -d "${APP}" ] || { echo "Brak ${APP} – uruchom najpierw: bash build_app.sh"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP}/Contents/Info.plist")
DMG="CAT2RIG-${VERSION}.dmg"

# zawartość obrazu: aplikacja + skrót do /Applications (przeciągnij i upuść)
STAGE=$(mktemp -d)
trap 'rm -rf "${STAGE}"' EXIT
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

rm -f "${DMG}"
hdiutil create \
    -volname "CAT2RIG ${VERSION}" \
    -srcfolder "${STAGE}" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov "${DMG}"

hdiutil verify "${DMG}" >/dev/null
echo
echo "Gotowe: $(pwd)/${DMG} ($(du -h "${DMG}" | cut -f1))"
