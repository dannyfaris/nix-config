# Caps Lock → Hyper on the niri desktop, via keyd. keyd is a system daemon
# that remaps at the evdev layer, below libinput and the compositor, so Hyper
# is realized everywhere the keyboard is read: niri, the greetd greeter, and
# TTYs. The Linux analogue of Karabiner's DriverKit layer.
#
# Hyper = Ctrl+Alt (the cross-platform base, ADR-039 §3). The modifier set is
# read from the single-source capability registry (lib/capabilities.nix —
# `tiers.hyper.linux`) so this substrate and the niri emitter share one
# constant and the base shape is a single edit (§4). keyd modifier letters:
# C=Ctrl, A=Alt, S=Shift, M=Meta/Super — so Ctrl+Alt renders the layer
# `[hyper:C-A]`. Hold-only: a bare Caps Lock tap is inert (deliberately
# `layer(...)`, not `overload(hyper, esc)`), to match the mac. The empty
# `[hyper:C-A]` section is keyd's idiom for a custom modifier layer;
# lib.generators.toINI renders the empty attrset as a bare section header.
# niri catches Hyper as `Ctrl+Alt+<key>` (plus Shift/Super escalators).
#
# VT-switch caveat: with the bare Ctrl+Alt base, Caps + F1–F12 emits literal
# Ctrl+Alt+F1..F12 — the kernel VT switch (it was masked under the old all-four
# base). The registry's F-row collision lint keeps the F-row unbound, so it is
# only reachable by pressing it on purpose. See docs/desktop/keybinds.md
# §Inherited reservations.
#
# neptune's Karabiner still produces the pre-cutover all-four Hyper; it migrates
# to Ctrl+Opt in the macOS emitter phase (#440). Until then the two hosts' Hyper
# bases differ — parity-not-identity is restored when that lands.
#
# Wired through the desktop-env system bundle, so only desktop hosts get the
# remap (headless hosts import no desktop bundle). See docs/desktop/keyd.md for
# the selection rationale, the xkb caps:hyper alternative, and break-glass notes
# (keyd is not fail-closed; the in-kernel `backspace+escape+enter` chord
# terminates it). Bind manifest: docs/desktop/keybinds.md.
{ lib, pkgs, ... }:
let
  # Hyper's modifier set comes from the registry (same constant the niri emitter
  # consumes), mapped to keyd's one-letter modifier codes. The layer is named
  # `hyper`; the `:C-A` suffix declares which modifiers it holds while active.
  hyperMods = (import ../../lib/capabilities.nix { inherit lib; }).tiers.hyper.linux;
  keydLetter = {
    Ctrl = "C";
    Alt = "A";
    Shift = "S";
    Super = "M"; # Meta
  };
  hyperLayer = "hyper:" + lib.concatMapStringsSep "-" (m: keydLetter.${m}) hyperMods;
in
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
        ${hyperLayer} = { };
      };
    };
  };
}
