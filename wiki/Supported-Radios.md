# Supported radios

| Maker | Model | Protocol | CI-V | Baud | CAT PTT | DATA | Hamlib # | Verified |
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
| Yaesu | FT-991/991A | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1035 |  |
| Yaesu | FT-891 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1036 |  |
| Yaesu | FT-710 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1049 |  |
| Yaesu | FTDX10 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1042 |  |
| Yaesu | FTDX101D/MP | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1040 |  |
| Yaesu | FTDX5000 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1032 |  |
| Yaesu | FTDX3000 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1037 |  |
| Yaesu | FTDX1200 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1034 |  |
| Yaesu | FT-2000 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1029 |  |
| Yaesu | FT-950 | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1028 |  |
| Yaesu | FT-450/450D | Yaesu text CAT |  | 38400 | ✓ | ✓ | 1046 |  |
| Yaesu | FT-817/818 | Yaesu binary CAT |  | 4800 | ✓ | – | 1020 |  |
| Yaesu | FT-857/857D | Yaesu binary CAT |  | 4800 | ✓ | – | 1022 |  |
| Yaesu | FT-897/897D | Yaesu binary CAT |  | 4800 | ✓ | – | 1023 |  |
| Kenwood | TS-590S/SG | Kenwood CAT |  | 115200 | ✓ | – | 2031 |  |
| Kenwood | TS-480 | Kenwood CAT |  | 57600 | ✓ | – | 2028 |  |
| Kenwood | TS-2000 | Kenwood CAT |  | 57600 | ✓ | – | 2014 |  |
| Elecraft | K2 | Kenwood CAT |  | 4800 | ✓ | – | 2021 |  |
| Elecraft | K3/K3S | Kenwood CAT |  | 38400 | ✓ | – | 2029 |  |
| Elecraft | KX2/KX3 | Kenwood CAT |  | 38400 | ✓ | – | 2045 |  |
| Elecraft | K4 | Kenwood CAT |  | 38400 | ✓ | – | 2047 |  |
| QRP Labs | QDX/QCX/QMX | Kenwood CAT |  | 9600 | ✓ | – | 2052 |  |
| DL2MAN | (tr)uSDX | Kenwood CAT |  | 38400 | ✓ | – | 2055 |  |

- **Verified** – tested on a real radio. The others were tested with protocol simulators – please [report](Troubleshooting#reporting-a-problem) whether yours works.
- **CI-V / Baud** – factory defaults filled in when you pick the model; check your radio's menu.
- **DATA** – WSJT-X *Data/Pkt* selects the radio's data mode (USB-D on Icom, DATA-U on Yaesu, DIG on FT-817). Without it use *Mode: USB*.
- **Hamlib #** – the same radio's number in Hamlib (`rigctl -l`), useful when comparing with other programs.
- Not on the list? Try *Icom (other CI-V model)* or a model from the same protocol family.

Per-family notes: [Icom and Xiegu](Icom-and-Xiegu) · [Yaesu](Yaesu) · [Kenwood and Elecraft](Kenwood-and-Elecraft)

*The table is generated from the code: `python3 scripts/radio_table.py en`.*
