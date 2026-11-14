# Devices

One page per device: evidence, how Home Assistant can see it, the integration path, and its
current status. How devices are found and what each status means:
[discovery.md](../discovery.md).

| Device                                          | Status                    | Integration                                       |
| ----------------------------------------------- | ------------------------- | ------------------------------------------------- |
| [Amazon Echo](amazon-echo.md)                   | *requires authentication* | Alexa Devices (core, cloud)                       |
| [Wi-Fi lamp](wifi-lamp.md)                      | *candidate* (offline)     | Tuya (core, cloud) after re-pairing in Smart Life |
| [Generic Android TV box](android-tv-box.md)     | *candidate*               | Kodi (core, local) once LibreELEC boots           |
| [Samsung TV](samsung-tv.md)                     | *not found* (powered off) | Samsung Smart TV (core, local)                    |
| [Smart electric shower](zagonel-shower.md)      | *integrated* (read-only)  | `zagonel` (community, cloud)                      |
| [Tower fan](tower-fan.md)                       | *integrated*              | Midea (core, local; cloud key once)               |
| [Host's own media server](host-media-server.md) | ignored                   | Not a home device                                 |

Add a page when a new device shows up, and update this table when a status changes.
