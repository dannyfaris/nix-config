# Inbound SSH (sshd) on Darwin: launchd-managed daemon shipped by
# macOS itself; nix-darwin's `services.openssh.enable` toggles macOS's
# Remote Login (Settings → General → Sharing).
#
# Unlike the NixOS module, nix-darwin's `services.openssh` is a thin
# wrapper — it does NOT expose `openFirewall`,
# `settings.PasswordAuthentication`, or the other knobs the NixOS
# sshd.nix sets directly. Posture hardening (key-only, no root, no
# keyboard-interactive) lands via `services.openssh.extraConfig`, a
# typed `lines` option that nix-darwin merges into
# `/etc/ssh/sshd_config.d/100-nix-darwin.conf`. This is preferable to
# a bespoke `environment.etc` drop-in because sshd's drop-in glob is
# lexically ordered and the first occurrence of a keyword wins — a
# `99-…conf` drop-in would actually be read *after* `100-nix-darwin.conf`
# (because `'9' > '1'` in ASCII order) and could be shadowed by any
# future occupant of `extraConfig`.
#
# Sibling to modules/nixos/sshd.nix (NixOS-only options) — kept
# separate rather than shared because the surfaces diverge enough that
# extracting a common kernel would add more abstraction than it
# removes.
_: {
  services.openssh = {
    enable = true;
    extraConfig = ''
      # Hardened SSH posture — key-only, no root, no password.
      # Mirrors the stance in modules/nixos/sshd.nix.
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
    '';
  };
}
