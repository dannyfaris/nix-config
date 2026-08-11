# yabai — trial window manager on neptune, replacing AeroSpace for the duration
# of the trial branch. Its hotkey half is home/darwin/skhd.nix.
#
# This re-opens the yabai rejection in docs/design/macos-deterministic-tiling.md
# §Rationale, which recorded yabai as failing immovable force 2. That force is
# only PARTIALLY met here, and the difference is worth being exact about. Its
# first clause — SIP stays enabled — holds: `enableScriptingAddition = false`
# means no Dock injection and no SIP change. Its second clause, "Accessibility-API
# only", does not: this config exercises private SkyLight throughout —
# SLSMoveWindowsToManagedSpace / SLSSpaceSetCompatID (space_manager.c:679-696),
# _SLPSSetFrontProcessWithOptions (window_manager.c:2104), SLSGetSpaceManagementMode
# (yabai.c:275), plus a synthesized private gesture stream for space switching
# (space_manager.c:920-945). The note draws exactly this contrast for AeroSpace at
# line 89: "Public Accessibility API + one private window-ID call". So the posture
# question the trial actually asks is whether SIP-enabled-but-private-API-heavy is
# acceptable, not whether yabai is Accessibility-only. It is not.
#
# Foregone without the scripting addition: space create/destroy/reorder,
# sticky/pip/shadow, opacity and window layers — none of which this config uses.
#
# A nix-darwin *system* service because the upstream module is a system module —
# the criterion modules/darwin/jankyborders.nix records for its own placement.
#
# Needs an Accessibility grant, keyed to the store path (ad-hoc signed, no Team
# Identifier), so it is lost on every version bump. Trial bootstrap steps are in
# docs/runbooks/yabai-trial.md.
{ config, lib, ... }:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
  operator = import ../../lib/operator.nix;
in
{
  services.yabai = {
    enable = true;

    # Explicit, not left to the upstream default: enabling it writes a
    # passwordless-root sudoers rule for the whole admin group
    # (%admin ALL=(root) NOPASSWD: … --load-sa) and requires SIP off. A posture
    # that consequential is stated in the config, not inherited.
    enableScriptingAddition = false;

    config = {
      # yabai has no i3-flat layout, so BSP with auto_balance is the nearest
      # analogue of AeroSpace's `tiles`: equal-area siblings rather than a
      # dwindle spiral.
      layout = "bsp";
      # String, not a Nix bool — the module renders `${toString v}`, so `true`
      # would become "1" and yabai accepts only on/off/x-axis/y-axis.
      auto_balance = "on";
      split_ratio = "0.50";

      # Carbon spacing-05 from the design token, matching what AeroSpace used.
      # The gap/border relationship is single-sourced in
      # modules/darwin/jankyborders.nix.
      window_gap = tokens.spacing.s05;
      top_padding = 10;
      bottom_padding = 10;
      left_padding = 10;
      right_padding = 10;

      # Focus stays keyboard-driven, matching the niri/AeroSpace habit; the mouse
      # neither takes nor follows focus.
      focus_follows_mouse = "off";
      mouse_follows_focus = "off";
      # New windows land on the display that has focus rather than the one that
      # happened to spawn them — the single-display case where these differ is a
      # background app opening a window.
      window_origin_display = "focused";
    };

    # Windows that must never be tiled. NET-NEW behaviour: the AeroSpace config
    # had no float rules at all (no `on-window-detected`), relying on AeroSpace's
    # own detection. yabai has none, so these are hand-listed and will need
    # extending as the trial finds more.
    #
    # 1Password and Finder float wholesale, in parity with the utility-palette
    # rules in home/nixos/niri.nix (Nautilus + 1Password, `open-floating`): apps
    # you summon and dismiss, not tiles. `manage=off` is the true analogue of
    # niri's `open-floating` — it sets the float flag rather than dropping the
    # window, so `window --toggle float` still tiles it back.
    #
    # Matched by app, never by title: these titles are content-derived (a Finder
    # window is named for its folder, 1Password's for the selected vault), so no
    # title filter can name the main window. The Finder rule subsumes the dialog
    # titles it replaces.
    #
    # The 1Password grid pin is the darwin half of niri's 0.5x0.5 open size —
    # Electron restores its last-saved bounds, which are tile-shaped for as long
    # as it has been tiling. `grid` needs no scripting addition.
    #
    # `rule --add` only appends, and yabai enrols every pre-existing window before
    # it runs this config (src/yabai.c:338 vs :348), so without the trailing
    # `rule --apply` these stay tiled across every mid-session agent reload.
    extraConfig = ''
      yabai -m rule --add app="^System Settings$" manage=off
      yabai -m rule --add app="^Karabiner-Elements$" manage=off
      yabai -m rule --add app="^Karabiner-EventViewer$" manage=off
      yabai -m rule --add app="^1Password$" manage=off grid=4:4:1:1:2:2
      yabai -m rule --add app="^Finder$" manage=off
      yabai -m rule --apply
    '';
  };

  launchd.user.agents.yabai.serviceConfig = {
    # The upstream module leaves both null, so a config parse error or a failed
    # precondition would go to a closed fd. yabai exits *successfully* when it
    # cannot get Accessibility or when "Displays have separate Spaces" is off
    # (src/yabai.c:271-277 via src/misc/log.h), so launchd reports the job healthy
    # and modules/darwin/launchd-failure-notifier.nix — keyed on non-zero exits —
    # stays silent. The log is the only signal.
    StandardOutPath = "${operator.darwinHome}/Library/Logs/yabai.out.log";
    StandardErrorPath = "${operator.darwinHome}/Library/Logs/yabai.err.log";
    # Those clean exits would otherwise respawn every ~10s, each re-prompting for
    # Accessibility, with no window manager up.
    KeepAlive = lib.mkForce { SuccessfulExit = false; };
  };
}
