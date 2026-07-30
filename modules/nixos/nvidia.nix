# NVIDIA GPU support — open kernel module + proprietary userspace.
#
# Imported ONLY by hosts/alcyone, the fleet's first and only discrete GPU
# (RTX 4060, Ada Lovelace). Never add this to the shared desktop-env
# bundle: metis is an Intel iGPU and needs none of it (#631).
#
# `open = true` is not a free choice. The open kernel module supports
# only Turing-and-newer cards AND needs a driver branch new enough to
# carry Ada support; the two constraints move together. `nvidiaPackages.
# stable` (595.84 in the current pin) satisfies both. Downgrading the
# branch without re-checking Ada+open support would break the module.
# Reconciled on-metal: the live CachyOS box runs the 595 open module on
# this exact card (#631 harvest).
#
# The userspace driver (nvidia-x11) and nvidia-settings are unfree —
# whitelisted by name in modules/shared/nix-daemon.nix, never via a
# blanket allowUnfree. The open kernel module itself is MIT/GPL.
#
# Deliberately out of scope (add only when actually wanted, #631):
# 32-bit / gaming (enable32Bit, Steam), CUDA/compute (nvidiaPersistenced,
# container-toolkit), and any other driver branch.
{ config, ... }:
{
  # GBM/EGL userspace so the Wayland compositor (niri) can render.
  hardware.graphics.enable = true;

  # Selects the NVIDIA stack (kernel modules + libglvnd vendor). Named for
  # X.org historically; still the switch a pure-Wayland niri session needs.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Ada → open kernel module, coupled to the driver branch (see header).
    open = true;

    # KMS — required for the boot→niri handoff on Wayland. On the live
    # CachyOS box niri composites cleanly with modeset on and WITHOUT
    # nvidia_drm.fbdev=1 (#631 harvest), so fbdev is deliberately unset;
    # add it only if the on-metal handoff black-screens.
    modesetting.enable = true;

    # Alcyone suspends on idle — Noctalia's guarded idle→suspend, inherited
    # via the desktop-env bundle (home/nixos/noctalia.nix); the driver's
    # suspend/resume hooks save and restore VRAM so the session survives a
    # sleep cycle.
    powerManagement.enable = true;

    # 595-branch stable — Ada + open-module capable (see header). The pin
    # (595.84) is the same 595 branch as the on-metal 595.45.04, a slightly
    # newer point release.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
