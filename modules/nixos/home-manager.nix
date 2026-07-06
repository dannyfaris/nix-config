# Home-manager NixOS-module wrapper for the operator. The wiring body is
# single-sourced in lib/mk-home-manager.nix (values-only twin, #541); this
# shell contributes the three platform constants. Linux: the XDG cache dir
# for zellij's permissions.kdl; `nixosConfigurations` for nixd's
# option-eval exprs (#335).
let
  operator = import ../../lib/operator.nix;
in
import ../../lib/mk-home-manager.nix {
  homeDirectory = operator.linuxHome;
  zellijCacheDir = "${operator.linuxHome}/.cache/zellij";
  flakeConfigAttr = "nixosConfigurations";
}
