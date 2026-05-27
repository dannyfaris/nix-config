# Ghostty terminfo entry (xterm-ghostty) — extracted from system-packages
# so it can sit in the remote-access bundle alongside sshd + mosh, which
# is what makes it relevant.
#
# Required so ncurses-based tools (htop, less, etc.) work when SSHing
# into this host from a Ghostty terminal on the client side. Without it,
# those tools fail at startup with "cannot initialize terminal type".
# This is the terminfo-only output of pkgs.ghostty — doesn't pull in the
# full terminal app.
#
# During slices 2–3 of the role-removal migration this entry is
# duplicated in modules/core/nixos/system-packages.nix. The two
# `environment.systemPackages = [ pkgs.ghostty.terminfo ]` declarations
# concatenate into the merged list (list-option merging is
# concatenation, NOT set union), but `pkgs.buildEnv` deduplicates
# store paths when assembling `system-path` (the symlink farm), so the
# resulting runtime closure is byte-identical to a single declaration.
# The duplicate line in system-packages.nix is removed in slice 4 once
# the role and its direct system-packages import are retired.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];
}
