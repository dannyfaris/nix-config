# Linux-side half of the macchina wiring — owns the NixOS-snowflake
# `ascii.txt` (with Stylix-driven two-tone colouring) and the
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
{ config, lib, ... }:
let
  esc = builtins.fromJSON ''"\u001b"''; # JSON parses \uXXXX; Nix strings do not
  # Per-host two-tone NixOS snowflake from the Stylix palette (ADR-028).
  # base0D = primary accent (blue/cyan family in most base16 schemes);
  # base0C = secondary accent (cyan/teal family). The silhouette still
  # reads as NixOS regardless of hue; the per-host SSH-context signal at
  # shell launch is the win. `inherit (...)` doesn't work for these
  # attrs because hyphens aren't valid in identifiers, so we read them
  # off the colours attrset directly.
  c = config.lib.stylix.colors;
  dark = "${esc}[38;2;${c."base0D-rgb-r"};${c."base0D-rgb-g"};${c."base0D-rgb-b"}m";
  light = "${esc}[38;2;${c."base0C-rgb-r"};${c."base0C-rgb-g"};${c."base0C-rgb-b"}m";
  bdark = "${esc}[48;2;${c."base0D-rgb-r"};${c."base0D-rgb-g"};${c."base0D-rgb-b"}m";
  blight = "${esc}[48;2;${c."base0C-rgb-r"};${c."base0C-rgb-g"};${c."base0C-rgb-b"}m";
  reset = "${esc}[0m";
in
{
  # NixOS snowflake — two-tone ANSI art displayed to the left of system info.
  # Glyph layout adapted from https://github.com/4DBug/nix-ansi; colour
  # escapes applied here. Written to the generic `ascii.txt` path the
  # shared Hydrogen theme references.
  xdg.configFile."macchina/ascii.txt".text =
    "${dark}       ◢██◣${light}   ◥███◣  ◢██◣\n"
    + "${dark}       ◥███◣${light}   ◥███◣◢███◤\n"
    + "${dark}        ◥███◣${light}   ◥██████◤\n"
    + "${dark}    ◢████████████${blight}◣${reset}${light}████◤${dark}   ◢◣\n"
    + "${dark}   ◢██████████████${blight}◣${reset}${light}███◣${dark}  ◢██◣\n"
    + "${light}        ◢███◤      ◥███◣${dark}◢███◤\n"
    + "${light}       ◢███◤        ◥██${bdark}◤${reset}${dark}███◤\n"
    + "${light}◢█████████◤          ◥${bdark}◤${reset}${dark}████████◣\n"
    + "${light}◥████████${bdark}◤${reset}${dark}◣          ◢█████████◤\n"
    + "${light}    ◢███${bdark}◤${reset}${dark}██◣        ◢███◤\n"
    + "${light}   ◢███◤${dark}◥███◣      ◢███◤\n"
    + "${light}   ◥██◤  ${dark}◥███${blight}◣${reset}${light}██████████████◤\n"
    + "${light}    ◥◤   ${dark}◢████${blight}◣${reset}${light}████████████◤\n"
    + "${dark}        ◢██████◣${light}   ◥███◣\n"
    + "${dark}       ◢███◤◥███◣${light}   ◥███◣\n"
    + "${dark}       ◥██◤  ◥███◣${light}   ◥██◤${reset}\n";

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
