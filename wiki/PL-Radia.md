# Obsługiwane radia

| Producent | Model | Protokół | CI-V | Prędkość | PTT CAT | DATA | Hamlib nr | Sprawdzone |
|---|---|---|---|---|---|---|---|---|
| Icom | IC-706MKIIG | CI-V | 58 | 19200 | – | – | 3011 | ✓ |
| Icom | IC-718 | CI-V | 5E | 9600 | – | – | 3013 |  |
| Icom | IC-746PRO | CI-V | 66 | 19200 | – | – | 3046 |  |
| Icom | IC-756PROIII | CI-V | 6E | 19200 | – | – | 3057 |  |
| Icom | IC-7000 | CI-V | 70 | 19200 | ✓ | – | 3060 |  |
| Icom | IC-7200 | CI-V | 76 | 19200 | ✓ | – | 3061 |  |
| Icom | IC-7410 | CI-V | 80 | 19200 | ✓ | – | 3067 |  |
| Icom | IC-7600 | CI-V | 7A | 19200 | ✓ | – | 3063 |  |
| Icom | IC-9100 | CI-V | 7C | 19200 | ✓ | – | 3068 |  |
| Icom | IC-7100 | CI-V | 88 | 19200 | ✓ | ✓ | 3070 |  |
| Icom | IC-7300 | CI-V | 94 | 19200 | ✓ | ✓ | 3073 |  |
| Icom | IC-705 | CI-V | A4 | 19200 | ✓ | ✓ | 3085 |  |
| Icom | IC-9700 | CI-V | A2 | 19200 | ✓ | ✓ | 3081 |  |
| Icom | IC-7610 | CI-V | 98 | 19200 | ✓ | ✓ | 3078 |  |
| Xiegu | G90 | CI-V | 88 | 19200 | ✓ | – | 3088 |  |
| Xiegu | X6100 | CI-V | 70 | 19200 | ✓ | – | 3087 |  |
| Xiegu | X5105 | CI-V | 70 | 19200 | ✓ | – | 3089 |  |
| Xiegu | X108G | CI-V | 70 | 19200 | – | – | 3076 |  |
| Yaesu | FT-991/991A | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1035 |  |
| Yaesu | FT-891 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1036 |  |
| Yaesu | FT-710 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1049 |  |
| Yaesu | FTDX10 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1042 |  |
| Yaesu | FTDX101D/MP | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1040 |  |
| Yaesu | FTDX5000 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1032 |  |
| Yaesu | FTDX3000 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1037 |  |
| Yaesu | FTDX1200 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1034 |  |
| Yaesu | FT-2000 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1029 |  |
| Yaesu | FT-950 | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1028 |  |
| Yaesu | FT-450/450D | Yaesu CAT tekstowy |  | 38400 | ✓ | ✓ | 1046 |  |
| Yaesu | FT-817/818 | Yaesu CAT binarny |  | 4800 | ✓ | – | 1020 |  |
| Yaesu | FT-857/857D | Yaesu CAT binarny |  | 4800 | ✓ | – | 1022 |  |
| Yaesu | FT-897/897D | Yaesu CAT binarny |  | 4800 | ✓ | – | 1023 |  |
| Kenwood | TS-590S/SG | Kenwood CAT |  | 115200 | ✓ | – | 2031 |  |
| Kenwood | TS-480 | Kenwood CAT |  | 57600 | ✓ | – | 2028 |  |
| Kenwood | TS-2000 | Kenwood CAT |  | 57600 | ✓ | – | 2014 |  |
| Elecraft | K2 | Kenwood CAT |  | 4800 | ✓ | – | 2021 |  |
| Elecraft | K3/K3S | Kenwood CAT |  | 38400 | ✓ | – | 2029 |  |
| Elecraft | KX2/KX3 | Kenwood CAT |  | 38400 | ✓ | – | 2045 |  |
| Elecraft | K4 | Kenwood CAT |  | 38400 | ✓ | – | 2047 |  |
| QRP Labs | QDX/QCX/QMX | Kenwood CAT |  | 9600 | ✓ | – | 2052 |  |
| DL2MAN | (tr)uSDX | Kenwood CAT |  | 38400 | ✓ | – | 2055 |  |

**Sprawdzone** = przetestowane na prawdziwym radiu; pozostałe na symulatorach protokołów – [daj znać](PL-Problemy#zgłaszanie-problemu), czy twoje działa. Adresy CI-V i prędkości to wartości fabryczne. *Hamlib nr* = numer modelu w `rigctl -l`.

*Tabela jest generowana z kodu: `python3 scripts/radio_table.py pl`.*

# Uwagi do poszczególnych rodzin

## Icom i Xiegu (CI-V)
| Model | Adres CI-V | Prędkość | PTT CAT | DATA |
|---|---|---|---|---|
| IC-706MKIIG, IC-718, IC-746PRO, IC-756PROIII | 58, 5E, 66, 6E | 19200/9600 | – (RTS/DTR) | – |
| IC-7200 / 7410 / 7600 / 9100 | 76 / 80 / 7A / 7C | 19200 | ✓ | – |
| IC-7000 | 70 | 19200 | ✓ | – |
| IC-7100 / 7300 / 705 / 9700 / 7610 | 88 / 94 / A4 / A2 / 98 | 19200 | ✓ | ✓ USB-D |
| Xiegu G90 | 88 | 19200 | ✓ | – |
| Xiegu X6100 / X5105 | 70 | 19200 | ✓ | – |
| Xiegu X108G | 70 | 19200 | – | – |

To wartości fabryczne – **sprawdź menu radia**. Włącz **CI-V Transceive**, żeby zmiany z gałki były widoczne od razu. CAT2RIG sam przełącza radio z pamięci (V/M) na VFO przed zmianą częstotliwości.

## Yaesu – nowszy CAT (FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FTDX5000, FTDX3000, FTDX1200, FT-2000, FT-950, FT-450)
- Prędkość domyślnie 38400 – **ustaw tę samą w menu CAT radia**. Bity stopu 2, RTS/CTS włączone, PTT CAT.
- Kabel USB daje **dwa porty**; CAT jest na jednym z nich – gdy radio milczy, wybierz drugi.
- **CAT RTS** włączone w radiu → zostaw **RTS/CTS**; gdy radio milczy, wyłącz CAT RTS i odznacz RTS/CTS.
- *Data/Pkt* w WSJT-X włącza DATA-U; sprawdź w menu źródło audio dla DATA.

## Yaesu – CAT binarny (FT-817/818, FT-857, FT-897)
Prędkość 4800 (menu CAT RATE), **2 bity stopu**, PTT CAT. Rozdzielczość 10 Hz. *Data/Pkt* = tryb DIG.

## Kenwood, Elecraft, QRP Labs, (tr)uSDX
TS-590S/SG 115200, TS-480 i TS-2000 57600, Elecraft K2 4800, K3/KX2/KX3/K4 38400, QRP Labs QDX/QCX/QMX 9600, (tr)uSDX 38400 – ustaw tak samo w radiu. PTT CAT. Brak trybu DATA – w WSJT-X ustaw **Mode: USB**.
