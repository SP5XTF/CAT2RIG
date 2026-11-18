# Building from source

Requires Xcode 15+ (tests need full Xcode; Command Line Tools are enough to build).

```bash
git clone https://github.com/<your-user>/CAT2RIG.git
cd CAT2RIG
swift test              # 78 tests
bash build_app.sh       # CAT2RIG.app (ad-hoc signed)
bash build_dmg.sh       # CAT2RIG-X.Y.dmg
```

In Xcode: open `Package.swift`, scheme **CAT2RIG**, ▶ to run (no icon/translations in that mode), ⌘U to test.

`VERSION=1.5.0 bash build_app.sh` overrides the version number.
