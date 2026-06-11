# 1Password desktop GUI — the operator's password manager on the metis
# Wayland desktop (browser autofill + app logins), matching macOS.
#
# Selection, scope, and the deliberate exclusions live in
# docs/desktop/1password.md §"NixOS desktop adoption (metis)" (#112):
# GUI only — the `op` CLI is deferred and 1Password is deliberately NOT the
# SSH agent. `_1password-gui` is unfree; its whitelist entry is in
# modules/shared/nix-daemon.nix.
_:
let
  operator = import ../../lib/operator.nix;
in
{
  programs._1password-gui = {
    enable = true;
    # Wire the operator into polkit-based unlock (mate-polkit is the live
    # agent, #103). Without an owner here, system-auth unlock is refused.
    polkitPolicyOwners = [ operator.name ];
  };

  # The GUI module creates the `onepassword` group and the setgid
  # 1Password-BrowserSupport wrapper, but does NOT add the operator to the
  # group — browser integration silently fails without membership. Merges
  # with the base extraGroups in modules/nixos/users.nix.
  users.users.${operator.name}.extraGroups = [ "onepassword" ];
}
