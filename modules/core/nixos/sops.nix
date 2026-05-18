# sops-nix configuration and secret declarations.
{
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets.dbf-password = {
      neededForUsers = true;
    };
  };
}
