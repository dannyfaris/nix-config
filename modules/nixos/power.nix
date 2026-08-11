# Laptop power posture (#636) — how a portable behaves on battery.
{
  # SL4 firmware is s2idle-only — no deep/S3. Pin explicitly so the sleep
  # state is whitelisted, not left to a default that assumes S3 (#636).
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];

  services = {
    # Battery telemetry the shell widget reads; no desktop host enables it.
    upower.enable = true;

    # Platform power profiles (was active on the donor install); drives the
    # ACPI profile that surface_platform_profile exposes.
    power-profiles-daemon.enable = true;

    # Pin the upstream lid defaults so a nixpkgs change can't silently flip
    # them (the X11Forwarding idiom). Renamed from services.logind.lidSwitch*
    # to settings.Login.* in this nixpkgs pin.
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      # Power button is wake-only on a laptop: upstream's poweroff default
      # is one bumped button from data loss, and it goes live at greetd
      # (pre-compositor) and whenever the compositor's power-key inhibitor
      # is off — as it is on alnair (#636). The fleet-wide power-key
      # meaning stays open (#651); this is the laptop-scoped call.
      HandlePowerKey = "ignore";
    };
  };
}
