# Disko disk layout for Alnair (Surface Laptop 4 15″ Intel 1978, bare
# metal, x86_64). Encrypted-at-rest from install — the Alcyone pattern
# (#631) reused unchanged (#636): a roaming laptop is the fleet's
# strongest theft case, so encryption is *more* warranted here.
#
# UEFI GPT: 2 GiB ESP, rest a LUKS2 container holding btrfs with four
# flat subvolumes @root / @home / @persist / @nix (the `@` prefix avoids
# disko#442's mktemp -d collision). Mount options exclude `discard=async`
# and `ssd`: both are auto-applied by Linux 6.2+ on capable devices.
#
# Encryption — Option A (#631 / #557): LUKS2 + systemd-cryptenroll TPM2
# auto-unseal. Two things are deliberately NOT declarative here:
#   1. The TPM keyslot is enrolled POST-INSTALL, on-metal
#      (`systemd-cryptenroll --tpm2-device=auto
#      /dev/disk/by-partlabel/disk-main-luks`) — it binds this physical
#      TPM+device and cannot be baked into a portable layout.
#      Procedure: headless-bootstrap.md §Encrypted hosts.
#   2. The install-time passphrase IS the ADR-043 recovery passphrase
#      (1Password vault + offline copy, never in repo/sops). It reaches
#      disko via nixos-anywhere `--disk-encryption-keys` (justfile
#      `bootstrap` recipe, keyfile argument).
# `crypttabExtraOpts = [ "tpm2-device=auto" ]` makes the systemd initrd
# try the TPM first and fall back to the passphrase — first boot
# (pre-enrollment) unlocks by passphrase; every boot after unseals
# unattended. Requires `boot.initrd.systemd.enable` (set in default.nix).
# The built-in keyboard at that fallback prompt needs the SAM chain in
# the initrd — modules/nixos/surface.nix.
#
# Custody invariant (ADR-043, from #526): the SSH host key is NOT
# TPM-bound. TPM unlocks root → /etc/ssh/ssh_host_ed25519_key exists as a
# plain file → sops reads the host's age identity from it.
#
# Device /dev/nvme0n1 confirmed on-metal (#636 harvest: KIOXIA
# KBG40ZNS256G 256 GB, the only drive). TPM 2.0 present, Secure Boot in
# setup mode, box already LUKS today. See ADR-022 / ADR-023, disko#442.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          # 2 GiB — comfortable for the retained systemd-boot generations
          # (kernel + initrd per generation); matches metis/alcyone.
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0022"
              "dmask=0022"
            ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot"; # → /dev/mapper/cryptroot
            # Install-time passphrase = the ADR-043 recovery passphrase,
            # supplied by the operator via nixos-anywhere
            # --disk-encryption-keys (writes /tmp/disko-password on the
            # installer). Never a repo/sops secret.
            passwordFile = "/tmp/disko-password";
            settings = {
              allowDiscards = true;
              # systemd initrd tries the TPM2 keyslot first, falls back to
              # the passphrase. The TPM keyslot is enrolled post-install
              # (see header); until then boot prompts for the passphrase.
              crypttabExtraOpts = [ "tpm2-device=auto" ];
            };
            content = {
              type = "btrfs";
              # -L nixos: filesystem label. -f: overwrite any prior
              # signature (this disk carries the Omarchy install — same
              # stale-signature class that bit Alcyone's ESP on install day).
              extraArgs = [
                "-L"
                "nixos"
                "-f"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "subvol=@root"
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "subvol=@home"
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
                # Persist whitelist backing store (docs/design/ephemeral-root.md).
                # Greenfield host: carried from first boot, no online retrofit.
                # neededForBoot is asserted host-side (impermanence requirement).
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "subvol=@persist"
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "subvol=@nix"
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
