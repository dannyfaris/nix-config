# hostContext for Darwin hosts. The typed option schema and the
# `_module.args` bridge are single-sourced in lib/mk-host-context.nix
# (values-only twin, #541); this shell contributes only the platform
# default for flakePath — the operator's Darwin home.
let
  operator = import ../../lib/operator.nix;
in
import ../../lib/mk-host-context.nix {
  defaultFlakePath = "${operator.darwinHome}/${operator.flakeRepoDirname}";
}
