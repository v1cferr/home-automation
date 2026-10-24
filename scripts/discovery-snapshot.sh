#!/usr/bin/env bash
# Passive-first snapshot of what the LAN announces, using the same mechanisms Home Assistant
# uses (mDNS, one SSDP M-SEARCH, the neighbor table). No port scans, no authentication.
#
# The output contains private addresses and MACs: write it under local/ (git-ignored), e.g.
#   scripts/discovery-snapshot.sh > local/discovery-$(date +%F).txt
set -euo pipefail

iface=${1:-$(ip route show default | awk '{print $5; exit}')}
src=$(ip -4 -o addr show dev "$iface" | awk '{split($4, a, "/"); print a[1]; exit}')

echo "# interface: $iface ($src)"
echo
echo "## mDNS services (avahi-browse, 10 s)"
timeout 10 avahi-browse --all --terminate --resolve --parsable 2>/dev/null |
  awk -F';' -v i="$iface" '$1 == "=" && $2 == i && $3 == "IPv4" {print $5, $7, $8 ":" $9}' |
  sort -u || true

echo
echo "## SSDP responders (one M-SEARCH ssdp:all, 5 s)"
python3 -I - "$src" <<'EOF'
import socket, sys, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind((sys.argv[1], 0))
s.settimeout(0.5)
s.sendto(b'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\n'
         b'MX: 3\r\nST: ssdp:all\r\n\r\n', ("239.255.255.250", 1900))
seen, end = {}, time.time() + 5
while time.time() < end:
    try:
        data, (ip, _) = s.recvfrom(8192)
    except socket.timeout:
        continue
    for line in data.decode(errors="ignore").split("\r\n"):
        if line.upper().startswith("SERVER:"):
            seen.setdefault(ip, set()).add(line.split(":", 1)[1].strip())
for ip, servers in sorted(seen.items()):
    print(ip, "|", "; ".join(sorted(servers)))
EOF

echo
echo "## Neighbors matched against Home Assistant's DHCP discovery table"
if docker inspect homeassistant >/dev/null 2>&1; then
  ip neigh show dev "$iface" | awk '$1 ~ /\./ && $3 ~ /:/ {print $1, $3}' |
    docker exec -i homeassistant python3 -c '
import fnmatch, sys
from homeassistant.generated.dhcp import DHCP
for line in sys.stdin:
    ip, mac = line.split()
    m = mac.replace(":", "").upper()
    hits = sorted({d["domain"] for d in DHCP if fnmatch.fnmatch(m, d.get("macaddress", "-"))})
    print(ip, mac, ",".join(hits) or "-")
'
else
  echo "(homeassistant container not running; skipped)"
fi
