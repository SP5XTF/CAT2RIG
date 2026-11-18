# Installation

**Requirements:** macOS 13 Ventura or newer (Apple Silicon or Intel) and a CAT/USB cable or interface for your radio.

## From a release (recommended)
1. Download `CAT2RIG-X.Y.dmg` from [Releases](https://github.com/<your-user>/CAT2RIG/releases).
2. Open it and drag **CAT2RIG** to **Applications**.
3. First launch: the app is not notarized by Apple, so right-click it → **Open** → **Open**. Alternatively:
   ```bash
   xattr -dr com.apple.quarantine /Applications/CAT2RIG.app
   ```

## USB drivers
Most radios appear as `/dev/cu.usbserial-…` without extra drivers. Some interfaces (e.g. the Silicon Labs CP210x chip in many Yaesu and Icom radios) may need the vendor's VCP driver on older macOS versions. If no new port appears after connecting the radio, install the driver for your cable's chip and click **Refresh** in CAT2RIG.

## Updating
Install the new version over the old one. Settings are kept.

**Coming from Civ2Rig (≤ 1.2):** settings are migrated on first launch. If *Launch at login* was on in Civ2Rig, turn it off there first, delete Civ2Rig.app and enable the option again in CAT2RIG.

## Uninstalling
Delete CAT2RIG.app. Settings: `defaults delete pl.hamradio.cat2rig`.
