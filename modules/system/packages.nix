# System packages (administration tools only)
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
  ];
}
