# Wi-Fi lamp

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

- **Evidence**: no mDNS service and no SSDP response. The router's DHCP leases list one
  client whose MAC prefix the IEEE registry assigns to *Tuya Smart Inc.*, with the generic
  hostname `wlan0` typical of Tuya Wi-Fi modules. The [shower](zagonel-shower.md) has since
  shown up as a separate client, so this is most likely the lamp, but nothing on the network names the
  product.
- **Home Assistant discovery**: none. The installed version has no DHCP matcher for that
  MAC prefix, and Tuya devices announce nothing over mDNS or SSDP.
- **Vendor app**: *Positivo Casa Inteligente* (`com.positivo.casainteligente`), confirmed by
  the owner on 2026-11-13. Positivo's devices are Tuya modules on Tuya's cloud under
  Positivo's own app keys, so the core Tuya integration cannot see an account from that app.
- **Integration path**: re-pair the lamp in the *Smart Life* app (remove it from Positivo's
  app first; a Tuya module joins either app), then add the core
  [Tuya](https://www.home-assistant.io/integrations/tuya/) integration, which links the Smart
  Life account by QR code (cloud). The only Positivo-specific integration,
  `rgsilva/homeassistant-positivo`, was rejected: archived since 2022-11, no bulb support,
  and it signs in with keys extracted from Positivo's app.
- **Status**: *candidate*. On 2026-11-13 it was no longer on the network: no lease, and its
  last address did not answer.
