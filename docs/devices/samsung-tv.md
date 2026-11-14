# Samsung TV (living room)

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

- **Evidence**: the router reserves an address for a client named `TV-Samsung-Sala`, whose MAC
  prefix the IEEE registry assigns to *Samsung Electronics*. On 2026-11-13 it was off: it
  held no lease and did not answer, so nothing on the network could be checked.
- **Home Assistant discovery**: expected once it is on. Samsung TVs announce themselves over
  SSDP, which the core [Samsung Smart TV](https://www.home-assistant.io/integrations/samsungtv/)
  integration matches; the TV then asks on screen to allow the connection.
- **Integration path**: that core integration, local. Turning the TV on over the network
  needs Wake-on-LAN or SmartThings, since a TV in standby drops off Wi-Fi.
- **Status**: *not found* (powered off). Turn it on and check *Discovered*.
