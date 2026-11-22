# Developer guide

## Layout
```
Sources/CAT2RIGCore/
  SerialPort.swift        termios port, SerialTransport protocol
  RigBackend.swift        RigBackend protocol, RigState, PTTMethod, HamlibErr
  IcomRig.swift           CI-V driver (Icom, Xiegu): bus parser, transceive, data mode, CAT PTT
  PolledSerialRig.swift   base for request/response protocols: polling, client priority, state
  TextCatRig.swift        Yaesu (new) and Kenwood/Elecraft text CAT (TextCatDialect)
  YaesuBinaryRig.swift    FT-817/857/897 binary CAT
  RadioModels.swift       model catalogue + RigFactory
  HamlibLibrary.swift     dlopen of libhamlib, typed C function pointers, model list
  HamlibRig.swift         driver on top of Hamlib (subclass of PolledSerialRig)
  RigctlProtocol.swift    rigctld commands and \dump_state
  RigctlServer.swift      TCP server (Network.framework)
  Localization.swift      L() helper
  ProjectLinks.swift      GitHub URLs (repository, wiki, releases, issues)
Sources/CAT2RIG/          SwiftUI app (window, help, settings)
Tests/CAT2RIGCoreTests/   XCTest with simulated radios
```

## Adding a radio
Usually one line in `RadioModel.all` (`RadioModels.swift`):
```swift
icom("ic7851", "IC-7851/7850", 0x8E, hamlib: 3075),
yaesu("ftdx9000", "FTDX9000", hamlib: 1030, digits: 8),
kenwood("k2", "K2", hamlib: 2021, baud: 4800, maker: "Elecraft"),
```
Add a test in `MultiRigTests.swift` if the radio behaves differently, then regenerate the tables: `python3 scripts/radio_table.py en` / `pl` (README, wiki *Supported-Radios*, *PL-Radia*). Take the Hamlib number from [Hamlib’s list](https://github.com/Hamlib/Hamlib/wiki/Supported-Radios).

## Adding a protocol
1. Subclass `PolledSerialRig` and override `prepare()`, `pollOnce()`, `doSetFreq`, `doSetMode`, `doCatPTT`. Use `send`, `readText`/`readBytes`, `updateFreq`, `updateMode`.
2. Add a `RigProtocolKind` case and a branch in `RigFactory.make`.
3. Write a fake radio (see `FakeCatRadios.swift`) and tests.

## Hamlib
`HamlibLibrary` loads `libhamlib.4.dylib` at runtime (app bundle → `vendor/hamlib` → Homebrew; `CAT2RIG_HAMLIB` overrides) and binds the needed functions with `dlsym` – no headers or link-time dependency. The model list reads the stable start of `struct rig_caps` (model, model_name, mfg_name … status). `HamlibRig` calls Hamlib only inside `withIO`, so access is serialized. Hamlib debug output goes to `~/Library/Logs/CAT2RIG/hamlib.log` via `rig_set_debug_file` (a `va_list` callback can't be declared as `@convention(c)` in Swift).

## Threads
Each driver has a polling thread; client commands (WSJT-X) take priority (`withIO(client: true)`). All shared state is behind locks – drivers are `@unchecked Sendable`.

## Localization
Polish is the base language and the key. Use `L("tekst %@", arg)` in code and `Text("tekst")` in SwiftUI; add the English text to `Resources/en.lproj/Localizable.strings`. `LocalizationTests` fails if an `L()` string has no translation.

## Releasing
1. Add a `## X.Y.Z` section to `CHANGELOG.md` (optionally `docs/releases/vX.Y.Z.md` with full release notes).
2. Bump `VERSION` in `build_app.sh`.
3. Commit, tag `vX.Y.Z`, push the tag – GitHub Actions runs the tests and publishes the DMG and ZIP.
