# sops-nix configuration for Darwin hosts.
#
# Uses the operator's user age key at
# `~/.config/sops/age/keys.txt` — derived from `~/.ssh/id_ed25519` via
# `ssh-to-age -private-key` as part of pre-bootstrap (documented in
# docs/runbooks/darwin-bootstrap.md once it lands). Matches the
# `dbf@mac` recipient already declared in `.sops.yaml`; the same age
# key has decrypted `secrets/secrets.yaml` for the operator since
# 2026-05-25.
#
# Distinct from the NixOS-side `sops.age.sshKeyPaths` shape: NixOS
# decrypts at activation via the host's `/etc/ssh/ssh_host_ed25519_key`
# (a host identity); Darwin uses the operator's user identity directly.
# That's the explicit choice — the Mac is the operator's machine and
# doesn't need a separate host identity for sops, and the user key is
# already in `.sops.yaml` as `dbf@mac`.
#
# No `secrets.dbf-password.neededForUsers`: macOS owns the login
# password (via the standard macOS account creation flow), not the
# config. Nothing here corresponds to NixOS's
# `users.users.dbf.hashedPasswordFile` chain.
_:

let
  operator = import ../../lib/operator.nix;
in
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "${operator.darwinHome}/.config/sops/age/keys.txt";
  };
}
