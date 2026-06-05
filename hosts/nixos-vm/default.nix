# Host-specific configuration for the UTM VM (aarch64-linux).
#
# Composes foundation + capability bundles + standalone modules directly
# (per ADR-027), no longer adopts the `headless` role. Standalones:
# bare-metal-VM platform modules (systemd-boot, NetworkManager) and
# Tailscale.
{ ... }:

{
  imports = [
    ./hardware.nix

    # Foundation — bundle every NixOS host imports by convention.
    ../../modules/nixos/foundation.nix

    # Capability bundles.
    ../../modules/nixos/bundles/remote-access.nix

    # Standalone system modules.
    ../../modules/nixos/boot-systemd.nix
    ../../modules/nixos/networking-networkmanager.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/unit-failure-notifier.nix # Fan systemd unit failures to ntfy over the tailnet (#199).
  ];

  networking.hostName = "nixos-vm";

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";

  # Per-host parametrisation consumed by home-manager modules
  # (editor.nix nixd options, nix-tooling NH_FLAKE). Set via the typed
  # option layer in modules/nixos/host-context.nix; bridged to
  # extraSpecialArgs via the host-context module's _module.args write.
  # See ADR-019.
  #
  # extraHomeModules is the full HM imports list for this host — capability
  # bundles plus standalone modules, per ADR-027's bundle model. Personal
  # dev box: cli tooling + dual git identity + GitHub CLI + agent CLI
  # extras + login info display + base agent CLIs + outbound SSH.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "nixos-vm";
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      ../../home/shared/bundles/git-multi-identity.nix
      ../../home/shared/stylix-targets.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
