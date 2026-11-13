# Device discovery

How devices are found, what each stage proves, and the current state of each device
category. Addresses and identifiers are intentionally absent: raw evidence lives in `local/`.

## Three stages, three different claims

| Stage                      | What it proves                                                            | Where to see it                                                                       |
| -------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Service announced**      | Something on the LAN advertises a protocol (mDNS, SSDP, DHCP)             | `avahi-browse`, `scripts/discovery-snapshot.sh`, the Zeroconf/SSDP browsers in the UI |
| **Integration discovered** | A Home Assistant integration's matcher fired and created a discovery flow | Settings > Devices & services > *Discovered*                                          |
| **Integration configured** | A config entry exists and entities work                                   | Settings > Devices & services > *Configured*                                          |

A device in stage 1 is not necessarily supported. A device in stage 2 may still need cloud
credentials. Only stage 3 counts as "integrated".

## Mechanisms Home Assistant uses

All are loaded by `default_config:`; none needs extra configuration.

- **Zeroconf / mDNS** ([docs](https://www.home-assistant.io/integrations/zeroconf/)): browses
  the service types listed in integration manifests. Needs 5353/udp inbound.
- **SSDP / UPnP** ([docs](https://www.home-assistant.io/integrations/ssdp/)): sends
  `M-SEARCH` and listens for `NOTIFY`. Needs 1900/udp inbound.
- **DHCP** ([docs](https://www.home-assistant.io/integrations/dhcp/)): watches DHCP requests
  on a raw socket and the host's neighbor table, matching hostnames and MAC prefixes (OUIs)
  from manifests. A device is usually seen when it joins the network or renews its lease, so
  power-cycling a device is the simplest way to trigger it.
- **Integration-specific broadcasts** (e.g. TP-Link, WiZ, Tuya local): sent by the
  integration itself once it is set up or during its own discovery.
- **Matter**: requires the Matter Server, which is not deployed in this phase.

## Diagnostic tools (non-invasive)

```sh
scripts/discovery-snapshot.sh > local/discovery-$(date +%F).txt
```

It lists mDNS services on the LAN interface, sends one standard SSDP `M-SEARCH` (the same
query Home Assistant sends), and matches the host's neighbor table against Home Assistant's
own DHCP matcher table. It does not scan ports, probe services or authenticate.

In the UI, after onboarding and with *Advanced mode* enabled in the user profile:
Settings > System > Network shows the interfaces used for discovery, and the Zeroconf and
SSDP integrations have *Browser* views listing everything received.

The neighbor table only contains hosts this machine has talked to. The router's DHCP lease
list (OpenWrt: Status > Overview > Active DHCP leases) is the authoritative inventory of
what is connected.

## Current state by device

Findings from the first run (Home Assistant 2026.10). Status vocabulary: *integrated*,
*discovered*, *candidate*, *requires authentication*, *not found*, *incompatible
(confirmed)*.

### Amazon Echo

- **Evidence**: announces `_spotify-connect._tcp`. Its Spotify Connect `getInfo` response
  (unauthenticated, read-only, the same request any Spotify client makes) reports brand
  *Amazon*, model *Echo Dot*.
- **Home Assistant discovery**: none expected. No core integration matches
  `_spotify-connect._tcp`, and Echo devices are not controlled over the LAN.
- **Integration path**: the core
  [Alexa Devices](https://www.home-assistant.io/integrations/alexa_devices/) integration
  (present in the installed version). It is cloud-based and needs the Amazon account
  credentials and a one-time code, entered in the UI by the account owner. Never store them
  in this repository.
- **Known bug (2026.10.x)**: the setup spinner never ends and the log shows
  `InvalidUrlClientError: /ax/claim?...`. Amazon now routes some sign-ins through a passkey
  page with a relative form action that `aioamazondevices` 16.3.2 cannot follow, so the
  credentials are never even submitted
  ([core#187595](https://github.com/home-assistant/core/issues/187595)). The bump to 16.9.1
  ([core#187985](https://github.com/home-assistant/core/pull/187985)) was merged into `dev`
  on 2026-10-22 without a backport, so it ships with 2026.11. Retry after updating the image.
- **Status**: *requires authentication*, blocked by the bug above.

### Wi-Fi lamp

- **Evidence**: no mDNS service and no SSDP response. The router's DHCP leases list one
  client whose MAC prefix the IEEE registry assigns to *Tuya Smart Inc.*, with the generic
  hostname `wlan0` typical of Tuya Wi-Fi modules. The shower has since shown up as a
  separate client, so this is most likely the lamp, but nothing on the network names the
  product.
- **Home Assistant discovery**: none. The installed version has no DHCP matcher for that
  MAC prefix, and Tuya devices announce nothing over mDNS or SSDP.
- **Integration path**: the core [Tuya](https://www.home-assistant.io/integrations/tuya/)
  integration, which links the Smart Life / Tuya Smart app account by QR code (cloud).
- **Status**: *candidate*. Confirm in the vendor app which device it is.

### Generic Android TV box

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

### Host's own media server

The UI lists a *DLNA Digital Media Server* under *Discovered*: that is the development
host's Jellyfin answering SSDP, not a home device. Ignore it.

### Smart electric shower

- **Evidence**: no mDNS service and no SSDP response, like the lamp. Once it joined the
  2.4 GHz network, the router's DHCP leases showed a client with the hostname `Zagonel` and
  a MAC prefix the IEEE registry assigns to *Espressif Inc.*, and the owner confirmed the
  brand. That matches the Zagonel Ducali, whose ESP32 module (Wi-Fi 2.4 GHz only, plus BLE)
  Anatel approved in 2022. The vendor app is *Smart Banho*. The router now reserves its
  address.
- **Home Assistant discovery**: none. The installed version has no DHCP matcher for that
  hostname or MAC prefix, there is no core integration, and no local API is documented.
- **Integration path**: community only, and cloud only. All three candidates sign in to
  Zagonel's cloud with the app account's email and password, which Home Assistant keeps in
  its config entry. Reviewed on 2026-11-12 against the criteria below:

  | Repository                                         | Activity                                      | Behavior                                                                  |
  | -------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------- |
  | `alexandrepossebom/zagonel-ha`                     | 6 commits, last 2026-09, no license           | Sensors only: one login, then `GET` requests every 10 minutes             |
  | `cleberdevsoares/homeassistant-zagonel-smartbanho` | 7 commits, created 2026-10, MIT               | Live state and controls over cloud MQTT; publishes to it every 15 s       |
  | `humbertogontijo/homeassistant-zagonel`            | Idle since 2023-10                            | Rejected: targets a server reported as shut down, open connection issues  |

  The first is the one to start with, because its whole code path was read and it never
  writes: it only fetches the shower list and the month's measurements, so it reports each
  shower after the fact rather than live. It needs `httpx`, which the installed version
  already ships. HACS is not deployed here, so `scripts/install-zagonel.sh` fetches it at
  the reviewed commit into `custom_components/`, which stays out of this repository because
  upstream has no license. The second was only skimmed: it has a write path to the
  appliance and optional database credentials, and needs a full read before it is
  considered.
- **Account**: the integration only signs in with an email and password. An app account
  created through Google sign-in has no password and is refused as invalid credentials
  until one is set in the app; the shower stays registered to the same account.
- **Status**: *integrated* (read-only) since 2026-11-12. The config entry was created
  through the REST config flow API, and the shower's 13 sensors (last shower and monthly
  totals) report data.
- **Safety**: a high-power heating appliance. No command of any kind is sent to it during
  discovery, and any future integration starts read-only.

### Tower fan

- **Product**: Midea VTB180A3, *Ventilador de Torre Smart Air Bladeless*, Wi-Fi. Paired
  with Midea's *SmartHome (MSmartHome)* app (`com.midea.ai.overseas`), whose account is
  the one the integration signs in with.
- **Evidence**: no mDNS service and no SSDP response. The router's DHCP leases list a client
  with the hostname `midea_fa_1188` and a MAC prefix the IEEE registry assigns to *GD Midea
  Air-Conditioning Equipment Co., Ltd.*; `fa` is Midea's appliance type code for fans. TCP
  port 6444, Midea's local control protocol, is open. One standard Midea discovery query
  (the same one the integration's *search* step sends, read-only) answers with type `0xFA`,
  model code `560000AG` and **protocol V3**.
- **Home Assistant discovery**: none yet. The core integration's DHCP matcher is
  `registered_devices` only, so it rediscovers devices that are already configured and
  never offers a new one.
- **Integration path**: the core [Midea](https://www.home-assistant.io/integrations/midea/)
  integration (present in the installed version, quality scale *gold*, built on
  `midea-local`), which lists `0xFA` fans with power, speed, oscillation and mode entities.
  Control is **local polling** over port 6444, but a V3 device only accepts a session after
  a token and key are fetched from Midea's cloud once, during setup. The config flow offers
  either a shared preset account that `midea-local` ships (on the NetHome Plus server) or
  the owner's own app account, whose email and password then stay in the config entry.
  Once set up, the cloud is not needed for day-to-day control. No community integration is
  needed, so none was reviewed.
- **First attempt (2026-11-13)**: the preset account signs in, but every `getToken` call
  answers `9999 system error`, so the flow ends in `token_unavailable`. Upstream reports the
  same for Brazilian appliances, where the token only comes from the SmartHome server
  ([midea-local#865](https://github.com/midea-lan/midea-local/issues/865)). The same issue
  ties appliances that refuse LAN login, even from Midea's own app, to bit `0x04` of byte 57
  of the decrypted discovery reply being clear; on this fan that byte is `0x0d`, so the bit
  is set, as on the appliances that work. Next: the owner's SmartHome account, entered in
  the UI with the *MSmartHome* server selected. An account created through Google sign-in
  needs a password set in the app first, as with the shower.
- **Status**: *integrated* (local control) since 2026-11-13. The owner's SmartHome account
  fetched the V3 key, and the config entry loads with one fan entity (on/off, speed,
  oscillation, 12 preset modes), three selects for oscillation mode and angles, and a child
  lock switch. Setting speed 1 through the API worked: the fan changed, and reported it on
  its next poll. Setting the *smart* preset afterwards returned `200` but left the fan at
  speed 1, as the owner confirmed at the appliance. The router reserves its address.
- **Known quirks**: the fan has **10 speeds** on its own panel (Midea's product page says
  3), and the device reports the panel's number as is: speed 1 read as `1`, speed 10 as
  `10`. The integration assumes 3 speeds (`midea-local`'s default for `0xFA`), so speeds 4
  to 10 show above 100 % (10 reads 333 %) and Home Assistant can only set speeds 1 to 3.
  The library accepts a `speed_count` override, but the core integration has no option to
  pass it. The preset also kept reading *smart* through manual speed changes, so that
  attribute does not reflect the real mode. The product page lists no oscillation or tilt,
  so the oscillation selects may do nothing on this model.

## Choosing an integration

Prefer, in order: a core integration with local control, a core integration with cloud
control, a community integration (only after checking maintenance, open issues, the code
path that handles credentials, and compatibility with the installed version).

Common paths once the vendor app is known:

| Vendor app                 | Core integration                                                                   | Control |
| -------------------------- | ---------------------------------------------------------------------------------- | ------- |
| Smart Life / Tuya Smart    | [Tuya](https://www.home-assistant.io/integrations/tuya/)                           | Cloud   |
| Matter-certified device    | [Matter](https://www.home-assistant.io/integrations/matter/) (needs Matter Server) | Local   |
| Tasmota / ESPHome firmware | Tasmota (needs MQTT) / ESPHome                                                     | Local   |
| Amazon Alexa app           | [Alexa Devices](https://www.home-assistant.io/integrations/alexa_devices/)         | Cloud   |
| Smart Banho (Zagonel)      | None in core; community only (see the shower above)                                | Cloud   |
| SmartHome (MSmartHome)     | [Midea](https://www.home-assistant.io/integrations/midea/) (V3: cloud key once)    | Local   |
