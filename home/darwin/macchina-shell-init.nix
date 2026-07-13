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
# Apple-logo ASCII carries raw ANSI colour escapes — macchina parses
# custom ascii with ansi-to-tui and re-emits palette-relative SGR, so
# the stripes follow the terminal's live palette (ADR-041 / #411).
# Stripe order (green leaf, then yellow / red / magenta / blue bands)
# matches macchina's own compiled-in Apple variant — verify against
# src/ascii.rs when bumping macchina.
{ lib, ... }:
let
  esc = builtins.fromJSON ''"\u001b"''; # JSON parses \uXXXX; Nix strings do not
  # Classic rainbow stripes as direct ANSI slot literals — logo
  # iconography, not UI accent roles: each scheme renders its own
  # rainbow (ANSI-16 has no orange, so the six historical bands
  # compress to five).
  green = "${esc}[32m";
  yellow = "${esc}[33m";
  red = "${esc}[31m";
  magenta = "${esc}[35m";
  blue = "${esc}[34m";
  reset = "${esc}[0m";
in
{
  # Apple logo — five-stripe pure-ASCII art. Art is macchina's built-in
  # macOS big variant (credit: Dylan Araps / Neofetch, MIT), markers
  # stripped and alignment corrected; all characters are 7-bit ASCII,
  # so JetBrainsMono Nerd Font never needs a fallback (sidesteps issue
  # #161). Every line restates its stripe's escape — cross-line SGR
  # carry through ansi-to-tui is unverified; per-line needs no such
  # assumption. Concatenation style mirrors the NixOS sibling.
  xdg.configFile."macchina/ascii.txt".text =
    "${green}                     ..'\n"
    + "${green}                 ,xNMM.\n"
    + "${green}               .OMMMMo\n"
    + "${green}               lMM\"\n"
    + "${yellow}     .;loddo:.  .olloddol;.\n"
    + "${yellow}   cKMMMMMMMMMMNWMMMMMMMMMM0:\n"
    + "${yellow} .KMMMMMMMMMMMMMMMMMMMMMMMWd.\n"
    + "${red} XMMMMMMMMMMMMMMMMMMMMMMMX.\n"
    + "${red};MMMMMMMMMMMMMMMMMMMMMMMM:\n"
    + "${red}:MMMMMMMMMMMMMMMMMMMMMMMM:\n"
    + "${magenta}.MMMMMMMMMMMMMMMMMMMMMMMMX.\n"
    + "${magenta} kMMMMMMMMMMMMMMMMMMMMMMMMWd.\n"
    + "${magenta} 'XMMMMMMMMMMMMMMMMMMMMMMMMMMk\n"
    + "${blue}  'XMMMMMMMMMMMMMMMMMMMMMMMMK.\n"
    + "${blue}    kMMMMMMMMMMMMMMMMMMMMMMd\n"
    + "${blue}     ;KMMMMMMMWXXWMMMMMMMk.\n"
    + "${blue}       \"cooc*\"    \"*coo'\"${reset}\n";

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
