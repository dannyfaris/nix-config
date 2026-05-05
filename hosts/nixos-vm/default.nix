# Host-specific configuration for the UTM VM (aarch64-linux).
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos-vm";

  # Greetd autologin into niri-session is correct for a desktop, but UTM's
  # Apple Virtualization Framework does not expose EGL_EXT_device_drm, so
  # niri cannot acquire a render device. Local console falls back to TTY
  # login; SSH is unaffected. Re-enable on the x86_64 desktop host (Tier 4).
  services.greetd = {
    enable = false;
    settings.default_session = {
      command = "niri-session";
      user = "dbf";
    };
  };

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";
}
