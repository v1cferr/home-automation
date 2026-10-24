# Device discovery

How devices are found, what each stage proves, and the current state of each device
category. Addresses and identifiers are intentionally absent: raw evidence lives in `local/`.

## Three stages, three different claims

| Stage | What it proves | Where to see it |
| --- | --- | --- |
| **Service announced** | Something on the LAN advertises a protocol (mDNS, SSDP, DHCP) | `avahi-browse`, `scripts/discovery-snapshot.sh`, the Zeroconf/SSDP browsers in the UI |
| **Integration discovered** | A Home Assistant integration's matcher fired and created a discovery flow | Settings > Devices & services > *Discovered* |
| **Integration configured** | A config entry exists and entities work | Settings > Devices & services > *Configured* |

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
  hostname `wlan0` typical of Tuya Wi-Fi modules. The shower was offline at the time, so
  this is most likely the lamp, but nothing on the network names the product.
- **Home Assistant discovery**: none. The installed version has no DHCP matcher for that
  MAC prefix, and Tuya devices announce nothing over mDNS or SSDP.
- **Integration path**: the core [Tuya](https://www.home-assistant.io/integrations/tuya/)
  integration, which links the Smart Life / Tuya Smart app account by QR code (cloud).
- **Status**: *candidate*. Confirm in the vendor app which device it is.

### Host's own media server

The UI lists a *DLNA Digital Media Server* under *Discovered*: that is the development
host's Jellyfin answering SSDP, not a home device. Ignore it.

### Smart electric shower

- **Evidence**: same as the lamp: nothing announced.
- **Status**: *not found*. Needs the brand and model, or the vendor app's name.
- **Safety**: a high-power heating appliance. No command of any kind is sent to it during
  discovery, and any future integration starts read-only.

## Choosing an integration

Prefer, in order: a core integration with local control, a core integration with cloud
control, a community integration (only after checking maintenance, open issues, the code
path that handles credentials, and compatibility with the installed version).

Common paths once the vendor app is known:

| Vendor app | Core integration | Control |
| --- | --- | --- |
| Smart Life / Tuya Smart | [Tuya](https://www.home-assistant.io/integrations/tuya/) | Cloud |
| Matter-certified device | [Matter](https://www.home-assistant.io/integrations/matter/) (needs Matter Server) | Local |
| Tasmota / ESPHome firmware | Tasmota (needs MQTT) / ESPHome | Local |
| Amazon Alexa app | [Alexa Devices](https://www.home-assistant.io/integrations/alexa_devices/) | Cloud |
