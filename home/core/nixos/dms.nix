# Dank Material Shell — DISABLED.
#
# DMS was attempted in slice 3 (ADR-028) and abandoned during slice 5
# after upstream version-skew issues across DMS / quickshell / niri-flake
# made the shell unviable on this stack (see #67 for the incident,
# PR #68 for the niri.service fix that exposed the deeper problem, #69
# for the niri-only baseline close-out, #70 for the scheduled cleanup
# pass that removes this module entirely).
#
# All four switches set false to make the disable explicit; the niri
# config no longer carries DMS-injected includes or enableKeybinds binds.
# This module is retained in disabled state until #70's cleanup deletes
# it.
_: {
  programs.dank-material-shell = {
    enable = false;
    systemd.enable = false;
    enableDynamicTheming = false;
    niri.enableKeybinds = false;
  };
}
