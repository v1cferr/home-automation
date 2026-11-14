# Generic Android TV box

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

- **Evidence**: announces `_androidtvremote._tcp` under the name `TV BOX`, with only the
  Android TV Remote ports (6466/6467) open; ADB (5555) is closed and nothing answers SSDP.
  The MAC prefix belongs to *Shenzhen iComm Semiconductor*, a maker of cheap Wi-Fi chips.
  CPU-Z on the box itself reports:

  | Field          | Reported                                      | Assessment                                                                |
  | -------------- | --------------------------------------------- | ------------------------------------------------------------------------- |
  | SoC            | Allwinner H3, hardware `sun8iw7p1`            | Real: the kernel's hardware ID matches. Quad Cortex-A7 (32-bit), Mali-400 |
  | Android        | "11.1"                                        | Fake: API level 24 and build `NRD91N` are Android 7.0                     |
  | Security patch | 2016-11-05                                    | Real, and never updated                                                   |
  | RAM / storage  | 8 GB / 128 GB                                 | Fake: free space reads 653 MB (7%) and 3.28 GB (2%); likely 1 GB / 8 GB   |
  | Build          | `eng`, `test-keys`, root available to any app | Allwinner reference board firmware (`dolphin_fvd_p1`, board `exdroid`)    |

  Google Play sign-in fails ("something went wrong"): the device is not Google-certified.

  Over ADB as root, the block devices settle the storage question: the eMMC (`mmcblk0`,
  type `MMC`, name `008G70`) holds 8 GB, and the microSD slot is `mmcblk1` (type `SD`). The
  RAM figure cannot be read from the system: even `/proc/meminfo` reports 8 GB, so the kernel
  itself was patched to lie.
- **Access**: the Developer options only offer USB debugging, but `su` works from a terminal
  app (Termux), and `setprop service.adb.tcp.port 5555` followed by restarting `adbd`
  enables network ADB as root, with no key authorization prompt (an `eng` build). A reboot
  turns it off again.
- **Home Assistant discovery**: none expected. The core
  [Android TV Remote](https://www.home-assistant.io/integrations/androidtv_remote/)
  integration matches `_androidtvremote2._tcp`, not the older name this box announces, but
  it can be added manually by address.
- **Trust**: an unpatched, rooted engineering build from an unknown vendor, the profile of
  boxes shipped with pre-installed malware (BadBox 2.0). Do not enable network ADB or pair
  it with anything while it runs the stock firmware.
- **Plan**: replace the system with [LibreELEC](https://libreelec.tv/) (Kodi), which ships
  official `H3.arm` images; the `beelink-x2` variant is an H3 TV box and the first to try.
  The H3 boot ROM boots from microSD before eMMC and cannot boot from USB, so the image goes
  on a microSD card and the stock Android stays untouched (remove the card to go back).
  Expected issues: DRAM clock mismatches with the board's device tree, and no mainline driver
  for the iComm Wi-Fi chip (use Ethernet or a USB Wi-Fi adapter with a mainline driver). Once
  running, the core [Kodi](https://www.home-assistant.io/integrations/kodi/) integration
  controls it locally.
  With no microSD reader on the host, the box wrote the card itself: the image went over on
  a USB stick and `dd` ran on the box against `mmcblk1`, checked by type and name first,
  then verified against the image's checksum.
- **Status**: *candidate*. LibreELEC 12.2.1 (`beelink-x2`) is on the microSD, not yet
  booted.
