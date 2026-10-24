# Architecture

## Overview

One container, `homeassistant`, running the official image
`ghcr.io/home-assistant/home-assistant:stable` with Docker Compose. Nothing else runs yet:
MQTT, ESPHome, Matter Server and n8n are deliberately left out until a device or an
automation needs them.

```
LAN (single broadcast domain)
 ├── Wi-Fi devices (lamp, shower, Echo, ...)
 └── host ── network_mode: host ── homeassistant :8123
                                     └── ./homeassistant  ->  /config
```

## Decisions

### Host networking

Zeroconf (mDNS, `224.0.0.251:5353`), SSDP (`239.255.255.250:1900`) and DHCP discovery listen
for multicast and broadcast traffic that a Docker bridge does not forward. `network_mode: host`
puts Home Assistant directly on the LAN interface, which is what the official installation
guide uses.

Side effect: there is no `ports:` mapping, so reachability on 8123 is decided by the host
firewall, not by Compose.

### No `privileged: true`

The official example sets `privileged: true` so the container can reach USB radios and
Bluetooth. This phase uses neither, and network discovery does not need it: Docker's default
capability set already includes `NET_RAW`, which the DHCP watcher uses. Privileged mode would
give the container every capability and every host device, so it stays off.

Consequence: the Bluetooth integration (part of `default_config:`) finds the host's adapter
over netlink but cannot manage it without D-Bus and `NET_ADMIN`, and logs errors. See
[troubleshooting.md](troubleshooting.md#bluetooth-errors-at-startup).

### Configuration vs. state

The container's `/config` is bind-mounted from `./homeassistant`. The directory is git-ignored
as a whole and only reviewed files are allowlisted back (`configuration.yaml` today). Ignored
on purpose:

| Path | Why |
| --- | --- |
| `.storage/` | UI-managed config: auth, users, config entries, device and entity registries |
| `home-assistant_v2.db*` | Recorder history (SQLite + WAL) |
| `secrets.yaml` | Secrets referenced with `!secret` |
| `*.log*` | Logs contain addresses and identifiers |
| `backups/`, `deps/`, `tts/`, `.cloud/` | Generated or private |
| `automations.yaml`, `scripts.yaml`, `scenes.yaml` | UI-edited; they embed device IDs. Revisit when automations exist |

`configuration.yaml` is the file Home Assistant generated on first start, unchanged. Keep
`default_config:` in it: it loads `zeroconf`, `ssdp`, `dhcp` and the rest of the discovery
stack.

### Restart and shutdown

`restart: unless-stopped` brings Home Assistant back after a crash or a host reboot, but not
after an explicit `docker compose stop`. `stop_grace_period: 2m` replaces Docker's 10 s
default so the recorder can commit and close SQLite; a measured stop takes about 5 s.

The image's init (s6-overlay) runs as PID 1 and forwards the stop signal, so `init: true` is
not needed.

## Security

- Not exposed to the internet: no port forwarding, no reverse proxy, no Nabu Casa remote
  access configured.
- With host networking, LAN access to 8123 depends on the host firewall. On the current
  development host the firewall does not allow 8123, so the UI is reachable from the host
  only. Opening it to the LAN is a separate, explicit firewall change.
- The container runs as root (the image requires it), so files under `homeassistant/` are
  owned by root on the host.
- Discovery listeners (5353/udp, 1900/udp) must be allowed by the host firewall for
  unsolicited announcements to arrive.

## Migrating to a 24/7 server

State is entirely in `./homeassistant`, so a migration is:

1. On the old host: `docker compose down` (clean database shutdown).
2. Copy the directory preserving ownership, e.g.
   `sudo rsync -aHAX homeassistant/ newhost:/srv/home-automation/homeassistant/`.
   Alternatively create a backup in the UI and restore it during onboarding on the new host.
3. On the new host: clone this repository, put the state in place, `docker compose up -d`.

Requirements for the new host:

- Same LAN segment (or VLAN) as the IoT devices, wired preferably, with a DHCP reservation.
- Firewall allowing 5353/udp and 1900/udp inbound, and 8123/tcp from the LAN only.
- On NixOS, express the above declaratively (`virtualisation.docker`,
  `networking.firewall`), and optionally run the stack from a systemd unit or
  `virtualisation.oci-containers` instead of an interactive `docker compose up`.
- Pin the image to a version tag instead of `stable` once updates should be deliberate.
