# Darwin overlay: dark-mode-notify patched to use .deliverImmediately
# notification suspension.
#
# WHY: the upstream 2022-07-18 build registers
# AppleInterfaceThemeChangedNotification via the block-based Cocoa API,
# which has no suspensionBehavior parameter and defaults to .hold/.coalesce.
# An idle launchd agent is App Nap eligible; the OS holds notifications,
# causing ~50% miss rate under sustained idle. The patch switches to the
# selector-based API with .deliverImmediately so the OS cannot defer
# delivery. See issue #620.
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      dark-mode-notify = prev.dark-mode-notify.overrideAttrs (_old: {
        patches = [ ./patches/dark-mode-notify-deliver-immediately.patch ];
      });
    })
  ];
}
