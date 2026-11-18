# Obsługiwane radia – uwagi

## Icom i Xiegu (CI-V)
| Model | Adres CI-V | Prędkość | PTT CAT | DATA |
|---|---|---|---|---|
| IC-706MKIIG | 58 | 19200 | – (RTS/DTR) | – |
| IC-718 | 5E | 9600 | – | – |
| IC-7000 | 70 | 19200 | ✓ | – |
| IC-7100 / 7300 / 705 / 9700 / 7610 | 88 / 94 / A4 / A2 / 98 | 19200 | ✓ | ✓ USB-D |
| Xiegu G90 | 88 | 19200 | ✓ | – |
| Xiegu X6100 / X5105 | 70 | 19200 | ✓ | – |

To wartości fabryczne – **sprawdź menu radia**. Włącz **CI-V Transceive**, żeby zmiany z gałki były widoczne od razu. CAT2RIG sam przełącza radio z pamięci (V/M) na VFO przed zmianą częstotliwości.

## Yaesu – nowszy CAT (FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FT-950, FT-450D)
- Prędkość domyślnie 38400 – **ustaw tę samą w menu CAT radia**. Bity stopu 2, RTS/CTS włączone, PTT CAT.
- Kabel USB daje **dwa porty**; CAT jest na jednym z nich – gdy radio milczy, wybierz drugi.
- **CAT RTS** włączone w radiu → zostaw **RTS/CTS**; gdy radio milczy, wyłącz CAT RTS i odznacz RTS/CTS.
- *Data/Pkt* w WSJT-X włącza DATA-U; sprawdź w menu źródło audio dla DATA.

## Yaesu – CAT binarny (FT-817/818, FT-857, FT-897)
Prędkość 4800 (menu CAT RATE), **2 bity stopu**, PTT CAT. Rozdzielczość 10 Hz. *Data/Pkt* = tryb DIG.

## Kenwood i Elecraft
TS-590S/SG 115200, TS-480 i TS-2000 57600, Elecraft K3/KX2/KX3/K4 38400 – ustaw tak samo w radiu. PTT CAT. Brak trybu DATA – w WSJT-X ustaw **Mode: USB**.
