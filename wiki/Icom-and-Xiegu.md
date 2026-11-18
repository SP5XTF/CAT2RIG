# Icom and Xiegu (CI-V)

| Model | Default CI-V address | Default baud | CAT PTT | DATA mode |
|---|---|---|---|---|
| IC-706MKIIG | 58 | 19200 | – (RTS/DTR) | – |
| IC-718 | 5E | 9600 | – | – |
| IC-7000 | 70 | 19200 | ✓ | – |
| IC-7100 | 88 | 19200 | ✓ | ✓ |
| IC-7300 | 94 | 19200 | ✓ | ✓ |
| IC-705 | A4 | 19200 | ✓ | ✓ |
| IC-9700 | A2 | 19200 | ✓ | ✓ |
| IC-7610 | 98 | 19200 | ✓ | ✓ |
| Xiegu G90 | 88 | 19200 | ✓ | – |
| Xiegu X6100 / X5105 | 70 | 19200 | ✓ | – |

Addresses and baud rates are factory defaults – **check your radio's menu**. Pick *Icom (other CI-V model)* for anything not listed and type its address.

## Radio menu
- **CI-V Address** – same as in CAT2RIG.
- **CI-V Baud Rate** – same as in CAT2RIG (USB-connected radios often accept any rate on the USB port).
- **CI-V Transceive: ON** – frequency changes from the knob appear instantly (otherwise within 0.5 s).
- IC-7300/705 and others with USB: the CI-V USB port is the one to choose.

## Notes
- Memory mode: when a client sets a frequency, CAT2RIG switches the radio from memory (V/M) to VFO first.
- DATA mode: *Data/Pkt* in WSJT-X selects USB-D (CI-V 1A 06); plain USB turns it off.
- IC-706MKIIG: no CI-V PTT. Use an interface that keys with RTS or DTR, or VOX.
- CI-V is a shared bus; collisions while the radio scans are handled (damaged frames are dropped).
