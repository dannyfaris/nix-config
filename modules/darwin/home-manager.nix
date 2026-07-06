# Home-manager nix-darwin-module wrapper for the operator. The wiring body
# is single-sourced in lib/mk-home-manager.nix (values-only twin, #541);
# this shell contributes the three platform constants. macOS: zellij's
# permissions.kdl lives in the Caches bundle dir, not XDG;
# `darwinConfigurations` for nixd's option-eval exprs (#335). The
# nix-darwin home-manager module itself is wired into the system module
# set by lib/mk-darwin-host.nix; this file configures it.
let
  operator = import ../../lib/operator.nix;
in
import ../../lib/mk-home-manager.nix {
  homeDirectory = operator.darwinHome;
  zellijCacheDir = "${operator.darwinHome}/Library/Caches/org.Zellij-Contributors.Zellij";
  flakeConfigAttr = "darwinConfigurations";
}
