# Device discovery

How devices are found, what each stage proves, and how an integration is chosen. The state of
each device lives in [devices/](devices/README.md). Addresses and identifiers are
intentionally absent: raw evidence lives in `local/`.

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

## Status vocabulary

Each page under [devices/](devices/README.md) ends with one of: *integrated*, *discovered*,
*candidate*, *requires authentication*, *not found*, *incompatible (confirmed)*. The first
run was on Home Assistant 2026.10.

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
| Smart Banho (Zagonel)      | None in core; community only ([shower](devices/zagonel-shower.md))                 | Cloud   |
| SmartHome (MSmartHome)     | [Midea](https://www.home-assistant.io/integrations/midea/) (V3: cloud key once)    | Local   |
