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

  # Under persist enforcement the host identity keys live PHYSICALLY on the
  # neededForBoot /persist filesystem — not bind-mounted onto /etc/ssh from an
  # impermanence FILE entry. Nothing read before the stage-2 mount units may
  # ride a bind mount, and sops-nix derives its age identity from these paths
  # (see modules/nixos/sops.nix) to decrypt neededForUsers secrets in early
  # boot; a key reachable only after a bind mount is the #553 auth-lockout
  # class, killed here by moving the keys off the auth path entirely. Mirrors
  # the upstream default's two-key shape, so persist hosts get exactly these
  # (option defaults never merge with definitions) and every other host keeps
  # the stock /etc/ssh default. On a fresh persist host sshd-keygen (multi-user,
  # after sops) generates these into /persist; first-boot sops instead depends
  # on the bootstrap key INJECTION staged by `just gen-host-key`/`bootstrap`
  # (the justfile interlock asserts the staged tree matches these paths). Gated
  # on persist.enable (adopting hosts only — see modules/nixos/persist.nix).
  services.openssh.hostKeys = lib.mkIf config.persist.enable [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      bits = 4096;
      path = "/persist/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
    }
  ];
}
