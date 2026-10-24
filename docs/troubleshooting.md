# Troubleshooting

## Status checks

```sh
docker compose ps
docker compose logs --tail 100 homeassistant
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8123/   # 200 or 302 when up
```

The full log is also at `homeassistant/home-assistant.log`.

## Bluetooth errors at startup

```
ERROR [habluetooth.manager] Missing required permissions for Bluetooth management ...
ERROR [habluetooth.scanner] hci0 (...): Failed to force stop scanner
```

Expected. `default_config:` loads Bluetooth, which finds the host adapter but has no D-Bus
socket and no `NET_ADMIN` capability; Docker grants `NET_RAW` by default (see
[architecture.md](architecture.md#no-privileged-true)). The retries back off and do not
affect anything else.

To silence it while Bluetooth is out of scope, disable the auto-created *Bluetooth* entry in
Settings > Devices & services. To actually use Bluetooth later, mount `/run/dbus:/run/dbus:ro`
and add `cap_add: [NET_ADMIN]`, which is still far narrower than `privileged: true`.

## The UI is not reachable from another device

With `network_mode: host` there is no port mapping, so the host firewall decides. On NixOS:

```sh
sudo iptables -S nixos-fw | grep 8123   # no output: 8123 is closed to the LAN
```

Opening it is a declarative change in the host configuration, ideally restricted to the
LAN subnet. Never forward 8123 on the router.

## A device does not show up

Work through these in order and record the evidence in `local/`.

1. **Is it on the network at all?** Look for it in the router's DHCP leases. If it is not
   there, it is offline or on a different network.
2. **Same broadcast domain?** Discovery only works within one L2 segment. Check that the
   host and the device are on the same subnet, that the SSID is bridged to the LAN (not a
   guest network) and that client isolation is off for that SSID (OpenWrt: `option isolate`
   in `/etc/config/wireless`).
3. **Does the host receive multicast?** `avahi-browse -art` should list other devices on the
   LAN (phones, TVs, speakers). If it only lists the host itself, multicast is filtered
   somewhere (Wi-Fi multicast-to-unicast, IGMP snooping, firewall).
4. **Firewall.** Inbound 5353/udp and 1900/udp must be accepted. Also note that replies to a
   *broadcast* or *multicast* query come back as unicast from the device's address, which a
   stateful firewall does not associate with the outgoing query. Integrations that discover
   by broadcasting (TP-Link, WiZ, Tuya local and others) can therefore miss devices on a
   host firewall that drops unsolicited UDP. If a known device is missing and its
   integration uses broadcast discovery, add it manually by IP before suspecting the device.
5. **Does Home Assistant support it?** Find the brand on
   <https://www.home-assistant.io/integrations/>. If the only control path is a vendor
   cloud, discovery will not find it; the integration is added manually and authenticated.
6. **Trigger DHCP discovery.** Power-cycle the device while Home Assistant is running; the
   DHCP watcher sees the new lease request.
7. **Debug logs.** Temporarily, in `configuration.yaml`:

   ```yaml
   logger:
     default: warning
     logs:
       homeassistant.components.zeroconf: debug
       homeassistant.components.ssdp: debug
       homeassistant.components.dhcp: debug
   ```

   Restart, reproduce, and remove the block afterwards: debug logs contain addresses.

## Clean shutdown

`docker compose down` waits up to `stop_grace_period` (2 min) for the recorder. If a stop
ever hits the limit, the next start logs that the database was not shut down cleanly; check
`docker compose logs` before raising the limit.
