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
# app-launch into `[mode.main.binding]`; the three `aerospace-exec` binds
# (edge-scroll, maximise-by-isolation, cycle-terminal-windows) are
# hand-authored below because they
# shell out to the `aerospace` CLI by an absolute (package-derived) path — which
# the repo-decoupled registry (only `{ lib }`) cannot form. The bodies are keyed
# by capability id and chorded from the registry entries themselves
# (caps.aerospaceExecCaps), with a both-directions completeness assert — a
# registry chord change moves these binds with it, and a cap↔body mismatch
# fails eval instead of leaving a reserved-but-inert chord (#537).
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

  # Cycle-terminal-windows (cycle-terminal-windows cap): focus the next Ghostty
  # window in window-id (creation) order, wrapping past the end; from a
  # non-Ghostty window, focus the first — that case needs no branch of its own
  # (unset i coerces to 0, so the i%NR+1 wrap arithmetic selects a[1]).
  # Matching is by bundle id, so it spans
  # the one-app-instance-per-window processes that spawn-terminal's `open -na`
  # creates (which is also why macOS's native Cmd+` cannot do this).
  # `--monitor all` not `--all` — the alias is rejected alongside filtering
  # flags like --app-bundle-id. The explicit `sort -n` matters: list-windows
  # sorts by window *title*, and Ghostty titles mutate (shell/session titles),
  # which would make the cycle order shift under the operator's feet.
  cycleTerminalWindows = "exec-and-forget AS=${aerospace}; cur=$($AS list-windows --focused --format '%{window-id}'); next=$($AS list-windows --monitor all --app-bundle-id com.mitchellh.ghostty --format '%{window-id}' | sort -n | awk -v c=\"$cur\" '{a[NR]=$0; if ($0==c) i=NR} END{if (NR) print a[i%NR+1]}'); [ -n \"$next\" ] && $AS focus --window-id \"$next\"";

  # Hand-authored aerospace-exec bodies, keyed by the CAPABILITY ID they
  # realize. Chords are rendered from the registry entries below, so a
  # registry chord change moves these binds with it — restating the chord
  # here was the drift seam #537 closed.
  execBodies = {
    focus-column-left = edgeScrollLeft;
    focus-column-right = edgeScrollRight;
    maximise-by-isolation = maximiseByIsolation;
    cycle-terminal-windows = cycleTerminalWindows;
  };

  # Registry↔body completeness, both directions: an exec cap with no body here
  # would be lint-reserved and table-documented yet inert at runtime; a body
  # with no exec cap would be an unlinted bind. Either fails at host eval (so
  # the toplevel builds gate it), not only in a check derivation.
  execIds = map (c: c.id) caps.aerospaceExecCaps;
  missingBodies = lib.subtractLists (lib.attrNames execBodies) execIds;
  strayBodies = lib.subtractLists execIds (lib.attrNames execBodies);
  handAuthoredBinds =
    lib.throwIf (missingBodies != [ ] || strayBodies != [ ])
      "aerospace.nix: aerospace-exec bodies out of sync with lib/capabilities.nix — registry caps missing a body: [${lib.concatStringsSep ", " missingBodies}]; bodies with no registry cap: [${lib.concatStringsSep ", " strayBodies}] (#537)"
      (
        lib.listToAttrs (
          map (c: lib.nameValuePair (caps.aerospaceChord c.chord) execBodies.${c.id}) caps.aerospaceExecCaps
        )
      );

  # Merge guard — mirrors home/nixos/niri.nix's mergeBinds (#455): the
  # collision lint covers the merged namespace only via its check derivation,
  # so the host-eval-time disjointness guarantee for this `//` lives here.
  mergeBinds =
    generated: handAuthored:
    let
      shadowed = lib.intersectLists (lib.attrNames generated) (lib.attrNames handAuthored);
    in
    lib.throwIf (shadowed != [ ])
      "aerospace.nix: hand-authored bind(s) ${lib.concatStringsSep ", " shadowed} shadow registry-emitted chords — declare them in lib/capabilities.nix instead (ADR-039 §8, #537)"
      (generated // handAuthored);
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
      # merged with the hand-authored complex binds. mergeBinds hard-fails on a
      # shadowing chord at host eval; the collision lint (caps.darwinCollisions)
      # additionally gates the merged namespace in CI.
      mode.main.binding = mergeBinds caps.aerospaceBinds handAuthoredBinds;

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
