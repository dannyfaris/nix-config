# Darwin-side half of the macchina wiring — owns the Apple-logo
# `ascii.txt` and the interactive-shell init that prints the banner at
# every fish shell launch (Ghostty tab, zellij pane, helix `:sh`,
# every login). Mirrors `home/nixos/macchina-shell-init.nix`.
#
# The platform-pure half (`home/shared/macchina.nix`) installs the
# package and writes the Hydrogen theme TOML referencing
# `${config.xdg.configHome}/macchina/ascii.txt`. This file owns the
# Darwin content of that path and the macOS-specific interface
# detection.
#
# `lib.mkBefore` pins the shell-init block ahead of `home/shared/shell.nix`'s
# own `interactiveShellInit` (starship's transient-prompt machinery).
# Both set the same `lib.types.lines` option; equal-priority concatenation
# order tracks import order, which is fragile across host configs.
# mkBefore (priority 500 vs default 1000) lands first in the
# concatenation regardless of import order.
#
# Interface priority for the banner's "Local IP" readout: the
# interface the kernel's routing table reports for the default route,
# read via `route -n get default` (the macOS equivalent of Linux's
# `ip route get`; there is no `ip` command on Darwin). Tailscale's
# Darwin client surfaces its interface as `utun*` rather than the
# fixed `tailscale0` name Linux uses, so we don't special-case it —
# the default-route lookup catches whichever interface is currently
# carrying outbound traffic, which is the most useful signal here.
# Runs without --interface if the lookup fails — Local IP readout is
# simply absent. The `command -q macchina` guard prevents a startup
# error if macchina is transiently missing from PATH.
#
# Apple-logo ASCII uses macchina's own `$N` palette-index escape
# syntax (configured via the Hydrogen theme's `[custom_ascii]` block).
# Each `$N` switches the rendering colour to palette index `N` — the
# multi-stripe layout traditional to the macchina Apple ASCII variant.
{ lib, ... }:
{
  xdg.configFile."macchina/ascii.txt".text = ''
                         ..'
                     ,xNMM.
                   .OMMMMo
                   lMM"
         .;loddo:.  .olloddol;.
       cKMMMMMMMMMMNWMMMMMMMMMM0:
     $2.KMMMMMMMMMMMMMMMMMMMMMMMWd.
     XMMMMMMMMMMMMMMMMMMMMMMMX.
    $3;MMMMMMMMMMMMMMMMMMMMMMMM:
    :MMMMMMMMMMMMMMMMMMMMMMMM:
    $4.MMMMMMMMMMMMMMMMMMMMMMMMX.
     kMMMMMMMMMMMMMMMMMMMMMMMMWd.
     $5'XMMMMMMMMMMMMMMMMMMMMMMMMMMk
      'XMMMMMMMMMMMMMMMMMMMMMMMMK.
        $6kMMMMMMMMMMMMMMMMMMMMMMd
         ;KMMMMMMMWXXWMMMMMMMk.
           "cooc*"    "*coo'"
  '';

  programs.fish.interactiveShellInit = lib.mkBefore ''
    if command -q macchina
        set -l _iface (route -n get default 2>/dev/null \
            | string match --regex --groups-only '^\s+interface: (.+)$')[1]
        if test -n "$_iface"
            macchina --interface $_iface
        else
            macchina
        end
    end
  '';
}
