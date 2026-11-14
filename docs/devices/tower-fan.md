# Tower fan

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

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
  needs a password set in the app first, as with the [shower](zagonel-shower.md).
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
  pass it ([midea-local#1075](https://github.com/midea-lan/midea-local/issues/1075)).
  The preset also kept reading *smart* through manual speed changes, so that
  attribute does not reflect the real mode. The product page lists no oscillation or tilt,
  so the oscillation selects may do nothing on this model.
