# Changelog

## 1.4.0
- **Support for many radios**: Icom (IC-7000, IC-7100, IC-7300, IC-705, IC-9700, IC-7610, IC-718,
  other CI-V), Xiegu (G90, X6100, X5105), Yaesu text CAT (FT-991/991A, FT-891, FT-710, FTDX10,
  FTDX101, FT-950, FT-450D), Yaesu binary CAT (FT-817/818, FT-857, FT-897), Kenwood (TS-590,
  TS-480, TS-2000) and Elecraft (K3, KX2/KX3, K4)
- Model picker with default baud rate, stop bits, RTS/CTS, CI-V address and PTT
- **CAT PTT** (CI-V 1C 00, Yaesu TX1/TX0, Kenwood TX/RX, FT-817 08/88)
- **DATA mode** for Icom radios with 1A 06 (USB-D) and Yaesu DATA-USB; reported to clients as PKTUSB
- Stop bits and RTS/CTS hardware flow control options
- `\dump_state` covers 4 m and 23 cm and advertises CW-R, RTTY-R and PKT modes
- Common driver interface (`RigBackend`), drivers `IcomRig`, `TextCatRig`, `YaesuBinaryRig`
- 20 new tests with Kenwood, Yaesu and FT-817 simulators (78 total)
- Rewritten in-app help (PL/EN): radio settings, main window, extended troubleshooting
- Warning when RTS/CTS and RTS PTT are set on the same port
- Project wiki (EN/PL) in `wiki/`, release notes in `docs/releases/`

## 1.3.2
- **Faster response to client commands.** macOS App Nap no longer slows CAT2RIG down when its
  window is in the background (activity assertion + `NSAppSleepDisabled`).
- Client commands (WSJT-X) take priority over background polling of the radio
- TCP_NODELAY on rigctl connections, shorter timeout for the VFO-mode command
- Commands taking ≥ 300 ms are logged ("Slow radio response")
- 1 new test (58 total)
- DMG installer (`build_dmg.sh`), attached to GitHub releases

## 1.3.1
- **Fix: crash while the radio is scanning (SCAN).** Collisions on the CI-V bus produced
  frames without the end byte; two frames were glued together and decoding the frequency
  overflowed. The frame parser now resynchronises on every preamble, rejects invalid BCD
  data and wrong lengths, and limits the receive buffer.
- 4 new tests, including a 300-frame scan flood with collisions (57 total)

## 1.3
- Renamed from Civ2Rig to **CAT2RIG** (settings are migrated automatically)
- **SCAN indicator**: detects rapid frequency changes from the radio (radio scanning or fast knob),
  logs start and end of scanning; client-requested changes are ignored
- 3 new tests (53 total)

## 1.2
- Launch at macOS login (Settings, ⌘,)
- App icon, built-in help (⌘?), English translation, language picker
- Auto-start of the radio connection, waits for the USB interface
- Version shown in the main window

## 1.1
- Switches the radio from memory mode (V/M) to VFO before setting the frequency
- `\get_lock_mode` / `\set_lock_mode` (Hamlib 4.7)
- PTT port opened non-exclusively (WSJT-X may open it too)
- Set commands and unsupported commands always shown in the log
- Control test (set frequency, PTT) without a client
- Accepts VFO arguments (`F VFOA …`), reports `has_set_vfo=1`
- Fixed priority inversion and Sendable warnings
- Core library split out, 50 XCTest tests

## 1.0
- First SwiftUI version: CI-V ↔ rigctld bridge for the Icom IC-706MKIIG
