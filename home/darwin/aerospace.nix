# AeroSpace window manager on Darwin (ADR-040, superseding ADR-039 §7's
# pure-Hammerspoon realization). Installs pkgs.aerospace via the
# `programs.aerospace` home-manager module and owns
# ~/.config/aerospace/aerospace.toml + the launchd agent.
#
# See docs/design/macos-deterministic-tiling.md for the *why* (the need-vs-means
# reframe, the settled keymap, the i3-flat/no-scroll limitations) and ADR-040
# for the frozen decision. Bootstrap runbook (Accessibility grant, "Automatically
# rearrange Spaces" off): docs/runbooks/darwin-bootstrap.md.
#
# Keybinds are single-sourced from lib/capabilities.nix (ADR-039): the
# `aerospace-action` emitter (caps.aerospaceBinds) renders the simple verbs +
# app-launch into `[mode.main.binding]`; the two `aerospace-exec` binds
# (edge-scroll, maximise-by-isolation) are hand-authored below because they
# shell out to the `aerospace` CLI by an absolute (package-derived) path — which
# the repo-decoupled registry (only `{ lib }`) cannot form. Their chords come
# from the registry via caps.aerospaceChord, so the merged-namespace collision
# lint (caps.darwinCollisions) sees them and they cannot drift from the caps
# they realize.
#
# SEQUENCING HAZARD (Stage-4 teardown, #494): before the first `nh darwin switch`
# with this module, remove any pre-existing unmanaged
# ~/.config/aerospace/aerospace.toml — home-manager's activation aborts if it
# cannot clobber a non-HM file at that path.
#
# exec-and-forget gotchas baked in below: it runs a bare `/bin/bash -c` with no
# nix profile on PATH, so the `aerospace` CLI is called by its absolute store
# path (never $HOME/.nix-profile/bin — that path goes stale on upgrade);
# `workspace next|prev` is passed `--no-stdin` (v0.20 forbids implicit stdin
# under exec-and-forget); and exec-and-forget swallows errors, so each bind is
# verified on-box (CLAUDE.md runtime-verification rule).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  caps = import ../../lib/capabilities.nix { inherit lib; };
  tokens = import ../../lib/theme-tokens.nix { inherit config; };

  # Absolute path to the AeroSpace CLI for the exec-and-forget bodies.
  aerospace = lib.getExe pkgs.aerospace;

  # Chords for the hand-authored aerospace-exec binds, rendered from the same
  # registry caps they realize (single-source; the collision lint reserves these
  # exact chords via those caps).
  chordFor = c: caps.aerospaceChord c;
  hyperLeft = chordFor {
    tier = "hyper";
    key = "Left";
  };
  hyperRight = chordFor {
    tier = "hyper";
    key = "Right";
  };
  hyperShiftM = chordFor {
    tier = "hyper";
    mods = [ "Shift" ];
    key = "M";
  };

  # Edge-scroll fallthrough (darwin-specific; focus-column-{left,right}): try to
  # focus that way; at the workspace edge `focus` exits non-zero, so fall through
  # to the adjacent workspace (wrap-around) and focus back the opposite way until
  # the boundary — landing on the far column. `workspace next|prev` needs
  # --no-stdin under exec-and-forget.
  edgeScrollRight = "exec-and-forget AS=${aerospace}; $AS focus --boundaries-action fail right || { $AS workspace --wrap-around --no-stdin next && while $AS focus --boundaries-action fail left >/dev/null 2>&1; do :; done; }";
  edgeScrollLeft = "exec-and-forget AS=${aerospace}; $AS focus --boundaries-action fail left || { $AS workspace --wrap-around --no-stdin prev && while $AS focus --boundaries-action fail right >/dev/null 2>&1; do :; done; }";

  # Maximise-by-isolation (maximise-by-isolation cap): AeroSpace has no stable
  # maximize (`fullscreen` drops on focus-change), so isolate the focused window
  # onto its own empty workspace. If it's already alone in the tiling layout →
  # no-op; else move it to the first empty workspace (focus follows).
  # STAGE-1 FIX (#494): count only *tiling* windows — `%{window-layout}` is
  # `floating` for floating windows and `h_tiles`/`v_tiles`/`*_accordion`
  # otherwise — so a lone tiled window beside a floating one no longer reads as
  # ≥2. Known limitation (carried): no empty workspace left → silent no-op.
  maximiseByIsolation = "exec-and-forget AS=${aerospace}; n=$($AS list-windows --workspace focused --format '%{window-layout}' | grep -vc '^floating$'); [ \"$n\" -le 1 ] || { ws=$($AS list-workspaces --monitor focused --empty | head -1); [ -n \"$ws\" ] && $AS move-node-to-workspace --focus-follows-window \"$ws\"; }";

  handAuthoredBinds = {
    ${hyperLeft} = edgeScrollLeft;
    ${hyperRight} = edgeScrollRight;
    ${hyperShiftM} = maximiseByIsolation;
  };
in
{
  programs.aerospace = {
    enable = true;
    # launchd owns start-at-login (stable store path, fixing the trial's manual
    # start). Enabling it forces start-at-login=false + after-login-command=[]
    # in the written config — those are managed by launchd instead (verified
    # against the pinned HM module).
    launchd.enable = true;

    settings = {
      # i3-flat tiling; new windows tile on open (the need, ADR-040). `auto`
      # orientation splits along the longer screen dimension.
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      # Gaps. inner is the Carbon spacing-05 vocabulary value (16), sourced from
      # the design token so it can't drift from the scale, and stays > 2× the
      # 6pt JankyBorders width so adjacent tiles' borders never touch; outer
      # clears the screen edge. NB the token is `spacing.s05`, NOT the niri
      # `layout.gap` — layout.gap is display-profile-scaled for niri's physical
      # rendering (12 under metis's 2× profile), whereas AeroSpace works in
      # macOS points where Retina scaling is transparent, so the unscaled
      # on-vocab value is the correct one here.
      gaps = {
        inner = {
          horizontal = tokens.spacing.s05;
          vertical = tokens.spacing.s05;
        };
        outer = {
          left = 10;
          right = 10;
          top = 10;
          bottom = 10;
        };
      };

      # Main mode: the emitted simple verbs + app-launch (caps.aerospaceBinds)
      # merged with the two hand-authored complex binds. The collision lint
      # (caps.darwinCollisions) guards the merged namespace, so this `//` cannot
      # silently shadow an emitted chord.
      mode.main.binding = caps.aerospaceBinds // handAuthoredBinds;

      # Service mode (Hyper+Shift+; enters it): low-frequency ops, each returning
      # to main. Hand-authored — an AeroSpace modal submap, not a chord→cap.
      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];
      };
    };
  };
}
