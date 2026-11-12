#!/usr/bin/env bash
# Installs the community Zagonel integration into the running Home Assistant container, at
# the exact commit that was reviewed (see docs/discovery.md, "Smart electric shower").
#
# The upstream repository carries no license, so its code is fetched here instead of being
# vendored into this public repository; homeassistant/custom_components/ stays git-ignored.
# Bumping the pin means reading the upstream diff first: this integration is read-only today
# and must stay that way for a heating appliance.
#
# Restart Home Assistant afterwards: custom integrations are only loaded at startup.
set -euo pipefail

repo=alexandrepossebom/zagonel-ha
commit=fb5c783a40a0de2c6bdef2021ed0d591d52bc58f
domain=zagonel
container=${1:-homeassistant}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl --fail --silent --show-error --location \
  "https://codeload.github.com/$repo/tar.gz/$commit" |
  tar -xz -C "$tmp" --strip-components=1

src=$tmp/custom_components/$domain
[ -f "$src/manifest.json" ] || { echo "no $domain integration in $repo@$commit" >&2; exit 1; }

# The config directory is root-owned on the host, so the copy goes through the container.
docker exec "$container" mkdir -p /config/custom_components
docker exec "$container" rm -rf "/config/custom_components/$domain"
docker cp --quiet "$src" "$container:/config/custom_components/$domain"
docker exec "$container" chown -R root:root "/config/custom_components/$domain"
docker exec "$container" chmod 755 /config/custom_components

echo "installed $repo@${commit:0:7} into $container:/config/custom_components/$domain"
echo "restart Home Assistant to load it: docker compose restart homeassistant"
