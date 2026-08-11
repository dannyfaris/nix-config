# Disko disk layout for Hadar (HP ProDesk Mini 600 G9, bare metal,
# x86_64 — the former metis hardware redeployed off-site, #798).
# Alcyone-shape — the fleet default for new hosts (#637 decision 1;
# headless-bootstrap.md §Decisions). The metis-era layout was
# unencrypted/three-subvolume; this is a full reformat, not a retrofit.
#
# UEFI GPT: 2 GiB ESP, rest a LUKS2 container holding btrfs with four
# flat subvolumes @root / @home / @persist / @nix (the `@` prefix avoids
# disko#442's mktemp -d collision). Mount options exclude
# `discard=async` and `ssd`: both are auto-applied by Linux 6.2+ on
# capable devices, so listing them would be noise.
#
# Encryption — Option A (#631 / #557): LUKS2 + systemd-cryptenroll TPM2
# auto-unseal. Off-site custody (#641: "someone else's spare room", not
# the operator's locked room) makes encryption-at-rest near-mandatory
# here. Two things are deliberately NOT declarative:
#   1. The TPM keyslot is enrolled POST-INSTALL, on-metal
#      (`systemd-cryptenroll --tpm2-device=auto
#      /dev/disk/by-partlabel/disk-main-luks`, the partlabel disko
#      generates for this partition) — it writes a keyslot bound to this
#      physical TPM+device and cannot be baked into a portable layout.
#      Procedure: headless-bootstrap.md §Encrypted hosts. Intel PTT is
#      expected on this platform but is NOT harvest-confirmed (the metis
#      era never used it) — the install-day BIOS checklist must verify
#      TPM 2.0 active before relying on unattended unseal (#798).
#   2. The install-time passphrase IS the ADR-043 recovery passphrase
#      (1Password vault + offline copy, never in repo/sops). It reaches
#      disko via nixos-anywhere `--disk-encryption-keys /tmp/disko-password
#      <local-file>` at format time (see the runbook).
# `crypttabExtraOpts = [ "tpm2-device=auto" ]` makes the systemd initrd
# try the TPM first and fall back to the passphrase: the very first boot
# (pre-enrollment) unlocks by passphrase at the physical console; every
# boot after enrollment unseals unattended — surviving power loss with
# no SSH/manual unlock, non-negotiable for an always-on box whose
# console is a different building away.
#
# Custody invariant (ADR-043, from #526): the SSH host key is NOT
# TPM-bound. TPM unlocks root → /persist/etc/ssh/ssh_host_ed25519_key
# exists as a plain file → sops reads the host's age identity from it.
#
# Device /dev/nvme0n1 matches the metis-era install on this same
# machine; still verify with `lsblk` from the live USB before invoking
# nixos-anywhere — the ProDesk Mini 600 G9 ships in multiple storage
# variants (NVMe SSD, SATA SSD). See ADR-022 / ADR-023, disko#442.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          # 2 GiB — comfortable for the retained systemd-boot generations
          # (kernel + initrd per generation); matches the fleet shape.
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
              # signature (reinstall over the metis-era filesystem on the
              # same disk).
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
                # Greenfield reinstall: carried from first boot, no online
                # retrofit (the metis era needed one). neededForBoot is
                # asserted host-side (impermanence requirement).
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
