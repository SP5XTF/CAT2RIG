# Troubleshooting

Tick **Show CAT frames** in CAT2RIG first – the log then shows everything sent to (`TX`) and received from (`RX`) the radio. With the **Hamlib** driver the details go to `~/Library/Logs/CAT2RIG/hamlib.log`.

| Symptom | What to check |
|---|---|
| “Radio not responding”, only `TX` in the log | baud rate, CI-V address, CAT settings in the radio menu; Yaesu: RTS/CTS and CAT RTS |
| No `RX` at all | wrong port (try the interface's other port), cable, USB driver |
| Port name changed after a reboot | CAT2RIG (1.7.1+) finds the interface by its USB serial number; after updating, start once manually with the right port |
| Port busy | flrig, rigctld or WSJT-X (with a serial port set) holds the port – close it |
| WSJT-X: *Connection refused* | CAT2RIG not started or different TCP port |
| WSJT-X: *cannot open PTT device* | set **PTT Method: CAT** in WSJT-X |
| Radio doesn't follow band changes | LOCK on the radio; check the log for `RPRT -9` |
| WSJT-X keeps changing the mode | radio has no DATA mode – set **Mode: USB** in WSJT-X |
| Slow reaction | look for “Slow radio response” in the log |
| PTT lamp lights but the radio doesn't transmit | RTS ↔ DTR, wrong PTT port, or use CAT PTT |
| Radio not on the model list | set **Driver: Hamlib** and pick it from the Hamlib menu ([Hamlib driver](Hamlib-Driver)) |
| Built-in driver misbehaves | try the same radio with **Driver: Hamlib** and report the difference |
| *Hamlib not available* | the app was built without Hamlib – download the release DMG or run `bash scripts/build_hamlib.sh` |
| S / PO meter shows “—” | the radio (or driver) doesn't report the value – e.g. IC-706MKIIG has no power meter, Kenwood/Elecraft meters only via Hamlib |

## Log codes
`RPRT 0` OK · `-1` invalid argument · `-5` radio not responding · `-9` rejected by the radio · `-11` command not supported

## Reporting a problem
[Open an issue](https://github.com/SP5XTF/CAT2RIG/issues/new/choose) with: CAT2RIG version (bottom of the window), macOS version, radio model, interface, baud rate, PTT settings in CAT2RIG and the client, and the log with *Show CAT frames* ticked (with the Hamlib driver also `~/Library/Logs/CAT2RIG/hamlib.log`).
