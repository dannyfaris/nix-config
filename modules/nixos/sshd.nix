# Inbound SSH (sshd): key-only, no root, no password fallback, and an
# explicit account whitelist. CLAUDE.md §Deliberate stances calls for
# "whitelist > blanket" on hardened surfaces; without `AllowGroups`, any
# future user with an authorised key would be permitted by default.
# Pinning to `wheel` mirrors the existing admin-group convention in
# modules/nixos/users.nix and keeps the door open to a second admin
# account without re-touching this file. A non-wheel account that should
# be SSH-reachable is a deliberate choice and would need to add itself
# here.
{ config, lib, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";

      # Account whitelist — only members of `wheel` may authenticate.
      AllowGroups = [ "wheel" ];

      # Tightened from upstream (6 / 120s). Key-only auth doesn't need 6
      # tries, and dropping pre-auth connections fast reduces the cost
      # of port-scan noise.
      MaxAuthTries = 3;
      LoginGraceTime = "30s";

      # No repo workflow uses `ssh -L`/`-R`. Pin explicitly rather than
      # inheriting upstream `yes`.
      AllowTcpForwarding = "no";

      # Upstream default is already `false`; pin so a future nixpkgs
      # change can't silently flip it.
      X11Forwarding = false;
    };
  };

  # Persist whitelist (module-owns-its-state, docs/design/ephemeral-root.md):
  # host identity keys — regenerating them breaks every peer's known_hosts
  # and the sops-nix age-key derivation. Explicit key files, not the /etc/ssh
  # dir: the dir also holds activation-managed config symlinks that must not
  # be shadowed by a bind mount. Gated on persist.enable (adopting hosts
  # only — see modules/nixos/persist.nix).
  environment.persistence."/persist".files = lib.mkIf config.persist.enable [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
}
