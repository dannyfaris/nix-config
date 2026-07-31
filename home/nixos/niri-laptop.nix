# niri laptop fragment — touchpad feel + built-in HiDPI panel scale.
#
# Alnair-scoped, NOT shared. Imported only via hosts/alnair
# hostContext.extraHomeModules. The shared home/nixos/niri.nix is loaded by
# the desktop hosts (metis/alcyone), which have no touchpad and no built-in
# panel — so these settings must not land there (#636 placement call). Values
# merge into programs.niri.settings (niri-flake's homeModules.config is
# auto-imported alongside niri.nix; there is no enable option to set).
let
  profile = import ../../lib/display-profiles.nix; # active display profile — output scale
in
{
  programs.niri.settings = {
    # eDP-1 is the built-in panel (2496×1664 3:2, ~201 PPI — the fleet's first
    # built-in HiDPI). It rides the fleet display profile so scale/fonts/geometry
    # stay in lockstep (the whole point of display-profiles.nix). Open question:
    # whether this panel wants its OWN profile (e.g. 1.5× while desktops run 2.0×)
    # is the on-metal tuning call and would force per-host profiles — see #636.
    outputs."eDP-1".scale = profile.scale;

    # Touchpad — mirrors the operator's MacBook Air feel. Behavioural
    # translation, not a settings import; full table in #636.
    input.touchpad = {
      tap = false; # Clicking=0 on the Air — physical click only, no tap-to-click
      natural-scroll = true; # macOS default (natural)
      click-method = "clickfinger"; # the Mac-defining setting — two-finger = right-click
      dwt = true; # disable-while-typing — macOS does this implicitly
      accel-speed = 0.0; # honest starting point; the one value expected to tune on-metal
    };

    # niri hard-binds XF86PowerOff → Suspend by default; the wake press is
    # redelivered to niri after resume and key-repeats into a suspend storm —
    # the un-wakeable-laptop loop (#636 on-metal finding). Single owner:
    # logind (mobility bundle pins HandlePowerKey=ignore alongside this).
    input.power-key-handling.enable = false;
  };
}
