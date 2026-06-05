# System info display — Macchina with a customised Hydrogen theme.
#
# Truly-platform-pure half of the macchina wiring: the package, the
# `macchina.toml` theme-selector, and the Hydrogen theme TOML. The
# theme references a generic `ascii.txt` art path; each platform owns
# the `ascii.txt` content (NixOS logo on Linux, Apple logo on
# Darwin) plus its interactive-shell init, in a
# `macchina-shell-init.nix` sibling under `home/<platform>/`.
#
# Hosts of either platform import this file *and* the matching
# platform-specific sibling. See ADR-027 for the foundation+bundles
# model and the operator's choice to keep macchina visible on every
# interactive fish shell.
{ pkgs, config, ... }:
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile = {
    "macchina/macchina.toml".text = ''
      theme = "Hydrogen"
    '';

    # Custom Hydrogen theme: identical to upstream except hide_ascii = false,
    # [custom_ascii] added, and the [bar] glyph swapped for mosh-safety (see
    # below). Cannot source upstream directly because that has hide_ascii =
    # true, which would suppress the art entirely.
    # Verify this TOML against contrib/themes/Hydrogen.toml when bumping macchina.
    #
    # The `[custom_ascii].path` points at a per-platform file written by
    # the matching `home/<platform>/macchina-shell-init.nix` sibling
    # (NixOS: Stylix-coloured NixOS logo; Darwin: macchina-coloured
    # Apple logo).
    "macchina/themes/Hydrogen.toml".text = ''
      # Hydrogen

      spacing         = 2
      padding         = 0
      hide_ascii      = false
      separator       = ">"
      key_color       = "Cyan"
      separator_color = "White"

      [custom_ascii]
      path = "${config.xdg.configHome}/macchina/ascii.txt"

      [palette]
      type = "Full"
      visible = false

      [bar]
      # Plain Geometric-Shapes circle (U+25CF), not a Nerd-Font or exotic
      # codepoint: mosh silently drops uncommon glyphs while re-rendering its
      # screen model (upstream Hydrogen's NKO U+07CB vanished entirely over
      # mosh, though it rendered fine over raw SSH). U+25CF is widely
      # supported and verified to survive a mosh session.
      glyph           = "●"
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
  };
}
