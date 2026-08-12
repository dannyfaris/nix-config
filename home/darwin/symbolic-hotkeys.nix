# macOS symbolic hotkeys — the system keyboard shortcuts under System Settings →
# Keyboard → Keyboard Shortcuts, declared rather than left to the settings panel.
#
# Declared because they do not survive a reboot. On celaeno's first cold boot of
# the yabai trial the entire Mission Control group came back unticked, taking
# `Hyper+1‑9` and the edge-scroll's space step with it — 11 of 41 binds, silently:
# no log line, no error, the chords simply did nothing while every bind that
# talks to yabai directly kept working. See docs/runbooks/yabai-trial.md §Findings.
#
# Load-bearing here (home/darwin/skhd.nix synthesizes these rather than calling
# `yabai -m space --focus`, to keep the macOS slide):
#   118‑126 — Switch to Desktop 1‑9 (Ctrl+1‑9), driven by `Hyper+1‑9`
#   79, 81  — Move left/right a space (Ctrl+←/→), the edge-scroll's plain step
#
# All seventeen are declared, not just those eleven, because of how the write
# works: home-manager applies `targets.darwin.defaults` with `defaults import`,
# which merges at *top-level key* granularity. `AppleSymbolicHotKeys` is a single
# key holding a nested dict, so declaring part of it replaces the whole thing —
# 28‑31 (screenshots) and 80/82 (move-window-with-space) are carried to avoid
# dropping them. The consequence is deliberate and worth stating: the Keyboard
# Shortcuts panel is no longer authoritative for any symbolic hotkey on this host;
# a change made there is reverted at the next activation.
#
# Timing is why this works rather than merely records intent. nix-darwin's
# `org.nixos.activate-system` daemon is RunAtLoad, and home-manager's activation
# runs inside `system.activationScripts.postActivation` (home-manager
# nix-darwin/default.nix:19) — so the import lands at boot, before login, and
# therefore before the WindowServer reads these.
#
# `enabled` is `1` for 28‑31 and `true` for the rest, mirroring what macOS itself
# wrote: the older entries carry a CFNumber, the newer a CFBoolean. Preserved as
# found rather than normalised, so the declared plist is byte-comparable with a
# panel-written one.
{
  targets.darwin.defaults."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
    let
      # <charCode> <keyCode> <modifierMask>. 65535 is "no character", used by
      # every entry whose key is addressed by keycode alone.
      key = enabled: parameters: {
        inherit enabled;
        value = {
          inherit parameters;
          type = "standard";
        };
      };
      ctrl = 262144;
      # Screenshot entries pair a shift+cmd mask with its ctrl-added variant
      # (copy-to-clipboard), which is why they come in twos.
      shiftCmd = 1441792;
      ctrlShiftCmd = 1179648;
      # Move-a-space masks: ctrl+fn, and the same with shift (moves the window).
      ctrlFn = 8650752;
      ctrlShiftFn = 8781824;
    in
    {
      # Screenshots — not trial-related, carried so the import cannot drop them.
      "28" = key 1 [
        51
        20
        shiftCmd
      ]; # picture of screen → file
      "29" = key 1 [
        51
        20
        ctrlShiftCmd
      ]; # picture of screen → clipboard
      "30" = key 1 [
        52
        21
        shiftCmd
      ]; # picture of selection → file
      "31" = key 1 [
        52
        21
        ctrlShiftCmd
      ]; # picture of selection → clipboard

      # Mission Control — move a space. 79/81 back the edge-scroll step.
      "79" = key true [
        65535
        123
        ctrlFn
      ]; # move left a space
      "80" = key true [
        65535
        123
        ctrlShiftFn
      ]; # move left, taking the window
      "81" = key true [
        65535
        124
        ctrlFn
      ]; # move right a space
      "82" = key true [
        65535
        124
        ctrlShiftFn
      ]; # move right, taking the window

      # Switch to Desktop 1‑9. Keycodes are the ANSI digit row, which is NOT
      # sequential — 5 and 6 are transposed relative to the others, as are 7‑9.
      "118" = key true [
        65535
        18
        ctrl
      ]; # Desktop 1
      "119" = key true [
        65535
        19
        ctrl
      ]; # Desktop 2
      "120" = key true [
        65535
        20
        ctrl
      ]; # Desktop 3
      "121" = key true [
        65535
        21
        ctrl
      ]; # Desktop 4
      "122" = key true [
        65535
        23
        ctrl
      ]; # Desktop 5
      "123" = key true [
        65535
        22
        ctrl
      ]; # Desktop 6
      "124" = key true [
        65535
        26
        ctrl
      ]; # Desktop 7
      "125" = key true [
        65535
        28
        ctrl
      ]; # Desktop 8
      "126" = key true [
        65535
        25
        ctrl
      ]; # Desktop 9
    };
}
