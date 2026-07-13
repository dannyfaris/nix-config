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
# Apple-logo ASCII uses the same Stylix true-colour mechanism as
# `home/nixos/macchina-shell-init.nix`: 24-bit ANSI escapes from
# config.lib.stylix.colors (base0D/base0C), applied at eval time.
# Two-tone: stem+leaf = base0D, body = base0C. Parity with #310.
{ config, lib, ... }:
let
  esc = builtins.fromJSON ''"\u001b"''; # JSON parses \uXXXX; Nix strings do not
  # Per-host two-tone Apple logo from the Stylix palette (ADR-028).
  # base0D = primary accent; base0C = secondary accent. Mirrors the
  # colour roles used by the NixOS sibling for the NixOS snowflake.
  c = config.lib.stylix.colors;
  dark = "${esc}[38;2;${c."base0D-rgb-r"};${c."base0D-rgb-g"};${c."base0D-rgb-b"}m";
  light = "${esc}[38;2;${c."base0C-rgb-r"};${c."base0C-rgb-g"};${c."base0C-rgb-b"}m";
  reset = "${esc}[0m";
in
{
  # Apple logo — two-tone pure-ASCII art, stem+leaf in dark (base0D),
  # body in light (base0C). Art is macchina's built-in macOS big
  # variant (credit: Dylan Araps / Neofetch, MIT), with $N palette-
  # index markers removed and alignment corrected; all characters are
  # 7-bit ASCII, so JetBrainsMono Nerd Font never needs a fallback
  # (sidesteps issue #161). Colour escapes applied here at eval time.
  xdg.configFile."macchina/ascii.txt".text =
    "${dark}                     ..'\n"
    + "${dark}                 ,xNMM.\n"
    + "${dark}               .OMMMMo\n"
    + "${dark}               lMM\"\n"
    + "${light}     .;loddo:.  .olloddol;.\n"
    + "${light}   cKMMMMMMMMMMNWMMMMMMMMMM0:\n"
    + "${light} .KMMMMMMMMMMMMMMMMMMMMMMMWd.\n"
    + "${light} XMMMMMMMMMMMMMMMMMMMMMMMX.\n"
    + "${light};MMMMMMMMMMMMMMMMMMMMMMMM:\n"
    + "${light}:MMMMMMMMMMMMMMMMMMMMMMMM:\n"
    + "${light}.MMMMMMMMMMMMMMMMMMMMMMMMX.\n"
    + "${light} kMMMMMMMMMMMMMMMMMMMMMMMMWd.\n"
    + "${light} 'XMMMMMMMMMMMMMMMMMMMMMMMMMMk\n"
    + "${light}  'XMMMMMMMMMMMMMMMMMMMMMMMMK.\n"
    + "${light}    kMMMMMMMMMMMMMMMMMMMMMMd\n"
    + "${light}     ;KMMMMMMMWXXWMMMMMMMk.\n"
    + "${light}       \"cooc*\"    \"*coo'\"${reset}\n";

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
