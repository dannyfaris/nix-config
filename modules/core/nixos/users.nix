# User declaration. Fully declarative — mutableUsers = false makes this the
# sole source of truth for user state. Identity attributes (name,
# description, SSH keys) come from lib/operator.nix per #49 so the same
# record will feed a sibling modules/core/darwin/users.nix when Darwin
# lands (epic #11).
{ config, pkgs, ... }:

let
  operator = import ../../../lib/operator.nix;
in
{
  users.mutableUsers = false;
  users.users.${operator.name} = {
    isNormalUser = true;
    inherit (operator) description;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    hashedPasswordFile = config.sops.secrets.dbf-password.path;

    openssh.authorizedKeys.keys = operator.authorizedKeys;

    # fish as the login shell. Requires programs.fish.enable below — the
    # system-side enable is what registers fish in /etc/shells, which is
    # the gate for being a valid login shell. Without it, switching the
    # shell to a home-manager-only fish would lock the user out at next
    # login. See docs/decisions/ADR-001-shell.md.
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
}
