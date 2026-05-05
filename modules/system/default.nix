# Shared system-tier NixOS modules.
{ lib, pkgs, ... }:

let
  # Public key from the Mac dev machine. Sole SSH credential for dbf.
  macSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNUroaa0Z3VyMJVnnQWTtuaosFL30E6xDsSUEAuS8MI daniel.faris@gotaxi.co.nz";
in
{
  # --- Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # --- Locale
  time.timeZone = "Pacific/Auckland";
  i18n.defaultLocale = "en_NZ.UTF-8";

  # --- Nix daemon settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Hardlink-dedupe /nix/store on write.
    auto-optimise-store = true;

    # Active dev repos are dirty most of the time; the warning is noise.
    warn-dirty = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Flakes don't generate programs.sqlite; leaving this on silently fails.
  programs.command-not-found.enable = false;

  # Whitelist unfree packages by name. Do NOT replace with allowUnfree = true.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  # --- SSH: key-only, no root, no password fallback
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- Users: fully declarative
  # mutableUsers = false makes this the sole source of truth for user state.
  users.mutableUsers = false;
  users.users.dbf = {
    isNormalUser = true;
    description = "Daniel";
    extraGroups = [ "wheel" "networkmanager" ];

    # TODO: switch to hashedPasswordFile via sops-nix (see TODO.md tier 2).
    hashedPassword = "REDACTED_HASH";

    openssh.authorizedKeys.keys = [ macSshKey ];
  };

  # --- System packages (administration tools only)
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
  ];
}
