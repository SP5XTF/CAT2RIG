<p align="center">
  <img src="docs/icon.png" width="128" alt="Ikona CAT2RIG">
</p>

<h1 align="center">CAT2RIG</h1>

<p align="center">
  Natywny most CAT dla macOS: <b>Icom · Yaesu · Kenwood · Elecraft · Xiegu · QRP Labs</b> → <b>Hamlib NET rigctl</b><br>
  WSJT-X, JTDX, fldigi i loggery sterują jednym radiem jednocześnie – jak przez flrig albo rigctld, tylko lżej.
</p>

<p align="center">
  <a href="README.md">🇬🇧 English version</a> · <a href="https://github.com/SP5XTF/CAT2RIG/wiki/PL-Strona-glowna">📖 Wiki</a>
</p>

<p align="center">
  <a href="https://github.com/SP5XTF/CAT2RIG/actions/workflows/ci.yml"><img src="https://github.com/SP5XTF/CAT2RIG/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/SP5XTF/CAT2RIG/releases/latest"><img src="https://img.shields.io/github/v/release/SP5XTF/CAT2RIG" alt="Wydanie"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licencja-MIT-green" alt="MIT"></a>
</p>

---

![Okno główne CAT2RIG](docs/screenshot.png)

## Możliwości

- **41 modeli radiów** – Icom i Xiegu (CI-V), Yaesu (CAT tekstowy i binarny), Kenwood, Elecraft, QRP Labs i (tr)uSDX; wybierasz model, a ustawienia domyślne wypełniają się same
- **Serwer TCP zgodny z rigctld** – w WSJT-X, JTDX, fldigi i loggerach wybierasz *Hamlib NET rigctl* (model 2); wielu klientów naraz
- **PTT** komendą CAT albo linią RTS/DTR na porcie CAT lub osobnym porcie PTT
- **Tryb DATA** (USB-D) w IC-7300/705/7100/9700/7610 oraz DATA-USB w Yaesu, gdy klient wybierze Data/Pkt
- Zmiany częstotliwości na bieżąco (CI-V transceive), automatyczne przełączanie pamięć → VFO w Icomach
- **S-metr i miernik mocy** – S1…S9+60 podczas odbioru, moc podczas nadawania (Icom, Xiegu, Yaesu, rodzina FT-817, Hamlib); dostępne też dla klientów jako `l STRENGTH` / `l RFPOWER_METER`
- **Wskaźnik SCAN**, **test sterowania** (częstotliwość i PTT bez programu klienckiego), **log** komend klientów i surowych ramek CAT
- **Hamlib w zestawie** – przełącz *Sterownik* na Hamlib, żeby użyć dowolnego z ponad 300 radiów, bez instalowania czegokolwiek (domyślne zostają sterowniki wbudowane)
- **Autostart**, **uruchamianie przy logowaniu do macOS**, wbudowana **pomoc**, interfejs **po polsku i po angielsku**
- Natywna aplikacja SwiftUI – bez Pythona i Hamlib w zestawie; 105 testów jednostkowych i integracyjnych

## Obsługiwane radia

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

**Sprawdzone** = przetestowane na prawdziwym radiu; pozostałe przetestowano na symulatorach protokołów. Adresy CI-V i prędkości to wartości fabryczne – sprawdź menu radia. *Hamlib nr* to numer modelu w `rigctl -l`. Zgłoszenia od właścicieli są bardzo mile widziane – [zgłoś issue](https://github.com/SP5XTF/CAT2RIG/issues/new/choose) z logiem ramek CAT.

### Inne radia przez Hamlib

Ustaw **Sterownik: Hamlib** i wybierz dowolny model z menu (pogrupowanego według producentów, z numerem modelu Hamlib). Model *Hamlib Dummy* to symulator do testów WSJT-X bez radia.

## Wymagania

- macOS 13 Ventura lub nowszy (Apple Silicon albo Intel)
- Obsługiwane radio z kablem/interfejsem CAT lub USB
- Do budowania ze źródeł: Xcode 15+ (do samego budowania wystarczą Command Line Tools; testy wymagają pełnego Xcode)

## Instalacja

### Pobranie gotowej aplikacji

Pobierz `CAT2RIG-X.Y.dmg` z zakładki [Releases](https://github.com/SP5XTF/CAT2RIG/releases), otwórz go i przeciągnij **CAT2RIG** do **Programów** (dostępny jest też `.zip`).

Aplikacja nie jest notaryzowana przez Apple, więc przy pierwszym uruchomieniu zablokuje ją Gatekeeper. Kliknij aplikację prawym przyciskiem → **Otwórz** → **Otwórz** albo wykonaj:

```bash
xattr -dr com.apple.quarantine /Applications/CAT2RIG.app
```

### Budowanie ze źródeł

```bash
git clone https://github.com/SP5XTF/CAT2RIG.git
cd CAT2RIG
bash build_app.sh          # CAT2RIG.app (pierwszy raz buduje też Hamlib – kilka minut)
bash build_dmg.sh          # CAT2RIG-X.Y.dmg
```

### Aktualizacja z Civ2Rig

CAT2RIG to nowa nazwa programu Civ2Rig (≤ 1.2). Ustawienia przenoszą się same przy pierwszym uruchomieniu. Jeśli w Civ2Rig było włączone *Uruchamiaj przy logowaniu*, najpierw wyłącz to w starej aplikacji, usuń Civ2Rig.app i włącz opcję ponownie w CAT2RIG.

## Konfiguracja

1. **Model** – wybierz radio; prędkość, bity stopu, RTS/CTS, adres CI-V i PTT ustawią się na wartości domyślne.
2. **Port radia** – port CAT interfejsu lub kabla USB (`/dev/cu.…`). **Prędkość** ustaw taką jak w menu radia.
3. **PTT** – *CAT*, jeśli radio to obsługuje; *RTS/DTR*, gdy interfejs kluczuje nadajnik linią.
4. **Start** – „Radio połączone” i częstotliwość na wyświetlaczu oznaczają, że CAT działa.

Uwagi dla poszczególnych radiów:

- **Icom / Xiegu** – adres CI-V musi być taki jak w menu radia; włącz *CI-V Transceive*, żeby zmiany z gałki były widoczne od razu.
- **Yaesu FT-991A, FT-891, FT-710, FTDX…** – w menu radia ustaw *CAT RATE* na tę samą prędkość. Jeśli w radiu jest włączone *CAT RTS*, zostaw zaznaczone **RTS/CTS**; gdy radio nie odpowiada, wyłącz CAT RTS i odznacz RTS/CTS.
- **Yaesu FT-817/857/897** – 2 bity stopu, prędkość CAT z menu radia (domyślnie 4800).
- **Kenwood / Elecraft** – Auto Information jest wyłączane automatycznie.

**WSJT-X / JTDX → Settings → Radio:**

| Ustawienie | Wartość |
|---|---|
| Rig | Hamlib NET rigctl |
| Network Server | `127.0.0.1:4532` (port TCP z CAT2RIG) |
| PTT Method | CAT |
| Mode | USB albo Data/Pkt (radia z trybem DATA) |
| Read and display PWR and SWR | **wyłączone** |

Najpierw uruchamiaj CAT2RIG, potem WSJT-X. Port CAT otwiera tylko CAT2RIG.

## Rozwiązywanie problemów

| Objaw | Przyczyna / rozwiązanie |
|---|---|
| „Radio nie odpowiada” | zły model, prędkość, adres CI-V albo port; Yaesu: bity stopu i RTS/CTS. Włącz *Pokaż ramki CAT*: tylko `TX` → radio milczy; brak `RX` → zły port lub kabel |
| Port zajęty | port trzyma flrig albo rigctld – zamknij go |
| WSJT-X: *Connection refused* | CAT2RIG nie działa albo port TCP się różni |
| WSJT-X: *cannot open PTT device* | WSJT-X i CAT2RIG chcą tego samego portu PTT – w WSJT-X ustaw PTT Method = CAT |
| Wolna reakcja | szukaj w logu wpisów „Wolna odpowiedź radia” |

Kody w logu: `RPRT 0` OK · `-1` zły argument · `-5` radio nie odpowiada · `-9` radio odrzuciło komendę · `-11` komenda nieobsługiwana.

## Obsługiwane komendy rigctl

`f` `F` `m` `M` `t` `T` `v` `V` `s` `S` `q`, ich długie formy (`\get_freq`, `\set_freq`, …), `\dump_state` (protokół 1), `\chk_vfo`, `\get_powerstat`, `\get_lock_mode`, `\set_lock_mode`, `l STRENGTH`, `l RFPOWER_METER`. Akceptowane są argumenty VFO (`F VFOA 14074000`) i prefiksy trybu rozszerzonego. Sprawdzone z Hamlib 4.5 oraz WSJT-X-improved z Hamlib 4.7.1.

## Struktura projektu

```
Sources/CAT2RIGCore/   port szeregowy, sterowniki (IcomRig, TextCatRig, YaesuBinaryRig), modele radiów,
                       HamlibRig, protokół i serwer rigctl
Sources/CAT2RIG/       aplikacja SwiftUI: okno główne, pomoc, ustawienia
Tests/                 XCTest – symulowane radia Icom, Yaesu, Kenwood i FT-817 + prawdziwi klienci TCP
Resources/             ikona, tłumaczenia (pl = język bazowy, en)
build_app.sh           buduje i podpisuje (ad-hoc) CAT2RIG.app
build_dmg.sh           pakuje ją do obrazu DMG
scripts/build_hamlib.sh  buduje dołączaną bibliotekę Hamlib (universal)
```

Testy: `swift test` albo ⌘U w Xcode.

## Dodawanie radia

Zwykle wystarczy nowy wpis w `RadioModel.all` (`Sources/CAT2RIGCore/RadioModels.swift`): rodzina protokołu, adres CI-V, domyślna prędkość, bity stopu i to, czy działa PTT przez CAT. Pull requesty mile widziane.

## Licencja

[MIT](LICENSE). Wydania zawierają bibliotekę [Hamlib](https://github.com/Hamlib/Hamlib) (LGPL 2.1) jako osobny, wymienialny plik – zob. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

73 de SP5XTF!
