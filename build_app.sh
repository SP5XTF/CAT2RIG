#!/bin/bash
# Buduje CAT2RIG.app (wymaga Xcode albo Command Line Tools: xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-1.7.1}"   # w CI nadpisywane numerem z tagu (v1.2 -> 1.2)

# Hamlib (LGPL) – biblioteka dołączana do aplikacji. SKIP_HAMLIB=1 buduje bez niej.
if [ "${SKIP_HAMLIB:-0}" != "1" ]; then
    bash scripts/build_hamlib.sh || echo "UWAGA: nie udało się zbudować Hamlib – aplikacja będzie bez sterownika Hamlib."
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/CAT2RIG"

APP="CAT2RIG.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/CAT2RIG"

# Hamlib: biblioteka w Frameworks, licencja i informacja o źródłach w Resources/Hamlib
if [ "${SKIP_HAMLIB:-0}" != "1" ] && [ -f vendor/hamlib/lib/libhamlib.4.dylib ]; then
    mkdir -p "${APP}/Contents/Frameworks" "${APP}/Contents/Resources/Hamlib"
    cp vendor/hamlib/lib/libhamlib.4.dylib "${APP}/Contents/Frameworks/"
    cp vendor/hamlib/COPYING.LIB vendor/hamlib/SOURCE.txt "${APP}/Contents/Resources/Hamlib/"
    codesign --force --sign - "${APP}/Contents/Frameworks/libhamlib.4.dylib"
    echo "Dołączono Hamlib $(cat vendor/hamlib/VERSION)"
fi

# ikona
cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"

# tłumaczenia (pl = język bazowy, en = angielski)
for lang in pl en; do
    mkdir -p "${APP}/Contents/Resources/${lang}.lproj"
    plutil -lint "Resources/${lang}.lproj/Localizable.strings" >/dev/null
    plutil -convert binary1 -o "${APP}/Contents/Resources/${lang}.lproj/Localizable.strings" \
        "Resources/${lang}.lproj/Localizable.strings"
done

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>        <string>CAT2RIG</string>
    <key>CFBundleIdentifier</key>        <string>pl.hamradio.cat2rig</string>
    <key>CFBundleName</key>              <string>CAT2RIG</string>
    <key>CFBundleDisplayName</key>       <string>CAT2RIG</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key>           <string>${VERSION}</string>
    <key>CFBundleDevelopmentRegion</key> <string>pl</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>pl</string>
        <string>en</string>
    </array>
    <key>NSHumanReadableCopyright</key>  <string>© 2026 Tomasz SP5XTF · github.com/SP5XTF/CAT2RIG · MIT</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>NSAppSleepDisabled</key>        <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>CAT2RIG shares radio control with programs on the local network (Hamlib rigctl).</string>
</dict>
</plist>
PLIST

codesign --force --sign - "${APP}"
# odśwież pamięć ikon Findera dla nowej wersji
touch "${APP}"
echo "Gotowe: $(pwd)/${APP}"
echo "Uruchom: open ${APP}   (albo przeciągnij do /Applications)"
