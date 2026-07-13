# sops-nix configuration for Darwin hosts.
#
# Darwin hosts declare no sops secrets — the fleet's only secret
# (`dbf-password`) is NixOS-only — so no Darwin host holds a
# machine-decryption identity. What `age.keyFile` wires is the
# *operator's* editing identity: the standalone operator age key at
# `~/.config/sops/age/keys.txt`, the fleet's edit + disaster-recovery
# root (docs/design/fleet-key-custody.md). It has no SSH ancestry —
# populated from the vault (1Password item "sops age key - operator"),
# never derived from an SSH keypair.
#
# Distinct from the NixOS-side `sops.age.sshKeyPaths` shape: NixOS
# secret-holders decrypt at activation via the host's
# `/etc/ssh/ssh_host_ed25519_key` (a host identity). Migration
# trigger: if a Darwin host ever declares a sops secret, it needs a
# real machine-decryption identity of its own and the
# host-key-vs-operator-key question reopens — see
# fleet-key-custody.md §Future possibilities.
#
# No `secrets.dbf-password.neededForUsers`: macOS owns the login
# password (via the standard macOS account creation flow), not the
# config. Nothing here corresponds to NixOS's
# `users.users.dbf.hashedPasswordFile` chain.
_:

let
  operator = import ../../lib/operator.nix;
in
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "${operator.darwinHome}/.config/sops/age/keys.txt";
  };
}
