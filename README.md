# home-automation

Self-hosted, local-first home automation built on
[Home Assistant Container](https://www.home-assistant.io/installation/linux/#docker-compose).
The current phase is **bootstrap, device discovery and diagnostics**: no automations yet.

## Quick start

Requirements: Docker Engine with the Compose plugin, on a Linux host attached to the same
LAN as the devices.

```sh
docker compose config --quiet   # validate
docker compose up -d
docker compose logs -f homeassistant
```

Open <http://localhost:8123> and complete the onboarding (create the owner account, set the
home location). The first start takes about two minutes while Home Assistant installs its
dependencies into `homeassistant/deps`.

Stop it with `docker compose down`. The `stop_grace_period` gives the recorder time to close
the database cleanly.

## Layout

| Path | What | In Git |
| --- | --- | --- |
| `compose.yaml` | The single Home Assistant service | yes |
| `homeassistant/` | The container's `/config`: all persistent state | only `configuration.yaml` |
| `scripts/discovery-snapshot.sh` | Non-invasive LAN discovery snapshot | yes |
| `local/` | Private diagnostics (addresses, MACs, hostnames) | no |
| `docs/` | Architecture, discovery method, troubleshooting | yes |

## Documentation

- [docs/architecture.md](docs/architecture.md): design decisions, persistence, security,
  migration to a 24/7 server.
- [docs/discovery.md](docs/discovery.md): how devices are discovered and how to tell an
  announced service from a configured integration.
- [docs/troubleshooting.md](docs/troubleshooting.md): known errors and how to diagnose
  devices that do not show up.

## Public repository rules

Never commit private addresses, MAC addresses, SSIDs, device identifiers, tokens or
passwords. Diagnostics go to `local/`, and secrets stay in `homeassistant/secrets.yaml`
(ignored).

The admin API token is not in this repository either: on the development host it comes from
the host's sops vault at `/run/secrets/home_assistant_token` (readable by the user only).
