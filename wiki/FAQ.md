# FAQ

**Why not just use rigctld or flrig?** You can. CAT2RIG is a small native macOS app with a GUI, auto-start, a SCAN indicator and logs aimed at digital-mode operating.

**Can several programs use the radio at once?** Yes – each connects to CAT2RIG over TCP.

**Do I need to install Hamlib?** No – it is bundled. The built-in drivers don't use it at all; the *Hamlib* driver does.

**Does it read S-meter, power or SWR?** S-meter and power – yes, since 1.7.0 (where the radio reports them). SWR – not yet, so keep *Read and display PWR and SWR* unticked in WSJT-X.

**Can I try it without a radio?** Yes – choose *Driver: Hamlib*, model *Hamlib → Dummy*, click Start (no port needed) and connect WSJT-X.

**Is it signed by Apple?** It is ad-hoc signed, not notarized – right-click → Open on first launch.

**Where are the settings stored?** `~/Library/Preferences/pl.hamradio.cat2rig.plist`.

**My radio is not on the list.** Many radios speak one of the supported protocols. Try *Icom (other CI-V model)* or a model from the same family and [report the result](Troubleshooting#reporting-a-problem).
