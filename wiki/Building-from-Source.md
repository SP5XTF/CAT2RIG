# Building from source

Requires Xcode 15+ (tests need full Xcode; Command Line Tools are enough to build).

```bash
git clone https://github.com/SP5XTF/CAT2RIG.git
cd CAT2RIG
bash scripts/build_hamlib.sh   # Hamlib 4.7.2, universal (once, a few minutes)
swift test              # 96 tests (Hamlib tests are skipped without the library)
bash build_app.sh       # CAT2RIG.app (ad-hoc signed, includes Hamlib)
bash build_dmg.sh       # CAT2RIG-X.Y.dmg
```

In Xcode: open `Package.swift`, scheme **CAT2RIG**, ▶ to run (no icon/translations in that mode), ⌘U to test.

`VERSION=1.7.0 bash build_app.sh` overrides the version number; `SKIP_HAMLIB=1 bash build_app.sh` builds without Hamlib.

`scripts/build_hamlib.sh` downloads the official Hamlib release, checks its SHA-256, builds arm64 and x86_64 and merges them with `lipo` into `vendor/hamlib/lib/libhamlib.4.dylib` (no Homebrew/autotools needed). `FORCE=1` rebuilds. To update Hamlib change `HAMLIB_VERSION` and `HAMLIB_SHA256` in the script.
