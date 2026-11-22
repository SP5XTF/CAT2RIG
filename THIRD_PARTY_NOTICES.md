# Third-party software

## Hamlib

CAT2RIG release builds include the **Hamlib** library (`CAT2RIG.app/Contents/Frameworks/libhamlib.4.dylib`).

- Version: see `vendor/hamlib/VERSION` / *Help* window (currently 4.7.2)
- License: GNU Lesser General Public License 2.1 – full text in `CAT2RIG.app/Contents/Resources/Hamlib/COPYING.LIB`
- Source code: https://github.com/Hamlib/Hamlib – the exact release archive and its SHA-256 are listed in `CAT2RIG.app/Contents/Resources/Hamlib/SOURCE.txt` and in `scripts/build_hamlib.sh`
- Hamlib is unmodified and dynamically loaded. You may replace `libhamlib.4.dylib` with your own build of Hamlib 4.x; CAT2RIG keeps working with its built-in drivers if the library is missing.

CAT2RIG itself is MIT-licensed (see `LICENSE`).
