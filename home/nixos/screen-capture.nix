# screen-capture — grim, the non-interactive Wayland capture tool.
#
# Installed as a plain home.packages addition (no upstream HM module
# exists, and none is wanted — there is nothing to configure). Home-side
# rather than system-side because capture works precisely by being the
# same uid that owns the compositor's socket: the consumer is an agent or
# the operator SSH'd in as `dbf`, driving the live session.
#
# The pinned niri implements wlr-screencopy (verified at the pinned rev),
# which is the protocol grim speaks; no portal is involved, so this route
# is independent of the screencast stack in docs/desktop/screen-sharing.md.
# niri's own screenshot surface stays the console path (automatic actions
# honour block-out-from; only the interactive UI shows blocked windows) —
# see docs/desktop/keybinds.md §Screenshots.
#
# The remote invocation (WAYLAND_DISPLAY discovery, image-budget flags),
# the block-out-from credential guard, and the NVIDIA/protocol-drift sharp
# edges live in docs/desktop/screen-capture.md. Deliberately no wrapper
# script yet — see that doc §Sharp edges.
#
# Per #529.
{ pkgs, ... }:
{
  home.packages = [ pkgs.grim ];
}
