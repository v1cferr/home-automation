# Smart electric shower

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

- **Evidence**: no mDNS service and no SSDP response, like the [lamp](wifi-lamp.md). Once it
  joined the 2.4 GHz network, the router's DHCP leases showed a client with the hostname `Zagonel` and
  a MAC prefix the IEEE registry assigns to *Espressif Inc.*, and the owner confirmed the
  brand. That matches the Zagonel Ducali, whose ESP32 module (Wi-Fi 2.4 GHz only, plus BLE)
  Anatel approved in 2022. The vendor app is *Smart Banho*. The router now reserves its
  address.
- **Home Assistant discovery**: none. The installed version has no DHCP matcher for that
  hostname or MAC prefix, there is no core integration, and no local API is documented.
- **Integration path**: community only, and cloud only. All three candidates sign in to
  Zagonel's cloud with the app account's email and password, which Home Assistant keeps in
  its config entry. Reviewed on 2026-11-12 against the criteria below:

  | Repository                                         | Activity                            | Behavior                                                                 |
  | -------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------ |
  | `alexandrepossebom/zagonel-ha`                     | 6 commits, last 2026-09, no license | Sensors only: one login, then `GET` requests every 10 minutes            |
  | `cleberdevsoares/homeassistant-zagonel-smartbanho` | 7 commits, created 2026-10, MIT     | Live state and controls over cloud MQTT; publishes to it every 15 s      |
  | `humbertogontijo/homeassistant-zagonel`            | Idle since 2023-10                  | Rejected: targets a server reported as shut down, open connection issues |

  The first is the one to start with, because its whole code path was read and it never
  writes: it only fetches the shower list and the month's measurements, so it reports each
  shower after the fact rather than live. It needs `httpx`, which the installed version
  already ships. HACS is not deployed here, so
  [`scripts/install-zagonel.sh`](../../scripts/install-zagonel.sh) fetches it at
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
- **Use (2026-11-13)**: the Energy dashboard lists the shower as an individual device for
  both energy and water, fed by the monthly sensors, which already carry `state_class: total`
  and a `last_reset` at the start of the month (UTC). The per-shower sensors are not used
  there: they are `total` without a reset, so each new shower would read as a delta from
  the previous one.
  [`config/packages/shower.yaml`](../../config/packages/shower.yaml) adds a notification
  when a shower goes over 15 min or BRL 2.00 (both adjustable helpers) and a monthly summary on the month's last
  evening. Notifications go to the UI's notification panel until a phone runs the
  companion app.
- **Safety**: a high-power heating appliance. No command of any kind is sent to it during
  discovery, and any future integration starts read-only.
