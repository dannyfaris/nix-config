# System packages — administration tools and terminal-compatibility data
# available to all users regardless of home-manager state. Per-user dev
# tooling lives in home/core/nixos/.
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
    curl

    # Ghostty's terminfo entry (xterm-ghostty). Required so ncurses-based
    # tools (htop, less, etc.) work when SSHing into this box from a
    # Ghostty terminal on the client side. Without it, those tools fail
    # at startup with "cannot initialize terminal type". This is the
    # terminfo-only output of pkgs.ghostty — doesn't pull in the full
    # terminal app.
    ghostty.terminfo
  ];
}
