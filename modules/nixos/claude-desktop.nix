# Claude Desktop for Linux — Anthropic's official beta, repackaged by
# aaddrick (github:aaddrick/claude-desktop-debian, pinned as the
# `claude-desktop` flake input). Imported per-host (metis only): it is a
# Wayland GUI app, so hosts without a desktop session would carry the
# Electron + KVM closure for nothing.
#
# Variant: `claude-desktop-fhs`, not the bare `claude-desktop`. The FHS
# build wraps the app in an FHS environment so MCP servers (which shell
# out to interpreters expecting /usr/bin paths) run — the whole reason
# Cowork is wanted here. `overlays.default` surfaces both `claude-desktop`
# and `claude-desktop-fhs` into pkgs; we install the FHS one. `claude-
# desktop` is unfree, whitelisted by name in modules/shared/nix-daemon.nix.
#
# Electron/Wayland rendering (NIXOS_OZONE_WL=1) already comes from the
# desktop-env bundle's electron-wayland.nix — not re-set here.
#
# SHARED CONFIG: this package reads/writes ~/.config/Claude, the SAME
# directory Anthropic's official claude-desktop .deb uses. Since v3.0.0 the
# two install side by side (binaries `claude-desktop-unofficial` vs
# `claude-desktop`), but they collide at runtime on that shared dir — only
# ONE can run at a time.
#
# Cowork readiness (KVM-backed micro-VM): Cowork launches its own QEMU
# guest against /dev/kvm directly, so this provides the discrete pieces its
# `--doctor` probes rather than the full libvirtd daemon (not present in
# this config, and its virtualisation stack would be unused). `claude-
# desktop-unofficial --doctor` is the on-host check that each dependency
# below is actually detected — per CLAUDE.md, a runtime property is only
# confirmed on the host, not by eval.
{
  inputs,
  pkgs,
  ...
}:
let
  operator = import ../../lib/operator.nix;
in
{
  nixpkgs.overlays = [ inputs.claude-desktop.overlays.default ];

  environment.systemPackages = [
    pkgs.claude-desktop-fhs

    # Cowork VM dependencies. KVM itself is already enabled — metis's
    # hardware-configuration.nix loads `kvm-intel`, giving /dev/kvm.
    pkgs.qemu_kvm # QEMU (qemu-system-x86_64), the VM engine.
    pkgs.virtiofsd # virtiofs host daemon — shares the guest's working dir.

    # OVMF UEFI firmware. This puts the firmware (OVMF_CODE.fd / OVMF_VARS.fd
    # under $out/FV) in the system closure so it is built and GC-rooted, but
    # NixOS's environment.pathsToLink does NOT link /FV — so it is reachable
    # only by its /nix/store path, not via any PATH/well-known location.
    # Whether Cowork's launcher discovers it that way is unverified from off
    # the host: `--doctor` (below) is the authority on what path it probes,
    # and the exact wiring lands as a follow-up once metis reports it. Kept
    # here so the firmware is present rather than absent while that is pinned
    # down. See CLAUDE.md "set ≠ enforced".
    pkgs.OVMF.fd
  ];

  # vhost-vsock — the host/guest socket transport Cowork uses to talk to its
  # VM. Loading the module creates /dev/vhost-vsock; the node defaults to
  # root:root 0600, so the operator (running Cowork's QEMU non-root) can't
  # open it. The udev rule below regroups it to `kvm` at 0660 so kvm-group
  # members reach it — the vsock parallel to /dev/kvm's own default rule.
  # Runtime-confirm the node's mode with `--doctor` per CLAUDE.md.
  boot.kernelModules = [ "vhost_vsock" ];
  services.udev.extraRules = ''
    KERNEL=="vhost-vsock", GROUP="kvm", MODE="0660"
  '';

  # kvm group membership for /dev/kvm. On current systemd /dev/kvm is created
  # world-accessible (0666) by the default rule, so this is belt-and-braces
  # rather than strictly required today — but it is the correct grant if that
  # default ever tightens, and it is the group /dev/vhost-vsock is regrouped
  # to above. Co-located with the capability that needs it (extraGroups merges
  # across modules), per the #341 pattern in networking-networkmanager.nix.
  users.users.${operator.name}.extraGroups = [ "kvm" ];
}
