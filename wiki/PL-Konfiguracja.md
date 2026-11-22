# Konfiguracja

## Radio
| Pole | Znaczenie |
|---|---|
| **Model** | twoje radio; wybór ustawia prędkość, bity stopu, RTS/CTS, adres CI-V i PTT |
| **Adres CI-V** | tylko Icom/Xiegu, szesnastkowo (np. `94`); taki jak w menu radia |
| **Port radia** | port CAT (`/dev/cu.…`); po podłączeniu kabla kliknij **Odśwież** |
| **Prędkość** | taka jak prędkość CAT/CI-V w radiu |
| **Bity stopu** | 1 albo 2 (starsze Yaesu wymagają 2; 2 działa z większością radiów) |
| **RTS/CTS** | sprzętowa kontrola przepływu – dla Yaesu z włączonym *CAT RTS* |
| **PTT** | *CAT*, *RTS*, *DTR* albo *brak / VOX* |
| **Port PTT** | dla RTS/DTR: port, którego linia kluczuje nadajnik (domyślnie *ten sam co radio*) |

## PTT
- **CAT** – nadawanie komendą CAT; dostępne we wszystkich radiach poza IC-706MKIIG i IC-718.
- **RTS / DTR** – linią interfejsu; port PTT jest otwierany bez wyłączności.
- **brak / VOX** – CAT2RIG nie dotyka PTT.

RTS/CTS i PTT linią RTS na tym samym porcie się wykluczają – CAT2RIG wtedy nie wystartuje.

## Serwer rigctl
- **Port TCP** – 4532 to standardowy port rigctld; zmień, jeśli działa też flrig/rigctld.
- **Dostęp z sieci lokalnej** – programy z innych komputerów mogą się łączyć (macOS zapyta o zgodę).

## Okno
- **Wyświetlacz** z częstotliwością i emisją, lampka **TX**, wskaźnik **SCAN** (szybkie zmiany częstotliwości).
- **Wskaźnik S / PO** – S-metr podczas odbioru, moc (%) podczas nadawania, gdy radio je podaje (Icom/Xiegu, nowsze Yaesu, FT-817/857/897, Hamlib). „—” = brak odczytu. Wartości przybliżone.
- **Test sterowania** – częstotliwość i PTT bez programu klienckiego (PTT naprawdę nadaje!).
- **Log** – komendy ustawiające, nieobsługiwane i wolne odpowiedzi; **Pokaż ramki CAT** dodaje surowy ruch.
- **Start automatycznie** – łączenie po uruchomieniu; czeka na interfejs USB (próba co 5 s).

## Ustawienia (⌘,)
- **Uruchamiaj przy logowaniu do macOS** – najpierw przenieś aplikację do Programów.
- **Język programu** – Systemowy / Polski / English (po ponownym uruchomieniu).
