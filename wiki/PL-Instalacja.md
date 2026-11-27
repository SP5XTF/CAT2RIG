# Instalacja

**Wymagania:** macOS 13 Ventura lub nowszy (Apple Silicon albo Intel) oraz kabel/interfejs CAT lub USB do radia.

## Z wydania (zalecane)
1. Pobierz `CAT2RIG-X.Y.dmg` z [Releases](https://github.com/SP5XTF/CAT2RIG/releases).
2. Otwórz go i przeciągnij **CAT2RIG** do **Programów**.
3. Pierwsze uruchomienie: aplikacja nie jest notaryzowana, więc kliknij ją prawym przyciskiem → **Otwórz** → **Otwórz**. Albo:
   ```bash
   xattr -dr com.apple.quarantine /Applications/CAT2RIG.app
   ```

Aplikacja jest uniwersalna (Apple Silicon i Intel) i zawiera już bibliotekę **Hamlib** – nic więcej nie trzeba instalować.

## Sterowniki USB
Większość radiów pojawia się jako `/dev/cu.usbserial-…` bez dodatkowych sterowników. Niektóre interfejsy (np. układ Silicon Labs CP210x w wielu radiach Yaesu i Icom) na starszych macOS wymagają sterownika VCP producenta. Jeśli po podłączeniu radia nie pojawia się nowy port, zainstaluj sterownik i kliknij **Odśwież** w CAT2RIG.

## Aktualizacja
Zainstaluj nową wersję w miejsce starej – ustawienia zostają.

**Z Civ2Rig (≤ 1.2):** ustawienia przenoszą się same. Jeśli w Civ2Rig było włączone *Uruchamiaj przy logowaniu*, wyłącz to najpierw w starej aplikacji, usuń Civ2Rig.app i włącz opcję ponownie w CAT2RIG.

## Odinstalowanie
Usuń CAT2RIG.app. Ustawienia: `defaults delete pl.hamradio.cat2rig`.
