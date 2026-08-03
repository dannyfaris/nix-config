# Roaming Wi-Fi MAC privacy (#753). A laptop shows one link-layer identity
# to many networks, so a fixed MAC makes its appearances at home, at a café
# and at an airport linkable to one machine by anyone in radio range.
# NetworkManager already randomises scan probes by default
# (wifi.scanRandMacAddress); this covers the half it does not — the address
# used to associate.
{
  # Keyed on the SSID, not the connection profile, so the address survives
  # a forget-and-rejoin; the mode alternatives are weighed in #753.
  #
  # Derived from /var/lib/NetworkManager/secret_key *and* /etc/machine-id
  # (v2 secret keys hash both in). Both sit on the persist whitelist and
  # both are load-bearing: lose either and these addresses reshuffle — as
  # do the IPv6 stable-privacy identities seeded from the same key.
  networking.networkmanager.wifi.macAddress = "stable-ssid";
}
