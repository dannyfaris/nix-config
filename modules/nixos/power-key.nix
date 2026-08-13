# Power key on interactive desktops is bound to a niri action (session lock
# — home/nixos/niri.nix) rather than left to logind's own handling. Ignoring
# it here is the other half of that: logind stops short-circuiting the key
# itself, at the greeter and whenever niri isn't holding the inhibitor
# (#651).
#
# Accepted consequence: outside a live niri session — at the greeter, or with
# a crashed compositor — the key now does nothing on these hosts, so there is
# no clean poweroff from it. Recovery is the console (CLAUDE.md §Break-glass)
# or a firmware hard cut. Electra keeps poweroff for exactly that reason.
{
  services.logind.settings.Login.HandlePowerKey = "ignore";
}
