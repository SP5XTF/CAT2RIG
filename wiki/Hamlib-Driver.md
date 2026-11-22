# Hamlib driver

Since 1.6.0 CAT2RIG includes the [Hamlib](https://github.com/Hamlib/Hamlib) library (4.7.2). Nothing has to be installed.

## When to use it
- **Your radio is not on the built-in list** – Hamlib supports 300+ models.
- **A built-in driver misbehaves** – switch to Hamlib for the same radio and compare (please report the difference).
- **Testing without a radio** – the *Hamlib Dummy* model simulates a transceiver; no serial port needed.

For radios on the built-in list the **Built-in** driver stays recommended: it is faster, tested in CAT2RIG and handles details like CI-V collisions while scanning or the memory→VFO switch.

## How to use it
1. **Driver:** *Hamlib 4.7.2*.
2. **Model:** open the menu, choose the manufacturer and the radio. The number after the name is the Hamlib model number (`rigctl -l`); a status like *(Beta)* or *(Untested)* comes from Hamlib.
3. **Port, baud rate, stop bits, RTS/CTS, CI-V address** (Icom/Xiegu) – as for the built-in drivers.
4. **PTT:** *CAT* (Hamlib's CAT PTT), *RTS*/*DTR* (Hamlib keys the line, optionally on a separate PTT port) or *none / VOX*.
5. **Start.**

Switching to Hamlib with a model selected from the built-in list preselects the same radio in Hamlib.

## Logging
Hamlib writes its messages to `~/Library/Logs/CAT2RIG/hamlib.log` – errors always, the full communication trace when **Show CAT frames** is ticked. Attach the file to bug reports (open it with Console.app or any text editor).

## License
Hamlib is licensed under the **LGPL 2.1**. It ships as a separate library `CAT2RIG.app/Contents/Frameworks/libhamlib.4.dylib`, which you may replace with your own Hamlib 4.x build. License text and source information: `Contents/Resources/Hamlib/` and [THIRD_PARTY_NOTICES.md](https://github.com/SP5XTF/CAT2RIG/blob/main/THIRD_PARTY_NOTICES.md). If the library is missing, CAT2RIG keeps working with its built-in drivers.
