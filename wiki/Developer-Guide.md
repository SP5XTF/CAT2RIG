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
  RigctlProtocol.swift    rigctld commands and \dump_state
  RigctlServer.swift      TCP server (Network.framework)
  Localization.swift      L() helper
Sources/CAT2RIG/          SwiftUI app (window, help, settings)
Tests/CAT2RIGCoreTests/   XCTest with simulated radios
```

## Adding a radio
Usually one line in `RadioModel.all` (`RadioModels.swift`):
```swift
icom("ic7851", "IC-7851", 0x8E),
yaesu("ft5000", "FTDX5000", digits: 8),
kenwood("ts890", "TS-890S", baud: 115200),
```
Add a test in `MultiRigTests.swift` if the radio behaves differently, and update the README/wiki tables.

## Adding a protocol
1. Subclass `PolledSerialRig` and override `prepare()`, `pollOnce()`, `doSetFreq`, `doSetMode`, `doCatPTT`. Use `send`, `readText`/`readBytes`, `updateFreq`, `updateMode`.
2. Add a `RigProtocolKind` case and a branch in `RigFactory.make`.
3. Write a fake radio (see `FakeCatRadios.swift`) and tests.

## Threads
Each driver has a polling thread; client commands (WSJT-X) take priority (`withIO(client: true)`). All shared state is behind locks – drivers are `@unchecked Sendable`.

## Localization
Polish is the base language and the key. Use `L("tekst %@", arg)` in code and `Text("tekst")` in SwiftUI; add the English text to `Resources/en.lproj/Localizable.strings`. `LocalizationTests` fails if an `L()` string has no translation.

## Releasing
1. Add a `## X.Y.Z` section to `CHANGELOG.md` (optionally `docs/releases/vX.Y.Z.md` with full release notes).
2. Bump `VERSION` in `build_app.sh`.
3. Commit, tag `vX.Y.Z`, push the tag – GitHub Actions runs the tests and publishes the DMG and ZIP.
