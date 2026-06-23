# Caps Lock → Hyper on the niri desktop, via keyd — keyboard-modifier
# parity with neptune's Karabiner (caps_lock → ⌘⌃⌥⇧). keyd is a
# system daemon that remaps at the evdev layer, below libinput and the
# compositor, so Hyper is realized everywhere the keyboard is read:
# niri, the greetd greeter, and TTYs. The Linux analogue of Karabiner's
# DriverKit layer.
#
# Maps caps_lock to a `hyper` modifier-layer that holds
# Super+Ctrl+Alt+Shift while held (keyd modifier letters: C=Ctrl,
# A=Alt, S=Shift, M=Meta/Super). Hold-only — a bare Caps Lock tap is
# inert (deliberately `layer(...)`, not `overload(hyper, esc)`), to
# match the mac. The empty `[hyper:C-A-S-M]` section is keyd's idiom
# for a custom modifier layer; lib.generators.toINI renders the empty
# attrset as a bare section header. niri binds catch Hyper as
# `Mod+Ctrl+Alt+Shift+<key>`.
#
# Wired through the desktop-env system bundle, so only desktop hosts get
# the remap (headless hosts import no desktop bundle). See
# docs/desktop/keyd.md for the selection rationale, the xkb caps:hyper
# alternative, and break-glass notes (keyd is not fail-closed; the
# in-kernel `backspace+escape+enter` chord terminates it). Bind
# manifest: docs/desktop/keybinds.md.
{ pkgs, ... }:
{
  # The `keyd` CLI on PATH — `services.keyd` wires only the daemon, so
  # `keyd monitor` (live keycode diagnostics) and `keyd reload` would
  # otherwise need the package's full store path. On a keyboard-remap
  # host the diagnostic is worth a stable command.
  environment.systemPackages = [ pkgs.keyd ];

  services.keyd = {
    enable = true;
    keyboards.default = {
      # All keyboards; keyd excludes its own virtual device. Scope by
      # device id instead of `*` if a future binding ever touches keys a
      # mouse can emit (keyd's wildcard also matches some keyboard-
      # emitting mice, e.g. the Logitech MX Master).
      ids = [ "*" ];
      settings = {
        main.capslock = "layer(hyper)";
        "hyper:C-A-S-M" = { };
      };
    };
  };
}
