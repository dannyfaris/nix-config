# linux-builder — nix-darwin's built-in Linux build VM, used to build
# Linux derivations on a Mac. The mac-mini imports this so it can
# verify nixosConfigurations cross-platform (PRD §10 + §11.6 bus-factor
# test); the operator runs e.g.
#
#   nix build .#nixosConfigurations.nixos-vm.config.system.build.toplevel
#
# on the Mac and the daemon offloads the build into the linux-builder
# VM, returning the resulting closure into the host's store.
#
# `nix.linux-builder.enable = true` provisions a launchd-managed VM
# image persistent at `/var/lib/linux-builder/`, plus an SSH keypair
# at `/etc/nix/builder_ed25519` and the system's `nix.buildMachines`
# entry. nix-darwin handles all the wiring; no manual steps post
# activation.
#
# Default `nix.linux-builder.systems` is derived from the builder VM's
# host platform — `[ cfg.package.nixosConfig.nixpkgs.hostPlatform.system ]`,
# which resolves to `aarch64-linux` on Apple Silicon. Explicit
# assignment here pins behaviour against a future builder-package
# swap. x86_64 NixOS hosts (mercury, metis) need a different builder
# package (Rosetta emulation), deferred until first activation
# succeeds per the #11 plan.
#
# Resource tuning, if mercury's closure doesn't fit: bump
# `nix.linux-builder.config.virtualisation.{cores,memorySize,diskSize}`
# in the host file. nix-darwin's defaults are conservative.
#
# `nix.settings.trusted-users` carries `@admin` (which includes `dbf`
# on the sudo-able operator account macOS creates) alongside the
# upstream-default `root` — without it, `nix build` invoked from the
# operator shell can't drive the remote build and silently falls back
# to local-only. The linux-builder module does NOT add to
# `trusted-users` automatically (upstream sets just `root`), so
# importing this module wires what's needed end-to-end rather than
# leaving the operator to chase a half-working setup.
#
# Standalone module per ADR-027 (no coherent sibling yet to graduate
# into a bundle).
_: {
  nix.linux-builder = {
    enable = true;
    systems = [ "aarch64-linux" ];
  };

  nix.settings.trusted-users = [
    "root"
    "@admin"
  ];
}
