# Kenwood and Elecraft

Both use the Kenwood text CAT protocol (`FA00014074000;`, `MD2;`).

| Model | Default baud |
|---|---|
| Kenwood TS-590S/SG | 115200 |
| Kenwood TS-480 | 57600 |
| Kenwood TS-2000 | 57600 |
| Elecraft K3/K3S, KX2/KX3, K4 | 38400 |

Set the same rate in the radio's menu. Stop bits 1, no RTS/CTS.

- PTT: CAT (`TX;` / `RX;`).
- CAT2RIG switches Auto Information off (`AI0;`).
- No DATA mode via CAT2RIG: set **Mode: USB** in WSJT-X and choose the data audio source in the radio menu.
