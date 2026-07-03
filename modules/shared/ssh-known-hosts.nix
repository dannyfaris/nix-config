# ssh-known-hosts — fleet host identities as declared trust (#517).
#
# Each fleet host's ed25519 public host key is committed at
# hosts/<name>/ssh_host_ed25519_key.pub and pinned here into the
# system-wide known-hosts set (`/etc/ssh/ssh_known_hosts` on both
# platforms — the option shape is identical on NixOS and nix-darwin).
# Cross-host SSH then never TOFU-prompts, and a reinstalled host (new
# key) fails loudly instead of silently re-trusting — TOFU's weakest
# moment converted into a declared, reviewable identity (whitelist >
# blanket). Public keys are safe to publish; this is the same material
# sops-nix derives host age keys from.
#
# Entries are keyed by bare MagicDNS name — the tailscale search domain
# expands them on every host, and the bare form keeps the tailnet
# identifier out of this public repo. Non-tailnet fallback paths (LAN
# IP, EC2 DNS) are deliberately NOT pinned: they're break-glass
# (~/.ssh/config.local per ADR-010), the EC2 name is dynamic, and the
# operator chose not to commit fleet IPs.
#
# nixos-vm is deliberately absent (excluded as a destination, #517).
# A new fleet host adds its committed pubkey + one entry here at
# bring-up.
{
  programs.ssh.knownHosts = {
    neptune.publicKeyFile = ../../hosts/neptune/ssh_host_ed25519_key.pub;
    mercury.publicKeyFile = ../../hosts/mercury/ssh_host_ed25519_key.pub;
    metis.publicKeyFile = ../../hosts/metis/ssh_host_ed25519_key.pub;
  };
}
