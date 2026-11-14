# Amazon Echo

Part of the [device inventory](README.md). Discovery stages and the status vocabulary:
[discovery.md](../discovery.md). Addresses and identifiers are intentionally absent: raw
evidence lives in `local/`.

- **Evidence**: announces `_spotify-connect._tcp`. Its Spotify Connect `getInfo` response
  (unauthenticated, read-only, the same request any Spotify client makes) reports brand
  *Amazon*, model *Echo Dot*.
- **Home Assistant discovery**: none expected. No core integration matches
  `_spotify-connect._tcp`, and Echo devices are not controlled over the LAN.
- **Integration path**: the core
  [Alexa Devices](https://www.home-assistant.io/integrations/alexa_devices/) integration
  (present in the installed version). It is cloud-based and needs the Amazon account
  credentials and a one-time code, entered in the UI by the account owner. Never store them
  in this repository.
- **Known bug (2026.10.x)**: the setup spinner never ends and the log shows
  `InvalidUrlClientError: /ax/claim?...`. Amazon now routes some sign-ins through a passkey
  page with a relative form action that `aioamazondevices` 16.3.2 cannot follow, so the
  credentials are never even submitted
  ([core#187595](https://github.com/home-assistant/core/issues/187595)). The bump to 16.9.1
  ([core#187985](https://github.com/home-assistant/core/pull/187985)) was merged into `dev`
  on 2026-10-22 without a backport, so it ships with 2026.11. Retry after updating the image.
  Updated on 2026-11-13: 2026.11.1 ships `aioamazondevices` 17.2.7.
- **Status**: *requires authentication*. The bug above is fixed in the installed version; the
  owner's sign-in is what remains.
