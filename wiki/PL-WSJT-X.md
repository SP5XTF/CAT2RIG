# WSJT-X, JTDX i inne programy

## WSJT-X / JTDX → Settings → Radio
| Ustawienie | Wartość |
|---|---|
| Rig | Hamlib NET rigctl |
| Network Server | `127.0.0.1:4532` (port TCP z CAT2RIG) |
| PTT Method | **CAT** |
| Mode | **Data/Pkt** w radiach z trybem DATA (IC-7100/7300/705/9700/7610, nowsze Yaesu), w pozostałych **USB** |
| Split Operation | None albo Fake It |
| Read and display PWR and SWR | **wyłączone** |

**Test CAT** powinien zrobić się zielony, a **Test PTT** zapalić lampkę TX w CAT2RIG.

**Kolejność:** najpierw CAT2RIG, potem WSJT-X. **Nie wybieraj** w WSJT-X portu szeregowego radia – należy on do CAT2RIG. Dźwięk ustawiasz niezależnie (karta USB radia albo interfejs audio).

## fldigi
Configure → Rig Control → Hamlib: Rig **Hamlib NET rigctl**, Device `127.0.0.1:4532`, PTT przez Hamlib CAT, Initialize.

## Loggery i inne
Wybierz *Hamlib NET rigctl* / *rigctld*, host `127.0.0.1`, port `4532`. Programów może być kilka naraz. Loggery pokazujące S-metr mogą go odczytać z CAT2RIG (`l STRENGTH`); moc podczas nadawania to `l RFPOWER_METER`.
