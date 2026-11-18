<p align="center">
  <img src="docs/icon.png" width="128" alt="CAT2RIG icon">
</p>

<h1 align="center">CAT2RIG</h1>

<p align="center">
  Native macOS CAT bridge: <b>Icom · Yaesu · Kenwood · Elecraft · Xiegu</b> → <b>Hamlib NET rigctl</b><br>
  Lets WSJT-X, JTDX, fldigi and loggers share one radio — like flrig or rigctld, but small and native.
</p>

<p align="center">
  <a href="README.pl.md">🇵🇱 Wersja polska</a> · <a href="../../wiki">📖 Wiki</a>
</p>

<p align="center">
  <a href="https://github.com/<your-user>/CAT2RIG/actions/workflows/ci.yml"><img src="https://github.com/<your-user>/CAT2RIG/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="../../releases/latest"><img src="https://img.shields.io/github/v/release/<your-user>/CAT2RIG" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT"></a>
</p>

---

![CAT2RIG main window](docs/screenshot.png)

## Features

- **Many radios** – Icom and Xiegu (CI-V), newer Yaesu (text CAT), Yaesu FT-817/857/897 (binary CAT), Kenwood and Elecraft; pick the model and the defaults are filled in
- **rigctld-compatible TCP server** – use *Hamlib NET rigctl* (model 2) in WSJT-X, JTDX, fldigi, loggers; several clients at once
- **PTT** by CAT command, or by RTS/DTR on the CAT port or a separate PTT port
- **DATA mode** (USB-D) on the IC-7300/705/7100/9700/7610 and Yaesu DATA-USB when the client asks for Data/Pkt
- Live frequency updates (Icom CI-V transceive), automatic memory → VFO switch on Icom
- **SCAN indicator**, **control test** (set frequency / key PTT without a client), **log** of client commands and raw CAT frames
- **Auto-start**, **launch at macOS login**, built-in **help**, **English and Polish** UI
- Native SwiftUI app, no Python, no Hamlib installation needed, 78 unit and integration tests

## Supported radios

| Maker | Models | Protocol | CAT PTT |
|---|---|---|---|
| Icom | IC-706MKIIG, IC-718 | CI-V | – (RTS/DTR) |
| Icom | IC-7000, IC-7100, IC-7300, IC-705, IC-9700, IC-7610, other CI-V | CI-V | ✓ |
| Xiegu | G90, X6100, X5105 | CI-V | ✓ |
| Yaesu | FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FT-950, FT-450D | text CAT | ✓ |
| Yaesu | FT-817/818, FT-857, FT-897 | binary CAT (8N2) | ✓ |
| Kenwood | TS-590S/SG, TS-480, TS-2000 | Kenwood CAT | ✓ |
| Elecraft | K3/K3S, KX2/KX3, K4 | Kenwood CAT | ✓ |

Tested on real hardware: IC-706MKIIG. The other drivers are tested against protocol simulators – reports from owners are very welcome (open an issue with the CAT frames log).

## Requirements

- macOS 13 Ventura or newer (Apple Silicon or Intel)
- A supported radio with its CAT/USB cable or interface
- To build from source: Xcode 15+ (or Command Line Tools for building only; tests need full Xcode)

## Installation

### Download

Grab `CAT2RIG-X.Y.dmg` from [Releases](../../releases), open it and drag **CAT2RIG** to **Applications** (a `.zip` is available too).

The app is not notarized by Apple, so the first launch is blocked by Gatekeeper. Either right-click the app → **Open** → **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/CAT2RIG.app
```

### Build from source

```bash
git clone https://github.com/<your-user>/CAT2RIG.git
cd CAT2RIG
bash build_app.sh          # CAT2RIG.app
bash build_dmg.sh          # CAT2RIG-X.Y.dmg
```

### Upgrading from Civ2Rig

CAT2RIG is the new name of Civ2Rig (≤ 1.2). Settings are migrated automatically on first launch. If you used *Launch at login* in Civ2Rig, turn it off there first, delete Civ2Rig.app and enable the option again in CAT2RIG.

## Setup

1. **Model** – choose your radio; baud rate, stop bits, RTS/CTS, CI-V address and PTT are set to defaults.
2. **Radio port** – the CAT port of your interface or USB cable (`/dev/cu.…`). Match the **baud rate** to the radio's menu.
3. **PTT** – *CAT* where supported, *RTS/DTR* if your interface keys the transmitter with a line.
4. **Start** – “Radio connected” and a frequency on the display mean CAT works.

Radio-specific notes:

- **Icom / Xiegu** – CI-V address must match the radio's menu; enable *CI-V Transceive* for instant knob updates.
- **Yaesu FT-991A, FT-891, FT-710, FTDX…** – set *CAT RATE* in the radio menu to the same baud rate. If *CAT RTS* is enabled in the radio, keep **RTS/CTS** ticked; if the radio stays silent, disable CAT RTS and untick RTS/CTS.
- **Yaesu FT-817/857/897** – 2 stop bits, CAT rate from the radio menu (4800 by default).
- **Kenwood / Elecraft** – Auto Information is switched off automatically.

**WSJT-X / JTDX → Settings → Radio:**

| Setting | Value |
|---|---|
| Rig | Hamlib NET rigctl |
| Network Server | `127.0.0.1:4532` (the TCP port from CAT2RIG) |
| PTT Method | CAT |
| Mode | USB, or Data/Pkt for radios with a DATA mode |
| Read and display PWR and SWR | **off** |

Start CAT2RIG first, then WSJT-X. Only CAT2RIG should open the CAT port.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| “Radio not responding” | wrong model, baud rate, CI-V address or port; Yaesu: stop bits and RTS/CTS. Enable *Show CAT frames*: only `TX` → radio silent; no `RX` → wrong port or cable |
| Port busy | flrig or rigctld holds the port – close it |
| WSJT-X: *Connection refused* | CAT2RIG not running, or TCP port differs |
| WSJT-X: *cannot open PTT device* | WSJT-X and CAT2RIG both want the PTT port – set PTT Method = CAT in WSJT-X |
| Slow reaction | look for “Slow radio response” in the log |

Log codes: `RPRT 0` OK · `-1` bad argument · `-5` radio not responding · `-9` rejected by the radio · `-11` unsupported command.

## Supported rigctl commands

`f` `F` `m` `M` `t` `T` `v` `V` `s` `S` `q`, their long forms (`\get_freq`, `\set_freq`, …), `\dump_state` (protocol 1), `\chk_vfo`, `\get_powerstat`, `\get_lock_mode`, `\set_lock_mode`. VFO arguments (`F VFOA 14074000`) and extended-response prefixes are accepted. Tested with Hamlib 4.5 and WSJT-X-improved with Hamlib 4.7.1.

## Project structure

```
Sources/CAT2RIGCore/   serial port, drivers (IcomRig, TextCatRig, YaesuBinaryRig), radio models,
                       rigctl protocol and TCP server
Sources/CAT2RIG/       SwiftUI app: main window, help, settings
Tests/                 XCTest – simulated Icom, Yaesu, Kenwood and FT-817 radios + real TCP clients
Resources/             app icon, translations (pl = base language, en)
build_app.sh           builds and ad-hoc signs CAT2RIG.app
build_dmg.sh           packs it into a DMG
```

Run the tests with `swift test` or ⌘U in Xcode.

## Adding a radio

Most radios only need a new entry in `RadioModel.all` (`Sources/CAT2RIGCore/RadioModels.swift`): protocol family, CI-V address, default baud rate, stop bits and whether CAT PTT works. Pull requests welcome.

## License

[MIT](LICENSE)
SP5XTF
73!
