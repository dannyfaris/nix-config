# sops-nix configuration and secret declarations.
{ config, lib, ... }:
let
  # The mount point of the fileSystems entry that CONTAINS `path` — the
  # longest declared mount that is a prefix of it, so /persist/etc/ssh/…
  # resolves to the /persist mount rather than to /.
  fsMountFor =
    path:
    lib.foldl' (best: m: if lib.stringLength m > lib.stringLength best then m else best) "/" (
      lib.filter (m: m == path || lib.hasPrefix (if m == "/" then "/" else m + "/") path) (
        lib.attrNames config.fileSystems
      )
    );
in
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    # No explicit age.sshKeyPaths. sops-nix's upstream default derives the age
    # identity from services.openssh.hostKeys (ed25519 entries mapped to their
    # .path), so the sops decryption key FOLLOWS sshd's key locations from a
    # single knob. Two knobs naming the key path independently — sshd's keys on
    # /persist while sops still read the wiped /etc/ssh — is the exact anatomy
    # of the #553 auth-lockout incident. Single-knob by construction; see
    # docs/design/ephemeral-root.md.

    secrets.dbf-password = {
      neededForUsers = true;
    };
  };

  # Invariant guarding the #553 class: under persist enforcement every resolved
  # sops age identity must live on a neededForBoot filesystem. sops-nix decrypts
  # neededForUsers secrets in early boot (before the ephemeral root is even
  # relevant), so an identity on the wiped root would lock the host out. The
  # guard walks each key path's containing mount and requires neededForBoot;
  # trivially true on non-persist hosts (the `!persist.enable` short-circuit),
  # so it evaluates harmlessly fleet-wide. See docs/design/ephemeral-root.md.
  assertions = [
    {
      assertion =
        !config.persist.enable
        || lib.all (
          p: config.fileSystems.${fsMountFor (toString p)}.neededForBoot or false
        ) config.sops.age.sshKeyPaths;
      message =
        "sops.age.sshKeyPaths must resolve onto a neededForBoot filesystem when "
        + "persist.enable is set — a key on the ephemeral root is wiped at reboot "
        + "and locks the host out (#553). Resolved paths: "
        + toString config.sops.age.sshKeyPaths;
    }
  ];
}
