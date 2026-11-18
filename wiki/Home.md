# CAT2RIG

**CAT2RIG** is a native macOS app that connects to your transceiver over CAT and shares it with WSJT-X, JTDX, fldigi and loggers as a **Hamlib NET rigctl** server – like flrig or rigctld, but small and native.

🇵🇱 [Wersja polska](PL-Strona-glowna)

## Start here
1. [Installation](Installation)
2. [Configuration](Configuration) – model, port, PTT
3. [WSJT-X and other programs](WSJT-X-Setup)
4. Notes for your radio: [Icom and Xiegu](Icom-and-Xiegu) · [Yaesu](Yaesu) · [Kenwood and Elecraft](Kenwood-and-Elecraft)
5. Something wrong? [Troubleshooting](Troubleshooting) · [FAQ](FAQ)

## Supported radios

| Maker | Models | Protocol | CAT PTT | DATA mode |
|---|---|---|---|---|
| Icom | IC-706MKIIG, IC-718 | CI-V | – | – |
| Icom | IC-7000 | CI-V | ✓ | – |
| Icom | IC-7100, IC-7300, IC-705, IC-9700, IC-7610 | CI-V | ✓ | ✓ USB-D |
| Icom | other CI-V models | CI-V | ✓ | – |
| Xiegu | G90, X6100, X5105 | CI-V | ✓ | – |
| Yaesu | FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FT-950, FT-450D | text CAT | ✓ | ✓ DATA-U |
| Yaesu | FT-817/818, FT-857, FT-897 | binary CAT | ✓ | (DIG) |
| Kenwood | TS-590S/SG, TS-480, TS-2000 | Kenwood CAT | ✓ | – |
| Elecraft | K3/K3S, KX2/KX3, K4 | Kenwood CAT | ✓ | – |

Verified on real hardware: IC-706MKIIG. Other drivers are tested with protocol simulators – reports are welcome (see [Troubleshooting → Reporting a problem](Troubleshooting#reporting-a-problem)).

## For developers
[Building from source](Building-from-Source) · [Developer guide](Developer-Guide) – architecture, adding a radio, tests, releases.
