# System info display — Macchina with a customised Hydrogen theme that
# swaps the upstream ASCII for the two-tone NixOS snowflake defined below.
#
# Platform-pure half of the macchina wiring (package + theme + ASCII
# art). The shell-init half lives in platform-specific siblings —
# `home/nixos/macchina-shell-init.nix` (Linux: iproute2) and
# `home/darwin/macchina-shell-init.nix` (Darwin: `route`) — because
# interface-detection uses platform-specific CLI tools. Each host's
# extraHomeModules imports BOTH this file and the matching sibling.
# See ADR-027 for the foundation+bundles model.
{ pkgs, config, ... }:
let
  esc = builtins.fromJSON ''"\u001b"''; # JSON parses \uXXXX; Nix strings do not
  # Per-host two-tone NixOS-snowflake from the Stylix palette (ADR-028).
  # base0D = primary accent (blue/cyan family in most base16 schemes);
  # base0C = secondary accent (cyan/teal family). The silhouette still
  # reads as NixOS regardless of hue; the per-host SSH-context signal at
  # shell launch is the win. `inherit (...)` doesn't work for these attrs
  # because hyphens aren't valid in identifiers, so we read them off the
  # colours attrset directly.
  c = config.lib.stylix.colors;
  dark = "${esc}[38;2;${c."base0D-rgb-r"};${c."base0D-rgb-g"};${c."base0D-rgb-b"}m";
  light = "${esc}[38;2;${c."base0C-rgb-r"};${c."base0C-rgb-g"};${c."base0C-rgb-b"}m";
  bdark = "${esc}[48;2;${c."base0D-rgb-r"};${c."base0D-rgb-g"};${c."base0D-rgb-b"}m";
  blight = "${esc}[48;2;${c."base0C-rgb-r"};${c."base0C-rgb-g"};${c."base0C-rgb-b"}m";
  reset = "${esc}[0m";
in
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile = {
    "macchina/macchina.toml".text = ''
      theme = "Hydrogen"
    '';

    # Custom Hydrogen theme: identical to upstream except hide_ascii = false
    # and [custom_ascii] added. Cannot source upstream directly because that
    # has hide_ascii = true, which would suppress the art entirely.
    # Verify this TOML against contrib/themes/Hydrogen.toml when bumping macchina.
    "macchina/themes/Hydrogen.toml".text = ''
      # Hydrogen

      spacing         = 2
      padding         = 0
      hide_ascii      = false
      separator       = ">"
      key_color       = "Cyan"
      separator_color = "White"

      [custom_ascii]
      path = "${config.xdg.configHome}/macchina/nixos-ascii.txt"

      [palette]
      type = "Full"
      visible = false

      [bar]
      glyph           = "ߋ"
      symbol_open     = '['
      symbol_close    = ']'
      hide_delimiters = true
      visible         = true

      [box]
      border          = "plain"
      visible         = true

      [box.inner_margin]
      x               = 1
      y               = 0

      [randomize]
      key_color       = false
      separator_color = false

      [keys]
      host            = "Host"
      kernel          = "Kernel"
      battery         = "Battery"
      os              = "OS"
      de              = "DE"
      wm              = "WM"
      distro          = "Distro"
      terminal        = "Terminal"
      shell           = "Shell"
      packages        = "Packages"
      uptime          = "Uptime"
      memory          = "Memory"
      machine         = "Machine"
      local_ip        = "Local IP"
      backlight       = "Brightness"
      resolution      = "Resolution"
      cpu_load        = "CPU Load"
      cpu             = "CPU"
      gpu             = "GPU"
      disk_space      = "Disk Space"
    '';

    # NixOS snowflake — two-tone blue ANSI art displayed to the left of system info.
    # Glyph layout adapted from https://github.com/4DBug/nix-ansi; colour escapes applied here.
    "macchina/nixos-ascii.txt".text =
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
  };
}
