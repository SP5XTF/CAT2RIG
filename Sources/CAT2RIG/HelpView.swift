import SwiftUI
import AppKit
import CAT2RIGCore

/// Okno pomocy (menu Pomoc lub ⌘?). Treść w dwóch językach, wybór wg języka programu.
struct HelpView: View {
    private let sections = LanguageSettings.effective == "en" ? HelpContent.english : HelpContent.polish

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "CAT2RIG")
                            .font(.title.bold())
                        Text("Most CAT (Icom, Yaesu, Kenwood, Elecraft, Xiegu) → Hamlib NET rigctl")
                            .foregroundStyle(.secondary)
                        Text(appVersionString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link(destination: ProjectLinks.repository) {
                            Text(verbatim: "github.com/SP5XTF/CAT2RIG")
                        }
                        .font(.caption)
                    }
                }
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.title3.bold())
                        Text(section.attributedBody)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if let lib = HamlibLibrary.shared {
                    Text(verbatim: "\(lib.version) · LGPL 2.1 · \(lib.models.count) models")
                    Text(verbatim: lib.path).textSelection(.enabled)
                } else {
                    Text("Hamlib niedostępny")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 400)
    }
}

struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String

    /// Markdown w treści: **pogrubienie**, `kod`; podziały linii zachowane.
    var attributedBody: AttributedString {
        (try? AttributedString(markdown: body,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(body)
    }
}

enum HelpContent {
    static let polish: [HelpSection] = [
        HelpSection(title: "Do czego służy CAT2RIG", body: """
        CAT2RIG łączy się z radiem przez CAT (Icom/Xiegu CI-V, Yaesu, Kenwood/Elecraft) i udostępnia \
        je programom – WSJT-X, JTDX, fldigi, loggerom – jako serwer **Hamlib NET rigctl**, tak jak \
        flrig albo rigctld. Programy nie otwierają portów szeregowych same, tylko łączą się \
        z CAT2RIG przez TCP, więc kilka z nich może jednocześnie sterować jednym radiem.
        """),
        HelpSection(title: "Szybki start", body: """
        1. Wybierz **Model** radia. Prędkość, bity stopu, RTS/CTS, adres CI-V i PTT ustawią się \
        na wartości domyślne.
        2. Wybierz **Port radia** – port CAT interfejsu albo kabla USB (`/dev/cu.…`). \
        **Prędkość** musi być taka jak w menu radia.
        3. Wybierz **PTT**: *CAT*, jeśli radio to obsługuje; *RTS/DTR*, gdy interfejs kluczuje \
        nadajnik linią; *brak / VOX*, gdy nadawanie załatwia VOX.
        4. Kliknij **Start**. Status „Radio połączone” i częstotliwość na wyświetlaczu oznaczają, \
        że CAT działa.
        5. Zaznacz **Start automatycznie**, żeby przy kolejnych uruchomieniach łączyć się od razu.
        """),
        HelpSection(title: "Obsługiwane radia", body: """
        • **Icom** (CI-V): IC-706MKIIG, IC-718, IC-746PRO, IC-756PROIII, IC-7000, IC-7200, \
        IC-7410, IC-7600, IC-9100, IC-7100, IC-7300, IC-705, IC-9700, IC-7610 oraz inne modele CI-V.
        • **Xiegu** (CI-V): G90, X6100, X5105, X108G.
        • **Yaesu** (nowszy CAT): FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FTDX5000, \
        FTDX3000, FTDX1200, FT-2000, FT-950, FT-450/450D.
        • **Yaesu** (CAT binarny): FT-817/818, FT-857, FT-897.
        • **Kenwood**: TS-590S/SG, TS-480, TS-2000. **Elecraft**: K2, K3/K3S, KX2/KX3, K4. \
        **QRP Labs**: QDX/QCX/QMX. **(tr)uSDX**.

        Znak **✓** przy modelu na liście oznacza radio sprawdzone na prawdziwym sprzęcie. \
        PTT przez CAT nie jest dostępne w IC-706MKIIG, IC-718, IC-746PRO, IC-756PROIII i X108G \
        (dla nich RTS/DTR albo VOX). \
        Tryb DATA (Data/Pkt w WSJT-X) obsługują IC-7100/7300/705/9700/7610 (USB-D) i nowsze Yaesu \
        (DATA-U). W pozostałych radiach ustaw w WSJT-X **Mode: USB**.
        """),
        HelpSection(title: "Ustawienia w radiu", body: """
        • **Icom / Xiegu** – adres CI-V w CAT2RIG musi być taki jak w menu radia (szesnastkowo, \
        np. `94`). Włącz **CI-V Transceive**, żeby zmiany z gałki były widoczne od razu.
        • **Yaesu FT-991A, FT-891, FT-710, FTDX…** – prędkość z menu CAT (np. *CAT RATE*). Kabel USB \
        daje dwa porty: CAT jest na jednym z nich – gdy radio nie odpowiada, spróbuj drugiego. \
        Gdy w radiu jest włączone **CAT RTS**, zostaw zaznaczone **RTS/CTS**; gdy radio milczy, \
        wyłącz CAT RTS w radiu i odznacz RTS/CTS.
        • **Yaesu FT-817/857/897** – 2 bity stopu, prędkość z menu (domyślnie 4800).
        • **Kenwood / Elecraft** – prędkość z menu radia; CAT2RIG sam wyłącza Auto Information.
        """),
        HelpSection(title: "Ustawienia WSJT-X / JTDX", body: """
        • **Rig:** Hamlib NET rigctl
        • **Network Server:** `127.0.0.1:` + Port TCP z CAT2RIG (domyślnie 4532)
        • **PTT Method:** CAT – nadawanie wykona CAT2RIG w sposób wybrany w jego oknie
        • **Mode:** Data/Pkt dla radiów z trybem DATA, w pozostałych USB
        • **Split Operation:** None albo Fake It
        • odznacz **Read and display PWR and SWR** – CAT2RIG tego nie podaje

        Najpierw uruchamiaj CAT2RIG, potem WSJT-X. Portu CAT nie ustawiaj w WSJT-X – otwiera go \
        tylko CAT2RIG.
        """),
        HelpSection(title: "PTT", body: """
        • **CAT** – nadawanie komendą CAT (CI-V 1C 00, Yaesu TX1;, Kenwood TX;, FT-817 0x08).
        • **RTS / DTR** – linią interfejsu, na porcie CAT albo na osobnym **Porcie PTT** \
        (np. IC-706MKIIG z interfejsem kluczującym RTS). Port PTT jest otwierany bez wyłączności, \
        więc WSJT-X też może go mieć otwartego.
        • **brak / VOX** – CAT2RIG nie dotyka PTT.

        RTS/CTS i PTT linią RTS na tym samym porcie się wykluczają – CAT2RIG o tym ostrzeże.
        """),
        HelpSection(title: "Okno programu", body: """
        • **Wyświetlacz** – częstotliwość i emisja odczytane z radia.
        • **TX** – zapala się na czerwono podczas nadawania.
        • **Wskaźnik S / PO** – podczas odbioru S-metr (S1…S9, S9+20…+60), podczas nadawania moc \
        w procentach mocy maksymalnej. Wartości pochodzą z radia: S-metr podają Icom/Xiegu, nowsze \
        Yaesu, FT-817/857/897 i radia przez Hamlib; moc – nowsze Icomy (IC-7100/7300/705/9700/7610), \
        nowsze Yaesu, FT-817/857/897 i część radiów przez Hamlib. Kreska „—” oznacza brak odczytu. \
        Odczyty są przybliżone (kalibracja jak w Hamlib). Programy klienckie mogą je odczytać \
        komendami `l STRENGTH` i `l RFPOWER_METER`.
        • **SCAN** – zapala się na pomarańczowo przy szybkich zmianach częstotliwości \
        (co najmniej 4 w ciągu 2 s), np. gdy radio skanuje. Zmiany zlecone przez WSJT-X się nie liczą.
        • **Test sterowania** – ustawienie częstotliwości i PTT bez programu klienckiego. \
        PTT naprawdę włącza nadawanie – podłącz antenę albo sztuczne obciążenie.
        • **Log** – komendy ustawiające od klientów (np. `rigctl < F 7074000 > RPRT 0`), \
        komendy nieobsługiwane i odpowiedzi trwające co najmniej 300 ms („Wolna odpowiedź radia”).
        • **Pokaż ramki CAT** – dodatkowo wszystkie komendy oraz bajty wysyłane do radia (`TX`) \
        i odbierane z niego (`RX`). Dla Yaesu i Kenwood widać je jako tekst.
        """),
        HelpSection(title: "Autostart i logowanie", body: """
        **Start automatycznie** – po uruchomieniu CAT2RIG łączy się z radiem z ostatnimi \
        ustawieniami; gdy interfejsu USB jeszcze nie ma, próbuje co 5 s.

        **Uruchamiaj przy logowaniu do macOS** – w **CAT2RIG → Ustawienia…** (⌘,). Najpierw \
        przenieś CAT2RIG.app do folderu **Programy**. Wyłączyć można też w Ustawieniach \
        systemowych → Ogólne → Rzeczy otwierane podczas logowania.
        """),
        HelpSection(title: "Rozwiązywanie problemów", body: """
        • **Radio nie odpowiada** – sprawdź model, prędkość, adres CI-V i port (spróbuj drugiego \
        portu interfejsu); w Yaesu także bity stopu i RTS/CTS. Z ramkami CAT: są tylko `TX` – \
        radio milczy (prędkość, adres, ustawienia CAT); brak `TX` i `RX` – zły port lub kabel.
        • **Port zajęty** – port trzyma inny program (flrig, rigctld, WSJT-X z ustawionym portem). \
        Zamknij go albo usuń port z jego ustawień.
        • **WSJT-X: Connection refused** – CAT2RIG nie działa albo port TCP się różni.
        • **WSJT-X: cannot open PTT device** – ustaw w WSJT-X **PTT Method: CAT**.
        • **Radio nie zmienia częstotliwości** – sprawdź LOCK. Icom: CAT2RIG sam przełącza radio \
        z pamięci (V/M) na VFO.
        • **WSJT-X ciągle przestawia emisję** – w radiu bez trybu DATA ustaw w WSJT-X Mode: USB.
        • **Wolna reakcja** – szukaj w logu wpisów „Wolna odpowiedź radia”.

        Kody w logu: `RPRT 0` OK, `-1` zły argument, `-5` radio nie odpowiada, \
        `-9` radio odrzuciło komendę, `-11` komenda nieobsługiwana.
        """),
        HelpSection(title: "Sterownik Hamlib", body: """
        CAT2RIG zawiera bibliotekę **Hamlib**, więc obsługuje także radia spoza własnej listy. \
        W polu **Sterownik** wybierz **Hamlib**, a w polu **Model** – producenta i radio z menu \
        (ponad 300 modeli; numer to numer modelu z `rigctl -l`). Port, prędkość, bity stopu, RTS/CTS, \
        adres CI-V i PTT ustawiasz tak samo jak dla wbudowanych sterowników.

        • **Wbudowany** – szybkie, przetestowane sterowniki CAT2RIG (zalecane dla radii z listy).
        • **Hamlib** – radia spoza listy albo porównanie, gdy wbudowany sterownik nie działa.
        • Model **Hamlib Dummy** to symulator radia – pozwala sprawdzić WSJT-X bez radia i bez portu.
        • Komunikaty Hamlib trafiają do pliku `~/Library/Logs/CAT2RIG/hamlib.log` (błędy zawsze, \
        z zaznaczonym **Pokaż ramki CAT** – pełny ślad komunikacji). Dołącz go do zgłoszenia błędu.

        Hamlib jest na licencji **LGPL 2.1** i jest dołączony jako osobna biblioteka \
        (Contents/Frameworks/libhamlib.4.dylib), którą można podmienić na własną wersję. \
        Kod źródłowy: [github.com/Hamlib/Hamlib](https://github.com/Hamlib/Hamlib).
        """),
        HelpSection(title: "Język i więcej informacji", body: """
        Język programu zmienisz w **CAT2RIG → Ustawienia…** (⌘,); domyślnie używany jest język \
        systemu. Więcej opisów, także poszczególnych radiów, jest w \
        [Wiki projektu](https://github.com/SP5XTF/CAT2RIG/wiki/PL-Strona-glowna). \
        Nowe wersje: [github.com/SP5XTF/CAT2RIG/releases](https://github.com/SP5XTF/CAT2RIG/releases). \
        Problem lub pomysł? [Zgłoś go na GitHubie](https://github.com/SP5XTF/CAT2RIG/issues/new/choose) \
        – najlepiej z logiem przy zaznaczonym „Pokaż ramki CAT”.
        """),
    ]

    static let english: [HelpSection] = [
        HelpSection(title: "What CAT2RIG does", body: """
        CAT2RIG talks to your radio over CAT (Icom/Xiegu CI-V, Yaesu, Kenwood/Elecraft) and shares \
        it with programs – WSJT-X, JTDX, fldigi, loggers – as a **Hamlib NET rigctl** server, just \
        like flrig or rigctld. Programs don't open serial ports themselves; they connect to \
        CAT2RIG over TCP, so several of them can control one radio at the same time.
        """),
        HelpSection(title: "Quick start", body: """
        1. Choose the radio **Model**. Baud rate, stop bits, RTS/CTS, CI-V address and PTT get \
        their defaults.
        2. Choose the **Radio port** – the CAT port of your interface or USB cable (`/dev/cu.…`). \
        The **Baud rate** must match the radio's menu.
        3. Choose **PTT**: *CAT* if the radio supports it; *RTS/DTR* if your interface keys the \
        transmitter by a line; *none / VOX* if VOX does the keying.
        4. Click **Start**. “Radio connected” and a frequency on the display mean CAT works.
        5. Tick **Start automatically** to connect right away next time.
        """),
        HelpSection(title: "Supported radios", body: """
        • **Icom** (CI-V): IC-706MKIIG, IC-718, IC-746PRO, IC-756PROIII, IC-7000, IC-7200, \
        IC-7410, IC-7600, IC-9100, IC-7100, IC-7300, IC-705, IC-9700, IC-7610 and other CI-V models.
        • **Xiegu** (CI-V): G90, X6100, X5105, X108G.
        • **Yaesu** (newer CAT): FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FTDX5000, \
        FTDX3000, FTDX1200, FT-2000, FT-950, FT-450/450D.
        • **Yaesu** (binary CAT): FT-817/818, FT-857, FT-897.
        • **Kenwood**: TS-590S/SG, TS-480, TS-2000. **Elecraft**: K2, K3/K3S, KX2/KX3, K4. \
        **QRP Labs**: QDX/QCX/QMX. **(tr)uSDX**.

        A **✓** next to a model in the list means it was verified on a real radio. \
        CAT PTT is not offered for the IC-706MKIIG, IC-718, IC-746PRO, IC-756PROIII and X108G \
        (use RTS/DTR or VOX). \
        DATA mode (Data/Pkt in WSJT-X) is supported on the IC-7100/7300/705/9700/7610 (USB-D) and \
        newer Yaesu (DATA-U). With other radios set **Mode: USB** in WSJT-X.
        """),
        HelpSection(title: "Radio settings", body: """
        • **Icom / Xiegu** – the CI-V address in CAT2RIG must match the radio's menu (hex, e.g. \
        `94`). Enable **CI-V Transceive** for instant knob updates.
        • **Yaesu FT-991A, FT-891, FT-710, FTDX…** – baud rate from the CAT menu (e.g. *CAT RATE*). \
        The USB cable provides two ports; CAT is on one of them – if the radio doesn't answer, try \
        the other. If **CAT RTS** is enabled in the radio keep **RTS/CTS** ticked; if the radio stays \
        silent, disable CAT RTS and untick RTS/CTS.
        • **Yaesu FT-817/857/897** – 2 stop bits, baud rate from the menu (4800 by default).
        • **Kenwood / Elecraft** – baud rate from the radio's menu; CAT2RIG turns Auto Information off.
        """),
        HelpSection(title: "WSJT-X / JTDX settings", body: """
        • **Rig:** Hamlib NET rigctl
        • **Network Server:** `127.0.0.1:` + the TCP port from CAT2RIG (default 4532)
        • **PTT Method:** CAT – CAT2RIG keys the radio the way chosen in its window
        • **Mode:** Data/Pkt for radios with a DATA mode, USB otherwise
        • **Split Operation:** None or Fake It
        • untick **Read and display PWR and SWR** – CAT2RIG doesn't report it

        Start CAT2RIG first, then WSJT-X. Don't set the CAT port in WSJT-X – only CAT2RIG opens it.
        """),
        HelpSection(title: "PTT", body: """
        • **CAT** – transmit by CAT command (CI-V 1C 00, Yaesu TX1;, Kenwood TX;, FT-817 0x08).
        • **RTS / DTR** – by an interface line, on the CAT port or a separate **PTT port** \
        (e.g. an IC-706MKIIG with an RTS-keyed interface). The PTT port is opened non-exclusively, \
        so WSJT-X may have it open too.
        • **none / VOX** – CAT2RIG leaves PTT alone.

        RTS/CTS and RTS PTT on the same port can't be used together – CAT2RIG warns about it.
        """),
        HelpSection(title: "Main window", body: """
        • **Display** – frequency and mode read from the radio.
        • **TX** – red while transmitting.
        • **S / PO meter** – S-meter while receiving (S1…S9, S9+20…+60), output power in percent of \
        maximum while transmitting. Values come from the radio: S-meter on Icom/Xiegu, newer Yaesu, \
        FT-817/857/897 and radios via Hamlib; power on newer Icoms (IC-7100/7300/705/9700/7610), newer \
        Yaesu, FT-817/857/897 and some radios via Hamlib. A dash “—” means no reading. Readings are \
        approximate (Hamlib calibration). Client programs can read them with `l STRENGTH` and \
        `l RFPOWER_METER`.
        • **SCAN** – orange on rapid frequency changes (at least 4 within 2 s), e.g. when the \
        radio is scanning. Changes requested by WSJT-X don't count.
        • **Control test** – set a frequency and key PTT without a client. PTT really transmits – \
        connect an antenna or a dummy load.
        • **Log** – set commands from clients (e.g. `rigctl < F 7074000 > RPRT 0`), unsupported \
        commands and responses taking 300 ms or more (“Slow radio response”).
        • **Show CAT frames** – also every command and the bytes sent to (`TX`) and received from \
        (`RX`) the radio; shown as text for Yaesu and Kenwood.
        """),
        HelpSection(title: "Auto-start and login", body: """
        **Start automatically** – on launch CAT2RIG connects with the last settings; if the USB \
        interface isn't there yet, it retries every 5 s.

        **Launch at macOS login** – in **CAT2RIG → Settings…** (⌘,). Move CAT2RIG.app to \
        **Applications** first. It can also be turned off in System Settings → General → Login Items.
        """),
        HelpSection(title: "Troubleshooting", body: """
        • **Radio not responding** – check model, baud rate, CI-V address and port (try the \
        interface's other port); for Yaesu also stop bits and RTS/CTS. With CAT frames on: only \
        `TX` – radio silent (baud, address, CAT settings); no `TX`/`RX` – wrong port or cable.
        • **Port busy** – another program holds the port (flrig, rigctld, WSJT-X with a port set). \
        Close it or remove the port from its settings.
        • **WSJT-X: Connection refused** – CAT2RIG isn't running or the TCP port differs.
        • **WSJT-X: cannot open PTT device** – set **PTT Method: CAT** in WSJT-X.
        • **Radio doesn't change frequency** – check LOCK. Icom: CAT2RIG switches from memory (V/M) \
        to VFO automatically.
        • **WSJT-X keeps changing the mode** – on radios without DATA mode set Mode: USB in WSJT-X.
        • **Slow reaction** – look for “Slow radio response” in the log.

        Log codes: `RPRT 0` OK, `-1` bad argument, `-5` radio not responding, \
        `-9` command rejected by the radio, `-11` command not supported.
        """),
        HelpSection(title: "Hamlib driver", body: """
        CAT2RIG includes the **Hamlib** library, so it also supports radios outside its own list. \
        Set **Driver** to **Hamlib** and pick the maker and radio from the **Model** menu \
        (300+ models; the number is the model number from `rigctl -l`). Port, baud rate, stop bits, \
        RTS/CTS, CI-V address and PTT work the same as with the built-in drivers.

        • **Built-in** – fast, tested CAT2RIG drivers (recommended for radios on the list).
        • **Hamlib** – radios not on the list, or for comparison when a built-in driver misbehaves.
        • The **Hamlib Dummy** model is a radio simulator – test WSJT-X without a radio or a port.
        • Hamlib messages go to `~/Library/Logs/CAT2RIG/hamlib.log` (errors always, the full \
        communication trace with **Show CAT frames** ticked). Attach it to bug reports.

        Hamlib is licensed under the **LGPL 2.1** and ships as a separate library \
        (Contents/Frameworks/libhamlib.4.dylib) that you may replace with your own build. \
        Source code: [github.com/Hamlib/Hamlib](https://github.com/Hamlib/Hamlib).
        """),
        HelpSection(title: "Language and more", body: """
        Change the program language in **CAT2RIG → Settings…** (⌘,); the system language is used by \
        default. More documentation, including per-radio notes, is in the \
        [project wiki](https://github.com/SP5XTF/CAT2RIG/wiki). \
        New versions: [github.com/SP5XTF/CAT2RIG/releases](https://github.com/SP5XTF/CAT2RIG/releases). \
        A problem or an idea? [Report it on GitHub](https://github.com/SP5XTF/CAT2RIG/issues/new/choose) \
        – ideally with the log while “Show CAT frames” is ticked.
        """),
    ]
}
