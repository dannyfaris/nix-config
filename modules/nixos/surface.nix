# Surface Laptop 4 (15" Intel, 1978) silicon — the Surface Aggregator
# stack, Iris Xe graphics, and built-in-webcam device access.
#
# Imported ONLY by hosts/alnair, the fleet's first laptop. Never add this
# to a shared bundle — it is exactly the modules/nixos/nvidia.nix pattern
# (host-specific silicon → dedicated module, not the auto-generated
# hardware-configuration.nix). Never reused (#636).
#
# Hand-rolled on the fleet's standard mainline kernel. nixos-hardware is
# deliberately NOT adopted: its microsoft/surface/common module
# unconditionally pins the linux-surface patched kernel (no enable guard),
# whose only benefit here — IPTS touchscreen/pen — is disabled. Mainline
# carries the whole SAM stack in-tree, proven on the live box (#636).
#
# The seam with the mobility bundle: this module makes the exact silicon
# *work* (drivers that make the battery readable at all); battery POSTURE
# (thresholds, profile-on-AC-vs-battery) lives in the mobility bundle.
let
  operator = import ../../lib/operator.nix;

  # The Surface System Aggregator Module (SAM) chain: UART transport up
  # through the keyboard/touchpad HID. The built-in keyboard is not a
  # standard i8042/USB HID device — it hangs off SAM over UART and only
  # comes alive once this chain loads (#636).
  samChain = [
    "intel_lpss"
    "intel_lpss_pci"
    "8250_dw"
    "surface_aggregator"
    "surface_aggregator_registry"
    "surface_aggregator_hub"
    "surface_hid_core"
    "surface_hid"
    "surface_kbd"
  ];

  # The kernel never probes the enumerated SSAM serdev device (serial0-0)
  # on the current pin, leaving keyboard + touchpad dead; a drivers_probe
  # write through the bus's own match path binds it instantly, and becomes
  # a no-op once a fixed kernel self-binds. Full on-metal forensics: #636.
  # Every step is guarded so the script-wrapper's injected `set -e` can't
  # wedge the loop; nothing Requires the unit — a timeout fails it for
  # visibility and boot proceeds.
  samProbeScript = ''
    set -u
    i=0
    while [ "$i" -lt 15 ]; do
      if [ -e /sys/bus/serial/devices/serial0-0/driver ]; then
        exit 0
      fi
      if [ -e /sys/bus/serial/devices/serial0-0 ]; then
        echo serial0-0 > /sys/bus/serial/drivers_probe 2>/dev/null || true
      fi
      sleep 1
      i=$((i + 1))
    done
    echo "surface: serial0-0 (SSAM) unbound after 15s — built-in keyboard/touchpad dead (#636)" >&2
    exit 1
  '';
in
{
  boot = {
    # SAM chain in the initrd: the built-in keyboard MUST work at the LUKS
    # recovery-passphrase prompt (the TPM2 auto-unseal fallback path).
    # pinctrl_tigerlake leads: the SSAM probe's wake IRQ is a GPIO on the
    # Tiger Lake pinctrl — without it in stage-1 the probe fails -EINVAL
    # (not -EPROBE_DEFER, so it is never retried; #636 on-metal finding,
    # the linux-surface#1645 signature).
    initrd.kernelModules = [ "pinctrl_tigerlake" ] ++ samChain;

    # Runtime: the SAM chain plus the battery/charger/platform-profile
    # drivers. These live here (silicon) because they make the battery
    # readable *at all*; the battery posture is the mobility bundle's seam.
    kernelModules = samChain ++ [
      "surface_battery"
      "surface_charger"
      "surface_platform_profile"
      "surfacepro3_button"
      "surface_hotplug"
    ];

    # Stage-1 SSAM re-probe — the built-in keyboard must be alive at the
    # LUKS recovery-passphrase prompt. Ordering-light on purpose: only
    # after modules-load, never Before= anything on the crypt path, so a
    # bug here can delay the keyboard by seconds but can never hang the
    # boot (DefaultDependencies off per the ephemeral-root boot-path idiom).
    initrd.systemd.services.surface-sam-probe = {
      description = "Bind the Surface Aggregator serdev device (SSAM re-probe)";
      unitConfig.DefaultDependencies = false;
      after = [ "systemd-modules-load.service" ];
      wantedBy = [ "initrd.target" ];
      serviceConfig.Type = "oneshot";
      script = samProbeScript;
    };
  };

  # Iris Xe / i915 — GBM/EGL userspace so the Wayland compositor (niri)
  # can render.
  hardware.graphics.enable = true;

  # The built-in webcam (Surface C UVC at /dev/video0) is the first
  # on-fleet camera, so the module that creates the need owns the group
  # (networking-networkmanager.nix precedent). Belt-and-suspenders — the
  # logind seat ACL usually grants it; acceptance test is browser-sees-cam.
  users.users.${operator.name}.extraGroups = [ "video" ];

  # IPTS touchscreen/pen: deliberately NOT enabled (operator lean, #636).
  # It is the only thing that would force the linux-surface patched kernel.

  # Stage-2 twin: a no-op when stage-1 bound it (first loop check), the
  # session's safety net when it didn't — and a loud unit failure (fanned
  # to ntfy) if the SSAM device can't be bound at all.
  systemd.services.surface-sam-probe = {
    description = "Bind the Surface Aggregator serdev device (SSAM re-probe)";
    after = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = samProbeScript;
    # Opt-in failure fan-out to the fleet ntfy endpoint (unit-failure-notifier.nix
    # contract) — a bind failure means a dead built-in keyboard.
    onFailure = [ "notify-failure@%n.service" ];
  };
}
