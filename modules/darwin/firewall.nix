# Host firewall on macOS — the Application Layer Firewall (ALF).
#
# Imported via foundation.nix so the guarantee holds for every Darwin
# host unconditionally. Mirrors the role of modules/nixos/firewall.nix
# (which sets `networking.firewall.enable = true` on NixOS).
#
# `networking.applicationFirewall.enable = true` toggles the macOS
# ALF on, with the default-safe posture: signed binaries (system +
# notarised third-party) pass; unsigned binaries prompt on first
# inbound connection. Defaults retained for the rest:
#   - `blockAllIncoming = false` — block-all would shut out our own
#     sshd; not the operator's intent given neptune is also an
#     inbound SSH server.
#   - `allowSigned = true` (default) — signed binaries get implicit
#     pass.
#   - `enableStealthMode = false` (default) — silent ICMP/port-probe
#     drops left off; a host that wants stealth opts in via its own
#     default.nix.
#
# Earlier shape used `system.defaults.alf.globalstate = 1`; that
# option set was removed upstream in favour of the
# `networking.applicationFirewall.*` family (a typed wrapper around
# `socketfilterfw` flags).
_: {
  networking.applicationFirewall.enable = true;
}
