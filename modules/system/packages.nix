# System packages — administration tools available to all users regardless
# of home-manager state. Per-user dev tooling lives in modules/home/.
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
  ];
}
