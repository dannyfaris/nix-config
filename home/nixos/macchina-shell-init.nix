# Linux shell-init half of the macchina wiring — sets
# `programs.fish.interactiveShellInit` to print the system-info banner
# at every interactive fish shell launch (Ghostty tab, zellij pane,
# helix `:sh`, every login). Behaviour change from the prior login-only
# trigger; the banner is the SSH-context anchor and the operator wants
# it visible on every new shell.
#
# Linux-only because interface detection uses iproute2 (`ip addr show`,
# `ip -o route get`). The Darwin sibling at
# `home/darwin/macchina-shell-init.nix` uses `route -n get default`.
# Hosts of either platform import this sibling alongside
# `home/shared/macchina.nix` (package + theme + ASCII).
#
# `lib.mkBefore` pins this block ahead of `home/shared/shell.nix`'s
# `interactiveShellInit` (starship's transient-prompt machinery). Both
# set the same `lib.types.lines` option; equal-priority concatenation
# order tracks import order, which is fragile across host configs.
# mkBefore (priority 500 vs default 1000) lands first in the
# concatenation regardless of import order.
#
# Interface priority: tailscale0 when present with an assigned IPv4,
# otherwise the interface the kernel would actually use for outbound
# traffic (queried via `ip route get`, which respects metric, policy,
# and multi-default-route precedence; `ip route show default | first`
# is unreliable on multi-homed hosts). Runs without --interface if
# neither resolves — Local IP readout is simply absent. The
# `command -q macchina` guard prevents a startup error if macchina is
# transiently missing from PATH (e.g. during a partial activation).
{ lib, ... }:
{
  programs.fish.interactiveShellInit = lib.mkBefore ''
    if command -q macchina
        if ip addr show tailscale0 2>/dev/null | string match --quiet --regex 'inet '
            macchina --interface tailscale0
        else
            set -l _iface (ip -o route get 192.0.2.1 2>/dev/null \
                | string replace --regex --filter '.*\bdev\s+(\S+).*' '$1')[1]
            if test -n "$_iface"
                macchina --interface $_iface
            else
                macchina
            end
        end
    end
  '';
}
