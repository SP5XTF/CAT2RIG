# Sterownik Hamlib

Od wersji 1.6.0 CAT2RIG zawiera bibliotekę [Hamlib](https://github.com/Hamlib/Hamlib) (4.7.2). Nic nie trzeba instalować.

## Kiedy go używać
- **Twojego radia nie ma na liście wbudowanych** – Hamlib obsługuje ponad 300 modeli.
- **Wbudowany sterownik działa źle** – przełącz to samo radio na Hamlib i porównaj (zgłoś różnicę).
- **Test bez radia** – model *Hamlib Dummy* symuluje transceiver; port nie jest potrzebny.

Dla radiów z listy wbudowanej zalecany zostaje sterownik **Wbudowany**: jest szybszy, przetestowany w CAT2RIG i obsługuje szczegóły, takie jak kolizje CI-V przy skanowaniu czy przełączanie pamięć→VFO.

## Jak używać
1. **Sterownik:** *Hamlib 4.7.2*.
2. **Model:** otwórz menu, wybierz producenta i radio. Numer po nazwie to numer modelu Hamlib (`rigctl -l`); status w nawiasie, np. *(Beta)*, pochodzi z Hamlib.
3. **Port, prędkość, bity stopu, RTS/CTS, adres CI-V** (Icom/Xiegu) – jak przy sterownikach wbudowanych.
4. **PTT:** *CAT* (PTT przez Hamlib), *RTS*/*DTR* (linia kluczowana przez Hamlib, także na osobnym porcie PTT) albo *brak / VOX*.
5. **Start.**

Po przełączeniu na Hamlib przy modelu z listy wbudowanej w Hamlib od razu wybiera się to samo radio.

## Log
Hamlib zapisuje komunikaty w pliku `~/Library/Logs/CAT2RIG/hamlib.log` – błędy zawsze, pełny ślad komunikacji przy zaznaczonym **Pokaż ramki CAT**. Dołącz ten plik do zgłoszenia błędu (otworzysz go w aplikacji Konsola albo dowolnym edytorze).

## Licencja
Hamlib jest na licencji **LGPL 2.1** i jest dołączony jako osobna biblioteka `CAT2RIG.app/Contents/Frameworks/libhamlib.4.dylib`, którą można podmienić na własną kompilację Hamlib 4.x. Tekst licencji i informacja o źródłach: `Contents/Resources/Hamlib/` oraz [THIRD_PARTY_NOTICES.md](https://github.com/SP5XTF/CAT2RIG/blob/main/THIRD_PARTY_NOTICES.md). Gdy biblioteki brak, CAT2RIG działa dalej na sterownikach wbudowanych.
