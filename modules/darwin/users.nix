# User declaration for Darwin hosts.
#
# Unlike NixOS (where `users.users.<name>` fully owns the account
# under `users.mutableUsers = false`), macOS owns user creation
# itself — the account exists from first-boot setup. nix-darwin
# manages only the subset of attributes declared here, gated on the
# user appearing in `users.knownUsers` (the safety list: nix-darwin
# refuses to touch users not in this list).
#
# `users.users.${operator.name}.uid` is **host-specific** and must be
# pinned in the host's default.nix to whatever `id -u dbf` returns on
# that machine. nix-darwin refuses to manage a user whose UID it
# didn't create unless the host declares the UID explicitly. The
# pre-bootstrap step in docs/runbooks/darwin-bootstrap.md (PR 7 of
# the mac-mini onboarding epic #11) collects the UID.
#
# Identity attributes (name, description) come from lib/operator.nix
# per #49 so the same record feeds both the NixOS and Darwin user
# declarations.
{ pkgs, hostContext, ... }:

let
  operator = import ../../lib/operator.nix;
in
{
  users.knownUsers = [ operator.name ];
  users.users.${operator.name} = {
    inherit (operator) description;
    shell = pkgs.fish;
    home = operator.darwinHome;

    # Load-bearing path for inbound SSH key auth on Darwin. nix-darwin's
    # `services.openssh.enable` ships /etc/ssh/sshd_config.d/101-authorized-keys.conf,
    # which sets `AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u`
    # (sshd won't follow ~/.ssh/authorized_keys when it's a /nix/store symlink,
    # which is what home-manager's `home.file` produces). That command's source
    # file is populated from this option. Keys derived from the declared
    # trust edges (ADR-042): this host's sshEdges entry mapped through
    # hostKeys; an absent entry throws (whitelist). Mirrors
    # modules/nixos/users.nix.
    openssh.authorizedKeys.keys = map (
      src: operator.hostKeys.${src}
    ) operator.sshEdges.${hostContext.hostName};
  };

  # Identifies the macOS account that user-domain defaults
  # (system.defaults.NSGlobalDomain.*, system.defaults.dock.*,
  # system.defaults.CustomUserPreferences.*) are written for at
  # activation. nix-darwin refuses to evaluate any option marked
  # `requiresPrimaryUser` without this being set — touched first by
  # modules/darwin/homebrew.nix's Sparkle keys (ADR-031). Identity
  # comes from the same lib/operator.nix record as the user
  # declaration above.
  system.primaryUser = operator.name;

  # System-side fish enable. On nix-darwin this is a PATH-safety check
  # for fish-aware modules (it does NOT populate /etc/shells — that's
  # `environment.shells` below). nix-darwin's user-shell change uses
  # `dscl` directly, which doesn't consult /etc/shells, so the login
  # path works either way; `environment.shells` is the entry that lets
  # `chsh` (and any other /etc/shells-gated tool) accept fish.
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
}
