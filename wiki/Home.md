# CAT2RIG

**CAT2RIG** is a native macOS app that connects to your transceiver over CAT and shares it with WSJT-X, JTDX, fldigi and loggers as a **Hamlib NET rigctl** server – like flrig or rigctld, but small and native.

🇵🇱 [Wersja polska](PL-Strona-glowna)

## What's new in 1.7.0
- **Hamlib built in** – switch *Driver* to Hamlib for any of 300+ radios, nothing to install → [Hamlib driver](Hamlib-Driver)
- **S-meter and power meter** in the main window → [Configuration](Configuration#window)

All versions: [Changelog](Changelog) · Downloads: [Releases](https://github.com/SP5XTF/CAT2RIG/releases)

## Start here
1. [Installation](Installation)
2. [Configuration](Configuration) – model, port, PTT
3. [WSJT-X and other programs](WSJT-X-Setup)
4. Notes for your radio: [Icom and Xiegu](Icom-and-Xiegu) · [Yaesu](Yaesu) · [Kenwood and Elecraft](Kenwood-and-Elecraft)
5. Something wrong? [Troubleshooting](Troubleshooting) · [FAQ](FAQ)

## Supported radios
**41 models**: Icom (IC-706MKIIG … IC-7610, IC-9700), Xiegu (G90, X6100, X5105, X108G), Yaesu (FT-991A, FT-891, FT-710, FTDX series, FT-817/857/897 …), Kenwood (TS-590, TS-480, TS-2000), Elecraft (K2, K3, KX2/KX3, K4), QRP Labs (QDX/QCX/QMX) and (tr)uSDX.

**Any other radio:** 300+ more models through the built-in [Hamlib driver](Hamlib-Driver) – nothing to install.

➡ **[Full table with CI-V addresses, baud rates, CAT PTT, DATA mode and Hamlib numbers](Supported-Radios)**

## For developers
[Building from source](Building-from-Source) · [Developer guide](Developer-Guide) – architecture, adding a radio, tests, releases.
