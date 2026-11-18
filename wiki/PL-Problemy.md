# Rozwiązywanie problemów

Najpierw zaznacz w CAT2RIG **Pokaż ramki CAT** – log pokaże wtedy wszystko, co idzie do radia (`TX`) i z radia (`RX`).

| Objaw | Co sprawdzić |
|---|---|
| „Radio nie odpowiada”, w logu tylko `TX` | prędkość, adres CI-V, ustawienia CAT w menu radia; Yaesu: RTS/CTS i CAT RTS |
| Brak jakiegokolwiek `RX` | zły port (spróbuj drugiego portu interfejsu), kabel, sterownik USB |
| Port zajęty | flrig, rigctld albo WSJT-X z ustawionym portem – zamknij |
| WSJT-X: *Connection refused* | CAT2RIG nie działa albo inny port TCP |
| WSJT-X: *cannot open PTT device* | w WSJT-X **PTT Method: CAT** |
| Radio nie zmienia pasma | LOCK w radiu; w logu `RPRT -9` |
| WSJT-X ciągle zmienia emisję | radio bez trybu DATA – w WSJT-X **Mode: USB** |
| Wolna reakcja | wpisy „Wolna odpowiedź radia” w logu |
| Lampka TX świeci, radio nie nadaje | RTS ↔ DTR, zły port PTT albo użyj PTT CAT |

Kody: `RPRT 0` OK · `-1` zły argument · `-5` radio nie odpowiada · `-9` radio odrzuciło komendę · `-11` komenda nieobsługiwana

## Zgłaszanie problemu
[Zgłoś issue](https://github.com/<your-user>/CAT2RIG/issues/new/choose): wersja CAT2RIG (dół okna), wersja macOS, model radia, interfejs, prędkość, ustawienia PTT w CAT2RIG i w kliencie oraz log z zaznaczonym *Pokaż ramki CAT*.
