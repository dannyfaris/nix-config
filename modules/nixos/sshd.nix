# Inbound SSH (sshd): key-only, no root, no password fallback, and an
# explicit account whitelist. CLAUDE.md §Deliberate stances calls for
# "whitelist > blanket" on hardened surfaces; without `AllowGroups`, any
# future user with an authorised key would be permitted by default.
# Pinning to `wheel` mirrors the existing admin-group convention in
# modules/nixos/users.nix and keeps the door open to a second admin
# account without re-touching this file. A non-wheel account that should
# be SSH-reachable is a deliberate choice and would need to add itself
# here.
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
}
