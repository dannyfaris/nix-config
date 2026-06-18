# Display profiles — the committed coupling of niri output scale, the
# per-surface font ramp, and the geometry (gap/radius/border), driven by one
# knob so they stay in lockstep and switchable.
#
# metis (the only desktop host) runs 2× (chosen after an on-panel A/B vs 1× and
# 1.5×). Each profile couples the niri output scale + the font ramp + the
# geometry, calibrated so all scales render at the SAME apparent size: the 1.5×
# profile carries the on-vocab design values (Carbon spacing-05 gap 16, M3 md
# radius 12, the agreed font band — foot 11 / bar 13 / launcher 14 / notif +
# dialog 12), and the 1× and 2× profiles scale those fonts and geometry by
# ~1/scale to preserve that apparent look at each scale.
#
# Faces are not scale-dependent — the hybrid model holds across profiles: mono
# (Monaspace Argon) backs foot + waybar + fuzzel; sans (IBM Plex Sans) backs
# fnott + GTK dialogs + web body. Only sizes + geometry + scale move per profile.
#
# Retained switchable for on-panel retuning: flip `active` to "1.0" / "1.5" /
# "2.0" and `nh os switch`. Scale is the only display knob pinned (#106):
# resolution and refresh are left to niri's preferred-mode auto-detection, since
# the hardware already reports native res + max refresh and only apparent size
# can't be inferred from EDID. Rationale: docs/desktop/niri.md §Display configuration.
let
  active = "2.0"; # ← THE KNOB: "1.0" | "1.5" | "2.0"

  profiles = {
    "1.0" = {
      scale = 1.0;
      fonts = {
        terminal = 17;
        desktop = 20;
        popups = 18;
        launcher = 21;
      };
      geometry = {
        gap = 24;
        radius = 18;
        border = 3;
      };
    };
    "1.5" = {
      scale = 1.5;
      fonts = {
        terminal = 11;
        desktop = 13;
        popups = 12;
        launcher = 14;
      };
      geometry = {
        gap = 16;
        radius = 12;
        border = 2;
      };
    };
    "2.0" = {
      scale = 2.0;
      fonts = {
        terminal = 8;
        desktop = 10;
        popups = 9;
        launcher = 11;
      };
      geometry = {
        gap = 12;
        radius = 9;
        border = 2;
      };
    };
  };
in
profiles.${active}
