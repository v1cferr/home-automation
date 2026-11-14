# Architecture

## Overview

One container, `homeassistant`, running the official image
`ghcr.io/home-assistant/home-assistant:stable` with Docker Compose. Nothing else runs yet:
MQTT, ESPHome, Matter Server and n8n are deliberately left out until a device or an
automation needs them.

```text
LAN (single broadcast domain)
 ├── Wi-Fi devices (lamp, shower, fan, Echo, ...)
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

### Updates

The compose pins `:stable`, and the host pulls it every day at 05:00 and recreates the
container only when the image changed. That timer is declared in the host's NixOS
configuration (dotfiles, `modules/nixos/services/home-assistant.nix`), not here, for the same
reason as the reverse proxy below. The owner chose always-latest on 2026-11-13, knowing that
monthly releases can carry breaking changes; going back one release means pinning the
previous tag in `compose.yaml`.

### Configuration vs. state

The container's `/config` is bind-mounted from a host directory outside this repository,
`HA_STATE_DIR` (default `/var/lib/home-assistant`, see `.env.example`). The reviewed YAML in
`config/` is then mounted read-only over it: `config/configuration.yaml` and
`config/packages/`. Everything else in `/config` is state, kept out of Git on purpose:

| Path                                              | Why                                                                          |
| ------------------------------------------------- | ---------------------------------------------------------------------------- |
| `.storage/`                                       | UI-managed config: auth, users, config entries, device and entity registries |
| `home-assistant_v2.db*`                           | Recorder history (SQLite + WAL)                                              |
| `secrets.yaml`                                    | Secrets referenced with `!secret`                                            |
| `*.log*`                                          | Logs contain addresses and identifiers                                       |
| `backups/`, `deps/`, `tts/`, `.cloud/`            | Generated or private                                                         |
| `automations.yaml`, `scripts.yaml`, `scenes.yaml` | UI-edited; they embed device IDs. Revisit when automations exist             |

`configuration.yaml` is the file Home Assistant generated on first start, plus one addition.
Keep `default_config:` in it: it loads `zeroconf`, `ssdp`, `dhcp` and the rest of the
discovery stack.

### Configuration layout

YAML that this repository owns goes in `config/packages/`, one file per device or topic, loaded by
`homeassistant: packages: !include_dir_named packages`. A package groups the helpers and
automations of one feature and refers to entities only by `entity_id`, never by device ID,
so it can be public. UI-edited automations stay in the ignored `automations.yaml`.

| Package       | What it holds                                                       |
| ------------- | ------------------------------------------------------------------- |
| `shower.yaml` | Long-shower alert with two threshold helpers, and a monthly summary |

Some settings only exist in `.storage/` and cannot be tracked: the Energy dashboard is one
(the shower is listed there as an individual device for energy and for water). They are
recorded in the docs instead.

The tracked files are owned by the user and edited in the working tree like any other file;
the container sees them read-only. `configuration.yaml` is a single-file mount, which pins
its inode: after a `git checkout` or an editor that replaces the file, restart the container,
which Home Assistant needs to reload YAML anyway. Validate before restarting:
`POST /api/config/core/check_config`.

### Reverse proxy

Remote access goes through the host's Caddy, which already serves a wildcard certificate for
the personal domain and answers `home.<domain>` by proxying to `127.0.0.1:8123`. Caddy only
admits the LAN and the router's WireGuard subnet and returns 403 to everyone else, so a phone
reaches Home Assistant through the VPN and the internet does not reach it at all. That entry
lives in the host's NixOS configuration, not in this repository.

Home Assistant must trust the proxy, or it answers 400 to forwarded requests. Since 2026.10
the HTTP settings are **not** read from `configuration.yaml`: they are migrated once into
`.storage/http` and managed from the UI or the `http/config/configure` WebSocket command,
which stages a *pending* config, restarts, and reverts to the *stable* one after a few minutes
unless it is promoted. A leftover `http:` block in YAML only raises a repair issue. The values
in use:

```yaml
use_x_forwarded_for: true
trusted_proxies: [127.0.0.1, ::1]
```

They travel with `.storage`, so a migration keeps them; re-check them if the proxy moves to
a different host.

Home Assistant must also **advertise** the proxy's address. Left unset, its internal and
external URLs default to `http://<host IP>:8123`, which is what it announces over mDNS
(`_home-assistant._tcp`) and what the Companion app picks up when it finds the server on the
LAN. The firewall keeps 8123 closed to other machines, so the app timed out without a single
request reaching Caddy. Both URLs are set to `https://home.<domain>` (Settings > System >
Network, or `config/core/update` over WebSocket; stored in `.storage/core.config`), and the
mDNS record carries the new value after a restart. The phone uses the same name on the LAN
and through WireGuard, since the router answers `*.<domain>` with the host's LAN address.

### Restart and shutdown

`restart: unless-stopped` brings Home Assistant back after a crash or a host reboot, but not
after an explicit `docker compose stop`. `stop_grace_period: 2m` replaces Docker's 10 s
default so the recorder can commit and close SQLite; a measured stop takes about 5 s.

The image's init (s6-overlay) runs as PID 1 and forwards the stop signal, so `init: true` is
not needed.

## Security

- Not exposed to the internet: no port forwarding and no Nabu Casa remote access. The
  reverse proxy admits only the LAN and the WireGuard subnet.
- With host networking, direct access to 8123 depends on the host firewall. On the current
  development host 8123 stays closed, so other devices go through the proxy on 443.
- The container runs as root (the image requires it), so the state directory is owned by
  root on the host. The mounts from `config/` are read-only, so the container cannot
  rewrite tracked files.
- Discovery listeners (5353/udp, 1900/udp) must be allowed by the host firewall for
  unsolicited announcements to arrive.

## Migrating to a 24/7 server

State is entirely in `HA_STATE_DIR`, so a migration is:

1. On the old host: `docker compose down` (clean database shutdown).
2. Copy the directory preserving ownership, e.g.
   `sudo rsync -aHAX /var/lib/home-assistant/ newhost:/var/lib/home-assistant/`.
   Alternatively create a backup in the UI and restore it during onboarding on the new host.
3. On the new host: clone this repository, put the state in place (set `HA_STATE_DIR` in
   `.env` if it is not the default), `docker compose up -d`.

Requirements for the new host:

- Same LAN segment (or VLAN) as the IoT devices, wired preferably, with a DHCP reservation.
- Firewall allowing 5353/udp and 1900/udp inbound, and 8123/tcp from the LAN only.
- On NixOS, express the above declaratively (`virtualisation.docker`,
  `networking.firewall`), and optionally run the stack from a systemd unit or
  `virtualisation.oci-containers` instead of an interactive `docker compose up`.
- Pin the image to a version tag instead of `stable` once updates should be deliberate.
