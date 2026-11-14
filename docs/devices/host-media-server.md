# Host's own media server

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

The UI lists a *DLNA Digital Media Server* under *Discovered*: that is the development
host's Jellyfin answering SSDP, not a home device. It had been configured by mistake; on
2026-11-13 the entry was deleted and the rediscovery marked *Ignored*, so it stays hidden.
