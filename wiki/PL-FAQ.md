# FAQ

**Po co, skoro jest rigctld albo flrig?** Można ich używać. CAT2RIG to mała natywna aplikacja z oknem, autostartem, wskaźnikiem SCAN i logiem pod emisje cyfrowe.

**Czy kilka programów może naraz używać radia?** Tak – każdy łączy się z CAT2RIG przez TCP.

**Czy trzeba instalować Hamlib?** Nie – jest w zestawie. Sterowniki wbudowane w ogóle go nie używają; korzysta z niego sterownik *Hamlib*.

**Czy odczytuje S-metr, moc, SWR?** S-metr i moc – tak, od wersji 1.7.0 (gdy radio je podaje). SWR – jeszcze nie, więc w WSJT-X zostaw odznaczone *Read and display PWR and SWR*.

**Czy mogę wypróbować bez radia?** Tak – wybierz *Sterownik: Hamlib*, model *Hamlib → Dummy*, kliknij Start (port niepotrzebny) i połącz WSJT-X.

**Czy aplikacja jest podpisana przez Apple?** Podpisana lokalnie (ad-hoc), bez notaryzacji – przy pierwszym uruchomieniu prawy przycisk → Otwórz.

**Gdzie są ustawienia?** `~/Library/Preferences/pl.hamradio.cat2rig.plist`.

**Mojego radia nie ma na liście.** Wiele radiów używa jednego z obsługiwanych protokołów. Spróbuj *Icom (inny model CI-V)* albo modelu z tej samej rodziny i [daj znać](PL-Problemy#zgłaszanie-problemu), jak poszło.
