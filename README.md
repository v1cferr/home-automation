# home-automation

Self-hosted, local-first home automation built on
[Home Assistant Container](https://www.home-assistant.io/installation/linux/#docker-compose).
The current phase is **bootstrap, device discovery and diagnostics**: no automations yet.

## Quick start

Requirements: Docker Engine with the Compose plugin, on a Linux host attached to the same
LAN as the devices.

```sh
cp .env.example .env            # only if the state should not live in /var/lib/home-assistant
docker compose config --quiet   # validate
docker compose up -d
docker compose logs -f homeassistant
```

Open <http://localhost:8123> and complete the onboarding (create the owner account, set the
home location). The first start takes about two minutes while Home Assistant installs its
dependencies into the state directory's `deps/`.

Stop it with `docker compose down`. The `stop_grace_period` gives the recorder time to close
the database cleanly.

## Layout

```text
.
├── compose.yaml            # the single Home Assistant service
├── .env.example            # HA_STATE_DIR: where runtime state lives on the host
├── config/                 # reviewed YAML, mounted read-only into /config
│   ├── configuration.yaml  # bootstrap: default_config and the packages loader
│   └── packages/           # one file per device or topic
├── scripts/                # discovery snapshot, pinned community integration install
├── docs/                   # architecture, discovery method, troubleshooting
│   └── devices/            # one page per device, with a status index
└── local/                  # private diagnostics (addresses, MACs); git-ignored
```

Runtime state (database, `.storage`, logs, backups, `deps`, `custom_components`,
`secrets.yaml`) is not in this tree: it lives in `HA_STATE_DIR`, by default
`/var/lib/home-assistant`, owned by root. Why the split:
[docs/architecture.md](docs/architecture.md), "Configuration vs. state".

## Documentation

- [docs/architecture.md](docs/architecture.md): design decisions, persistence, security,
  migration to a 24/7 server.
- [docs/discovery.md](docs/discovery.md): how devices are discovered and how to tell an
  announced service from a configured integration.
- [docs/devices/](docs/devices/README.md): each device's evidence, integration path and
  status.
- [docs/troubleshooting.md](docs/troubleshooting.md): known errors and how to diagnose
  devices that do not show up.

## Public repository rules

Never commit private addresses, MAC addresses, SSIDs, device identifiers, tokens or
passwords. Diagnostics go to `local/`, and secrets stay in `secrets.yaml` inside the state
directory, outside the repository.

The admin API token is not in this repository either: on the development host it comes from
the host's sops vault at `/run/secrets/home_assistant_token` (readable by the user only).
