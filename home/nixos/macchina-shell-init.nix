# Linux-side half of the macchina wiring — owns the NixOS-logo
# `ascii.txt` (with two-tone ANSI-slot colouring) and the
# interactive-shell init that prints the banner at every fish shell
# launch (Ghostty tab, zellij pane, helix `:sh`, every login). The
# trigger is `programs.fish.interactiveShellInit` rather than
# `loginShellInit` per the operator's "always visible on every new
# shell" preference; macchina is the SSH-context anchor.
#
# The platform-pure half (`home/shared/macchina.nix`) installs the
# package and writes the Hydrogen theme TOML referencing
# `${config.xdg.configHome}/macchina/ascii.txt`. This file owns the
# platform-specific content of that path and the shell-init that
# triggers it; the Darwin sibling at `home/darwin/macchina-shell-init.nix`
# does the same with the Apple-logo art and macOS interface detection.
# Hosts of either platform import the matching pair.
#
# `lib.mkBefore` pins the shell-init block ahead of `home/shared/shell.nix`'s
# own `interactiveShellInit` (starship's transient-prompt machinery).
# Both set the same `lib.types.lines` option; equal-priority concatenation
# order tracks import order, which is fragile across host configs.
# mkBefore (priority 500 vs default 1000) lands first in the
# concatenation regardless of import order.
#
# Interface priority for the banner's "Local IP" readout: tailscale0
# when present with an assigned IPv4, otherwise the interface the
# kernel would actually use for outbound traffic (queried via
# `ip route get`, which respects metric, policy, and multi-default-
# route precedence; `ip route show default | first` is unreliable on
# multi-homed hosts). Runs without --interface if neither resolves —
# Local IP readout is simply absent. The `command -q macchina` guard
# prevents a startup error if macchina is transiently missing from
# PATH (e.g. during a partial activation).
{ lib, ... }:
let
  esc = builtins.fromJSON ''"\u001b"''; # JSON parses \uXXXX; Nix strings do not
  # Two-tone from the terminal's ANSI palette: blue (slot 4) and cyan
  # (slot 6) are the bus positions of the base0D/base0C accents this file
  # previously baked as Stylix truecolor (ADR-041 / #411). Direct canonical
  # literals, not token roles — base0C has no role, and reading
  # theme-tokens would reintroduce the Stylix eval this drops.
  dark = "${esc}[34m"; # ANSI blue
  light = "${esc}[36m"; # ANSI cyan
  reset = "${esc}[0m";
in
{
  # NixOS logo — two-tone pure-ASCII art displayed to the left of
  # system info. Glyph layout is the `NixOS2` logo from
  # fastfetch-cli/fastfetch (MIT), chosen for being 7-bit ASCII
  # (` _/\` only) — every character is in MonaspiceAr Nerd Font
  # natively, so foot never engages fontconfig fallback for this
  # banner. Sidesteps issue #161. Colour escapes (ANSI blue / cyan
  # slots — see the let block) applied here. Written to the generic
  # `ascii.txt` path the shared Hydrogen theme references.
  xdg.configFile."macchina/ascii.txt".text =
    "${dark}        __    ${light}____    __\n"
    + "${dark}       /  \\   ${light}\\   \\  /  \\\n"
    + "${dark}       \\   \\   ${light}\\   \\/   /\n"
    + "${dark}     ___\\   \\___${light}\\      /\n"
    + "${dark}    /            ${light}\\    /   ${dark}/\\\n"
    + "${dark}   /______________${light}\\   \\  ${dark}/  \\\n"
    + "${light}        /   /      \\   \\${dark}/   /\n"
    + "${light} ______/   /        \\  ${dark}/   /___\n"
    + "${light}/         /          \\${dark}/        \\\n"
    + "${light}\\____    /${dark}\\          /   ______/\n"
    + "${light}    /   /${dark}  \\        /   /\n"
    + "${light}   /   /${dark}\\   \\${light}______${dark}/${light}___${dark}/${light}_____\n"
    + "${light}   \\  /${dark}  \\   \\${light}              /\n"
    + "${light}    \\/${dark}   /    \\${light}____    ____/\n"
    + "${light}       ${dark} /      \\${light}   \\   \\\n"
    + "${light}       ${dark}/   /\\   \\${light}   \\   \\\n"
    + "${light}       ${dark}\\__/  \\___\\${light}   \\__/${reset}\n";

  programs.fish.interactiveShellInit = lib.mkBefore ''
    if command -q macchina
        if ip addr show tailscale0 2>/dev/null | string match --quiet --regex 'inet '
            macchina --interface tailscale0
        else
            set -l _iface (ip -o route get 192.0.2.1 2>/dev/null \
                | string replace --regex --filter '.*\bdev\s+(\S+).*' '$1')[1]
            if test -n "$_iface"
                macchina --interface $_iface
            else
                macchina
            end
        end
    end
  '';
}
