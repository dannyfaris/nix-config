# System info display on login — Macchina with the Hydrogen theme.
# Scoped to nixos-vm and metis via extraHomeModules; not on Mercury
# (EC2 work host where login noise is unwanted).
{ pkgs, ... }: {
  home.packages = [ pkgs.macchina ];

  xdg.configFile."macchina/macchina.toml".text = ''
    theme = "Hydrogen"
  '';

  # Themes are not bundled in the nixpkgs package — pull directly from
  # the macchina source derivation so the reference in macchina.toml resolves.
  xdg.configFile."macchina/themes/Hydrogen.toml".source =
    "${pkgs.macchina.src}/contrib/themes/Hydrogen.toml";

  # loginShellInit runs once on SSH login, not on every zellij pane open.
  # Guard prevents a startup error if macchina is transiently missing from PATH.
  programs.fish.loginShellInit = "command -q macchina; and macchina";
}
