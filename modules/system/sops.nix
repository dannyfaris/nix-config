# sops-nix configuration and secret declarations.
{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.dbf-password = {
    neededForUsers = true;
  };
}
