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
in
{
  # SAM chain in the initrd: the built-in keyboard MUST work at the LUKS
  # recovery-passphrase prompt (the TPM2 auto-unseal fallback path).
  boot.initrd.kernelModules = samChain;

  # Runtime: the SAM chain plus the battery/charger/platform-profile
  # drivers. These live here (silicon) because they make the battery
  # readable *at all*; the battery posture is the mobility bundle's seam.
  boot.kernelModules = samChain ++ [
    "surface_battery"
    "surface_charger"
    "surface_platform_profile"
    "surfacepro3_button"
    "surface_hotplug"
  ];

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
}
