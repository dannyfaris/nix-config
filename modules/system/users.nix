# User declaration. Fully declarative — mutableUsers = false makes this the
# sole source of truth for user state.
{ config, ... }:

let
  # Public key from the Mac dev machine. Sole SSH credential for dbf.
  macSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNUroaa0Z3VyMJVnnQWTtuaosFL30E6xDsSUEAuS8MI daniel.faris@gotaxi.co.nz";
in
{
  users.mutableUsers = false;
  users.users.dbf = {
    isNormalUser = true;
    description = "Daniel";
    extraGroups = [ "wheel" "networkmanager" ];

    hashedPasswordFile = config.sops.secrets.dbf-password.path;

    openssh.authorizedKeys.keys = [ macSshKey ];
  };
}
