# WSJT-X, JTDX and other programs

Any program with Hamlib support can use CAT2RIG through the **Hamlib NET rigctl** (model 2) driver.

## WSJT-X / JTDX → Settings → Radio
| Setting | Value |
|---|---|
| Rig | Hamlib NET rigctl |
| Network Server | `127.0.0.1:4532` (the TCP port from CAT2RIG) |
| PTT Method | **CAT** |
| Mode | **Data/Pkt** for radios with DATA mode (IC-7100/7300/705/9700/7610, newer Yaesu), otherwise **USB** |
| Split Operation | None or Fake It |
| Read and display PWR and SWR | **off** |

Click **Test CAT** (turns green) and **Test PTT** (CAT2RIG shows TX).

**Order:** start CAT2RIG first, then WSJT-X. **Never** select the radio's serial port in WSJT-X – CAT2RIG owns it.

Audio is independent of CAT2RIG: select the radio's USB audio device (or your sound interface) in WSJT-X → Audio.

## fldigi
Configure → Rig Control → Hamlib: Rig **Hamlib NET rigctl**, Device `127.0.0.1:4532`, PTT via Hamlib CAT. Initialize.

## Loggers and other tools
Choose *Hamlib NET rigctl* / *rigctld* and host `127.0.0.1`, port `4532`. Several programs can be connected at once. Loggers that display the S-meter can read it from CAT2RIG (`l STRENGTH`); power while transmitting is `l RFPOWER_METER`.

## Remote access
Tick *Allow access from local network* in CAT2RIG and use the Mac's IP address instead of `127.0.0.1` on the other computer.
