# Roaming identity privacy (#753, #754). A laptop shows one identity to many
# networks, so anything it broadcasts unchanged makes its appearances at
# home, at a café and at an airport linkable to one machine — and, when the
# identifier is human-meaningful, to its operator. Covers the association
# path; NetworkManager already randomises scan probes by default
# (wifi.scanRandMacAddress).
{
  # Keyed on the SSID, not the connection profile, so the address survives
  # a forget-and-rejoin; the mode alternatives are weighed in #753.
  #
  # Derived from /var/lib/NetworkManager/secret_key *and* /etc/machine-id
  # (v2 secret keys hash both in). Both sit on the persist whitelist and
  # both are load-bearing: lose either and these addresses reshuffle — as
  # do the IPv6 stable-privacy identities seeded from the same key.
  networking.networkmanager.wifi.macAddress = "stable-ssid";

  # DHCP option 12, and its DHCPv6 FQDN equivalent (option 39) — one gate
  # covers both. Left alone, NetworkManager announces the host's name to
  # every DHCP server it meets: an identifier that outlives every MAC change
  # above and, unlike a MAC, describes itself (#754).
  #
  # 0, not false. NetworkManager parses [connection] global defaults with
  # strtoll, so a boolean literal fails to parse, falls back to the
  # deprecated per-family property — which defaults to true — and the name
  # keeps going out. Nothing logs it and `NetworkManager --print-config`
  # echoes the file either way, so only a runtime probe catches it (#303).
  #
  # Escape hatch for a network that insists on a name:
  #   nmcli connection modify <ssid> ipv4.dhcp-send-hostname yes
  networking.networkmanager.connectionConfig = {
    "ipv4.dhcp-send-hostname" = 0;
    "ipv6.dhcp-send-hostname" = 0;
  };
}
