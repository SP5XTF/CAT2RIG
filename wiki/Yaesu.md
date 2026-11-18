# Yaesu

## Newer radios – text CAT
FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FT-950, FT-450D

| Setting | Default in CAT2RIG |
|---|---|
| Baud rate | 38400 – **set the same CAT rate in the radio menu** |
| Stop bits | 2 (works also when the radio uses 1) |
| RTS/CTS | on |
| PTT | CAT (`TX1;` / `TX0;`) |

- The USB cable gives **two serial ports** (Enhanced and Standard). CAT is on one of them – if the radio doesn't answer, choose the other port.
- **CAT RTS:** if this menu item is *enabled* in the radio, keep **RTS/CTS** ticked. If the radio stays silent, disable CAT RTS in the radio and untick RTS/CTS.
- **DATA mode:** *Data/Pkt* in WSJT-X selects DATA-U (`MD0C;`); the radio then takes audio from USB (check its DATA audio source menu).
- CAT2RIG sends `AI0;` (Auto Information off) on connect.

Expected log with *Show CAT frames*:
```
TX  AI0;
TX  FA;
RX  FA014074000;
TX  MD0;
RX  MD02;
```

## Older radios – binary CAT
FT-817/818, FT-857, FT-897

| Setting | Default |
|---|---|
| Baud rate | 4800 (menu *CAT RATE*) |
| Stop bits | **2** |
| RTS/CTS | off |
| PTT | CAT |

- Frequency resolution is 10 Hz.
- *Data/Pkt* selects DIG mode; configure DIG for USB in the radio's menu.
