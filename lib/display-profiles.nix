# Display calibration — the committed coupling of niri output scale, the
# per-surface font ramp, and the geometry (gap/radius/border), defined once so
# they stay in lockstep.
#
# 1.5× is the settled scale for NixOS desktop hosts. The values here ARE the
# on-vocab design band — Carbon spacing-05 gap 16, M3 md radius 12, foot 11 /
# dialog 12 — carried directly, not derived by scaling. How that scale was
# arrived at: docs/desktop/visual-identity.md §"Hardware is a design input".
#
# The 1.0 / 2.0 profiles and the `active` knob that selected between them were
# dropped in #715: no rider wanted a different scale, so the ladder had no user.
# The trigger to reintroduce a per-host seam is the first host that wants a scale
# its siblings don't — #715 records the plumbing shape (static-tokens.nix imports
# this as pure lib with no hostContext access, which is the hard part).
#
# Faces are not scale-dependent and live elsewhere: mono (Monaspace Argon) backs
# foot + TUIs, sans (Inter) backs GTK dialogs + web body — see docs/desktop/fonts.md.
#
# Scale is the only display knob pinned (#106): resolution and refresh are left
# to niri's preferred-mode auto-detection, since the hardware already reports
# native res + max refresh and only apparent size can't be inferred from EDID.
# Rationale: docs/desktop/niri.md §Display configuration.
{
  scale = 1.5;
  fonts = {
    terminal = 11;
    popups = 12;
  };
  geometry = {
    gap = 16;
    radius = 12;
    border = 2;
  };
}
