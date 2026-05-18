# User declaration. Fully declarative — mutableUsers = false makes this the
# sole source of truth for user state.
{ config, pkgs, ... }:

let
  # Public key from the Mac dev machine. Sole SSH credential for dbf.
  macSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNUroaa0Z3VyMJVnnQWTtuaosFL30E6xDsSUEAuS8MI dbf@mac";
in
{
  users.mutableUsers = false;
  users.users.dbf = {
    isNormalUser = true;
    description = "Daniel";
    extraGroups = [ "wheel" "networkmanager" ];

    hashedPasswordFile = config.sops.secrets.dbf-password.path;

    openssh.authorizedKeys.keys = [ macSshKey ];

    # fish as the login shell. Requires programs.fish.enable below — the
    # system-side enable is what registers fish in /etc/shells, which is
    # the gate for being a valid login shell. Without it, switching the
    # shell to a home-manager-only fish would lock the user out at next
    # login. See docs/decisions/ADR-001-shell.md.
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
}
