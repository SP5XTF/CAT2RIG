#!/bin/bash
# Buduje bibliotekę Hamlib (universal: Apple Silicon + Intel) z oficjalnego wydania
# i umieszcza ją w vendor/hamlib/. Wywoływane automatycznie przez build_app.sh.
#
#   bash scripts/build_hamlib.sh            – zbuduj, jeśli jeszcze nie ma
#   FORCE=1 bash scripts/build_hamlib.sh    – zbuduj od nowa
#
# Wymaga tylko narzędzi Xcode (Command Line Tools). Wydania Hamlib zawierają gotowy
# skrypt configure, więc autotools nie są potrzebne.
#
# Licencja: Hamlib jest na LGPL 2.1. Dołączamy go jako osobną, wymienialną bibliotekę
# .dylib wraz z tekstem licencji i informacją o źródłach (vendor/hamlib/SOURCE.txt).
set -euo pipefail
cd "$(dirname "$0")/.."

HAMLIB_VERSION="4.7.2"
HAMLIB_SHA256="ae1fcf2dbc80ea0786ea8f047b09399c3f7737d1930442f61a031708ed33e88f"
HAMLIB_URL="https://github.com/Hamlib/Hamlib/releases/download/${HAMLIB_VERSION}/hamlib-${HAMLIB_VERSION}.tar.gz"

OUT="vendor/hamlib"
LIB="$OUT/lib/libhamlib.4.dylib"
WORK="build/hamlib"
MIN_MACOS="13.0"

if [ "${FORCE:-0}" != "1" ] && [ -f "$LIB" ] && [ "$(cat "$OUT/VERSION" 2>/dev/null)" = "$HAMLIB_VERSION" ]; then
    echo "Hamlib $HAMLIB_VERSION już zbudowany: $LIB"
    exit 0
fi

mkdir -p "$WORK" "$OUT/lib"
TARBALL="$WORK/hamlib-${HAMLIB_VERSION}.tar.gz"
if [ ! -f "$TARBALL" ]; then
    echo "Pobieram Hamlib $HAMLIB_VERSION…"
    curl -fL --retry 3 -o "$TARBALL" "$HAMLIB_URL"
fi
echo "$HAMLIB_SHA256  $TARBALL" | shasum -a 256 -c -

build_arch() {
    local arch="$1" host="$2"
    local src="$WORK/src-$arch"
    rm -rf "$src"
    mkdir -p "$src"
    tar xzf "$TARBALL" -C "$src" --strip-components 1
    echo "Buduję Hamlib dla $arch (kilka minut)…"
    (
        cd "$src"
        ./configure --host="$host" \
            CC="clang -arch $arch" \
            CFLAGS="-O2 -mmacosx-version-min=$MIN_MACOS" \
            LDFLAGS="-mmacosx-version-min=$MIN_MACOS" \
            --enable-shared --disable-static \
            --without-libusb --without-readline --without-xml-support \
            --without-cxx-binding --without-indi --disable-html-matrix \
            > configure.log 2>&1 || { tail -40 configure.log; exit 1; }
        make -j"$(sysctl -n hw.ncpu)" -C src > make.log 2>&1 || { tail -40 make.log; exit 1; }
    )
    cp "$src/src/.libs/libhamlib.4.dylib" "$WORK/libhamlib-$arch.dylib"
}

build_arch arm64 aarch64-apple-darwin
build_arch x86_64 x86_64-apple-darwin

lipo -create "$WORK/libhamlib-arm64.dylib" "$WORK/libhamlib-x86_64.dylib" -output "$LIB"
install_name_tool -id "@rpath/libhamlib.4.dylib" "$LIB"
strip -x "$LIB"
# Apple Silicon wymaga ważnego podpisu – strip/install_name_tool go unieważniają
codesign --force --sign - "$LIB"

cp "$WORK/src-arm64/COPYING.LIB" "$OUT/COPYING.LIB"
echo "$HAMLIB_VERSION" > "$OUT/VERSION"
cat > "$OUT/SOURCE.txt" <<EOF
CAT2RIG includes the Hamlib library ${HAMLIB_VERSION} (libhamlib.4.dylib),
licensed under the GNU Lesser General Public License 2.1 (see COPYING.LIB).

Unmodified source code of this exact version:
  ${HAMLIB_URL}
  SHA-256: ${HAMLIB_SHA256}
Project: https://github.com/Hamlib/Hamlib

Built with: --without-libusb --without-readline --without-xml-support (universal arm64 + x86_64).
You may replace Contents/Frameworks/libhamlib.4.dylib with your own build of Hamlib 4.x.
EOF

echo "Gotowe: $LIB ($(du -h "$LIB" | cut -f1), $(lipo -archs "$LIB"))"
