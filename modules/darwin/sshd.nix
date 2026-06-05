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
# Posture parity with modules/nixos/sshd.nix's #198 hardening lands here
# too (#233): an explicit account whitelist plus tightened auth limits.
# The whitelist mechanism diverges from NixOS by necessity — see the
# AllowUsers note below.
let
  operator = import ../../lib/operator.nix;
in
{
  services.openssh = {
    enable = true;
    extraConfig = ''
      # Hardened SSH posture — key-only, no root, no password.
      # Mirrors the stance in modules/nixos/sshd.nix.
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no

      # Account whitelist. NixOS uses `AllowGroups wheel`; Darwin pins the
      # operator by name instead — mac-mini is a single-operator box, and
      # AllowUsers makes no assumption about macOS-managed group state
      # (admin/staff aren't the NixOS `wheel`). A second SSH-reachable
      # account would be a deliberate one-line addition here. Name sourced
      # from lib/operator.nix so it can't drift from the user declaration.
      AllowUsers ${operator.name}

      # Tightened from upstream (6 / 120s) — key-only auth needs neither,
      # and a fast pre-auth drop cuts port-scan cost. Matches the NixOS side.
      MaxAuthTries 3
      LoginGraceTime 30s

      # mac-mini is the operator's SSH *client* into the Linux fleet; no
      # workflow uses inbound `ssh -L`/`-R` to it. Pin off rather than
      # inherit upstream `yes`. X11Forwarding is already off upstream; pin
      # it explicitly (explicit > implicit), matching the NixOS side.
      AllowTcpForwarding no
      X11Forwarding no
    '';
  };
}
