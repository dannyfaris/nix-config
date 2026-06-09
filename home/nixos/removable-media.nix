# Removable media (home side) — udiskie auto-mounts inserted devices and
# notifies via fnott; the mount.yazi plugin gives in-yazi unmount/eject (the
# safe-removal affordance, since we run tray-less). The system side (udisks2
# + filesystem helpers) is modules/nixos/removable-media.nix. See
# docs/desktop/removable-media.md (#105).
{ pkgs, ... }:
{
  services.udiskie = {
    enable = true;
    automount = true; # plug in -> mount; the issue's core ask
    notify = true; # mount/unmount pop-ups via fnott (org.freedesktop.Notifications)
    # Tray-less: the home-manager default ("auto") hard-Requires a
    # tray.target that waybar doesn't register, which fails the unit. Going
    # tray-less keeps notifications (tray-independent) and drops the ordering
    # fragility; safe-eject lives in the mount.yazi plugin below instead.
    tray = "never";
  };

  # mount.yazi — mount / unmount / eject removable partitions from inside
  # yazi (our browse surface; no GUI file manager). Wraps udisksctl (from
  # udisks2) + lsblk. Linux-only, so it lives here rather than in the
  # cross-platform yazi config (home/shared/cli-utils.nix). The plugin has no
  # setup(), so a keybind is all that's needed. yazi 26.5 uses the `mgr`
  # keymap section; prepend_keymap layers over yazi's built-in defaults.
  programs.yazi = {
    plugins.mount = pkgs.yaziPlugins.mount;
    keymap.mgr.prepend_keymap = [
      {
        on = "M";
        run = "plugin mount";
        desc = "Removable media — mount / unmount / eject";
      }
    ];
  };
}
