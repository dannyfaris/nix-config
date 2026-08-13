# niri laptop fragment — touchpad feel + built-in HiDPI panel scale.
#
# Alnair-scoped, NOT shared. Imported only via hosts/alnair
# hostContext.extraHomeModules. The shared home/nixos/niri.nix is loaded by
# the desktop host alcyone, which has no touchpad and no built-in
# panel — so these settings must not land there (#636 placement call). Values
# merge into programs.niri.settings (niri-flake's homeModules.config is
# auto-imported alongside niri.nix; there is no enable option to set).
let
  profile = import ../../lib/display-profiles.nix; # display calibration — output scale
in
{
  programs.niri.settings = {
    # eDP-1 is the built-in panel (2496×1664 3:2, ~201 PPI — the fleet's first
    # built-in HiDPI). It rides the fleet display calibration so scale/fonts/
    # geometry stay in lockstep. The #636 open question — whether this panel
    # wants its OWN scale — was answered on-metal here: it wants 1.5×, which is
    # now the fleet calibration, so no per-host seam is needed (#715).
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
