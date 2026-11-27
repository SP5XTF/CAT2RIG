# Rozwiązywanie problemów

Najpierw zaznacz w CAT2RIG **Pokaż ramki CAT** – log pokaże wtedy wszystko, co idzie do radia (`TX`) i z radia (`RX`). Przy sterowniku **Hamlib** szczegóły trafiają do pliku `~/Library/Logs/CAT2RIG/hamlib.log`.

| Objaw | Co sprawdzić |
|---|---|
| „Radio nie odpowiada”, w logu tylko `TX` | prędkość, adres CI-V, ustawienia CAT w menu radia; Yaesu: RTS/CTS i CAT RTS |
| Brak jakiegokolwiek `RX` | zły port (spróbuj drugiego portu interfejsu), kabel, sterownik USB |
| Po restarcie port ma inną nazwę | CAT2RIG (od 1.7.1) rozpoznaje interfejs po numerze seryjnym USB; po aktualizacji uruchom raz ręcznie z właściwym portem |
| Port zajęty | flrig, rigctld albo WSJT-X z ustawionym portem – zamknij |
| WSJT-X: *Connection refused* | CAT2RIG nie działa albo inny port TCP |
| WSJT-X: *cannot open PTT device* | w WSJT-X **PTT Method: CAT** |
| Radio nie zmienia pasma | LOCK w radiu; w logu `RPRT -9` |
| WSJT-X ciągle zmienia emisję | radio bez trybu DATA – w WSJT-X **Mode: USB** |
| Wolna reakcja | wpisy „Wolna odpowiedź radia” w logu |
| Lampka TX świeci, radio nie nadaje | RTS ↔ DTR, zły port PTT albo użyj PTT CAT |
| Radia nie ma na liście modeli | ustaw **Sterownik: Hamlib** i wybierz je z menu Hamlib ([Sterownik Hamlib](PL-Hamlib)) |
| Wbudowany sterownik działa źle | spróbuj tego samego radia ze **Sterownik: Hamlib** i zgłoś różnicę |
| *Hamlib niedostępny* | aplikacja zbudowana bez Hamlib – pobierz DMG z Releases albo uruchom `bash scripts/build_hamlib.sh` |
| Wskaźnik S / PO pokazuje „—” | radio (lub sterownik) nie podaje wartości – np. IC-706MKIIG nie ma miernika mocy, mierniki Kenwood/Elecraft tylko przez Hamlib |

Kody: `RPRT 0` OK · `-1` zły argument · `-5` radio nie odpowiada · `-9` radio odrzuciło komendę · `-11` komenda nieobsługiwana

## Zgłaszanie problemu
[Zgłoś issue](https://github.com/SP5XTF/CAT2RIG/issues/new/choose): wersja CAT2RIG (dół okna), wersja macOS, model radia, interfejs, prędkość, ustawienia PTT w CAT2RIG i w kliencie oraz log z zaznaczonym *Pokaż ramki CAT* (przy sterowniku Hamlib także plik `~/Library/Logs/CAT2RIG/hamlib.log`).
