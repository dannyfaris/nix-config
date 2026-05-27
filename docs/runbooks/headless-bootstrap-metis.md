# Headless bootstrap — Metis (bare-metal HP ProDesk 600 G3 Desktop Mini)

> **Superseded by [headless-bootstrap.md](./headless-bootstrap.md)** (2026-05-25).
>
> This runbook describes the pre-ADR-022 procedure: manual
> `parted`/`mkfs`/`btrfs subvolume` partitioning, a two-pass install
> (stock NixOS then flake), post-boot host-key harvest, and surgical
> kernel-modules merge into a mixed-content `hardware.nix`. It is
> preserved unchanged for historical reference; do not follow it for
> new hosts. The current procedure uses `nixos-anywhere` + `disko` with
> pre-injected host SSH keys and the three-file per-host structure
> (`default.nix` / `disko.nix` / `hardware-configuration.nix`).

Operational procedure for bringing Metis up on bare metal from a fresh disk
to a fully-managed `nh os switch` target. Metis is an x86_64-linux personal
dev box adopting the `headless` role (per `parts/nixos.nix` and
`hosts/metis/default.nix`).

Companion to [headless-bootstrap-aws.md](./headless-bootstrap-aws.md), which
covers the AWS path (Mercury). The shape is the same — install, harvest host
key, re-encrypt sops, switch into the flake — but the install step is a
manual disk partition rather than an AMI launch, and the per-host
considerations (encryption, swap, filesystem, BIOS) are decided here rather
than inherited from the cloud image.

## Decisions baked into this runbook

These are deliberate choices for Metis, not defaults. Each one is
hard or impossible to retrofit; if you're bootstrapping a *different* bare-
metal host later, re-evaluate before copying this runbook verbatim.

| Decision | Choice | Reason |
|---|---|---|
| Full-disk encryption | **None** | Daniel is often out of town for days; unattended reboot after a power-cut is essential. LUKS would mean the box stays down until someone enters the passphrase at the console. |
| Filesystem | **btrfs** with three flat subvolumes (`root`, `home`, `nix`) | Per-subvolume mount options + a clean foundation we can layer Snapper onto later if needed. No snapshot tooling is enabled today; the layout deliberately keeps that door open without committing to it. |
| Swap | **zram only** (no disk swap) | 32 GB RAM with a compressed RAM-backed swap as an overflow valve for cold anonymous pages. Keeps reclaim graceful under load with zero SSD wear. No hibernate needed on a headless box. |
| Boot | **systemd-boot, UEFI, Secure Boot off** | Matches `modules/core/nixos/boot-systemd.nix`. `lanzaboote` is not in this config. |
| ESP size | **2 GiB** | systemd-boot copies each generation's kernel + initrd to the ESP; 2 GiB is comfortable for 15-20 retained generations. |
| Periodic scrub | **`services.btrfs.autoScrub.enable`** (monthly default) | Detects silent bit-rot by checksum verification; cheap insurance on a single-device btrfs filesystem. |

## Prerequisites on the operator's machine

The "operator's machine" here is `nixos-vm` — the UTM VM is currently the
only machine holding an age decryption identity for `secrets/secrets.yaml`.
Some steps run there; others run at Metis's console or over SSH to Metis.
Each step below is marked `[vm]` or `[metis]`.

- Access to this repo (clone, commit, push permission).
- `nix` with flakes enabled, plus the ability to run `nix shell nixpkgs#<pkg>`.
- **Confirm Daniel's Mac SSH key in `modules/core/nixos/users.nix:7`
  matches the private key on the Mac you'll use to SSH into Metis.** That
  key is hardcoded as the sole inbound credential for `dbf` once Metis
  switches into the flake. If you've rotated the Mac key since `users.nix`
  was last touched, fix it on the VM first (commit a new key, switch,
  verify SSH still works), then begin the Metis bootstrap. Console
  keyboard is your only recovery if this is wrong.
- A blank ≥ 4 GB USB stick.
- A monitor (HDMI or DP) and USB keyboard for Metis's console — physically
  reachable until at least Phase 6 verification completes.

## Phase 1 — Make install media

`[vm]` Download the latest NixOS 25.11 minimal ISO for `x86_64-linux` from
https://nixos.org/download. Minimal is fine — Metis is headless.

`[vm]` UTM cannot pass through physical USB, so flash from the Mac, not the
VM. Copy the ISO to the Mac and use `dd`, Raspberry Pi Imager, or Etcher to
write it. Verify the SHA-256 against nixos.org before flashing.

If Metis's eventual install location has Wi-Fi only (no ethernet),
double-check the ProDesk's Wi-Fi chipset — some Intel cards need the
NixOS unfree-firmware ISO build (also published on nixos.org), not the
stock minimal ISO.

## Phase 2 — BIOS preparation

`[metis]` With monitor and USB keyboard attached, power on and tap **F10**
to enter BIOS Setup (HP ProDesk 600 G3 default).

Settings to confirm or change:

- **Security → Secure Boot: disable.** NixOS doesn't ship a signed shim
  by default and `lanzaboote` isn't in this config.
- **Advanced → Boot Options: UEFI enabled, Legacy/CSM disabled.**
  systemd-boot is UEFI-only.
- **Advanced → Power-On Options → After Power Loss: On** (or "Previous
  State"). The headline reason this box is unencrypted — it must come back
  up unattended after a power-cut. Without this, you're flying back home
  to press the power button.
- **Advanced → Power-On Options → Wake-on-LAN: enabled** (optional but
  cheap). Lets you wake the box from another tailnet node if it's been
  powered off cleanly.
- **Check BIOS firmware version against HP's support page.** HP push
  microcode/security updates regularly. Updating from the pre-OS HP
  firmware updater is much less fiddly than from Linux. Easier to do now
  than later.

Save and exit (F10), then tap **F9** at POST for the one-shot boot menu
and pick the USB. The NixOS installer should boot to a `nixos@nixos`
shell.

## Phase 3 — Partition, format, mount

The strategy is two-pass: install a stock NixOS off the ISO first (no
flake) to get a system on disk with networking + SSH; then in Phase 5
clone the flake and switch into the real config. Trying to install
directly with `nixos-install --flake` is possible but means the ISO needs
all the sops/secrets plumbing before you've even harvested the host key —
easier to do it in two passes.

### Confirm the target device

`[metis]` **Do not assume `/dev/nvme0n1`.** The ProDesk 600 G3 Desktop Mini ships
in multiple variants (NVMe SSD, SATA SSD, occasionally an HDD too). From
the installer shell:

```bash
lsblk
```

Identify the disk you intend to install onto. Substitute its name into
the commands below wherever `nvme0n1` appears. Double-check before
running `parted` — `mklabel gpt` against the wrong device is the kind of
mistake that ends an afternoon.

### Get on the network

`[metis]` Wired ethernet should pick up DHCP automatically. Confirm:

```bash
ip a
ping -c 2 nixos.org
```

For Wi-Fi: `sudo systemctl start wpa_supplicant` then `wpa_cli` to add
the network, or `nmtui` if present.

### Partition the disk

`[metis]` UEFI GPT, 2 GiB ESP, rest as btrfs root. Labels (`boot`,
`nixos`) match the placeholder in `hosts/metis/hardware.nix` so the
intermediate config is at least bootable until Phase 6 swaps in the
real hardware.nix.

```bash
sudo -i
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 2GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 2GiB 100%
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2
```

### Create btrfs subvolumes

`[metis]` Three flat subvolumes — one per top-level mount that benefits
from independent mount options or a separate identity in `mount` output:

- `root` for `/` — system root.
- `home` for `/home` — user data, kept distinct so future snapshot
  cadences can diverge from `/` without restructuring.
- `nix` for `/nix` — the store is large and reproducible; isolating it
  keeps options like compression tunable without touching user data.

No `@snapshots` subvolume — snapshot tooling is intentionally not part of
this bootstrap (see Decisions table). Subvolumes can be added later
without disrupting the existing layout.

```bash
mount /dev/disk/by-label/nixos /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
umount /mnt
```

### Mount with the right options

`[metis]` Pin each mount to its subvolume; match the options committed in
`hosts/metis/hardware.nix` so the installed system mounts the same way:

```bash
MOPTS=compress=zstd:1,noatime,ssd,discard=async
mount -o subvol=root,$MOPTS /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/{boot,home,nix}
mount -o subvol=home,$MOPTS /dev/disk/by-label/nixos /mnt/home
mount -o subvol=nix,$MOPTS  /dev/disk/by-label/nixos /mnt/nix
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

Mount option rationale:

- `subvol=<name>` — without this each mount would expose the top-level
  subvolume tree instead of the intended slice.
- `compress=zstd:1` — fast compression with real disk savings on the nix
  store. `:1` is the lowest CPU cost; raise later if you want more
  compression for less CPU.
- `noatime` — don't update access times on read. Standard for SSDs and
  CoW-friendly.
- `ssd` — SSD-aware allocator behaviour (auto-detected on modern btrfs,
  set explicitly to match the committed config).
- `discard=async` — batched TRIM, smoother than synchronous discard and
  preferable to a separate `fstrim.timer` on modern kernels.
- `umask=077` on `/boot` — install-time only; the running system remounts
  per `hardware.nix` (`fmask=0022,dmask=0022`) after the Phase 6 switch.

## Phase 4 — Install a minimal NixOS

`[metis]` Generate the install-time config:

```bash
nixos-generate-config --root /mnt
```

Edit `/mnt/etc/nixos/configuration.nix` to a minimum that lets you SSH
back in on next boot. Set the hostname explicitly, enable sshd, install
Daniel's Mac key for root (temporary — `users.nix` will replace this in
Phase 5), enable flakes, declare btrfs support:

```nix
{ pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "btrfs" ];

  networking.hostName = "metis";
  networking.networkmanager.enable = true;
  time.timeZone = "Pacific/Auckland";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNUroaa0Z3VyMJVnnQWTtuaosFL30E6xDsSUEAuS8MI dbf@mac"
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";
}
```

The root SSH key is the cheap way in for the next phase; it vanishes the
moment the flake's `users.nix` (with `mutableUsers = false` and no root
SSH key) activates in Phase 5.

`[metis]` Install and reboot:

```bash
nixos-install --no-root-passwd
reboot
```

Pull the USB during POST. Metis should come up on the network with
hostname `metis` and accept SSH for `root` using the Mac key.

## Phase 5 — Harvest host key, re-encrypt sops on the VM

`[vm]` From the VM (which holds the existing decryption identity for
`secrets/secrets.yaml`), harvest Metis's freshly minted ed25519 host
pubkey and convert it to an age recipient:

```bash
ssh-keyscan -t ed25519 metis > /tmp/metis_hostkey
nix shell nixpkgs#ssh-to-age -c sh -c 'ssh-to-age < /tmp/metis_hostkey'
```

The output is a single age public key starting `age1…`.

`[vm]` Edit `.sops.yaml` — add `&metis` under `keys:` and include it in
the existing `creation_rules` `key_groups`:

Before:

```yaml
keys:
  - &nixos-vm age1wwg6k2xnt4kakkajl7y2eydxw3jf4ll7z8ql64v9hvjdm8svh5psjxxz3l

creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *nixos-vm
```

After:

```yaml
keys:
  - &nixos-vm age1wwg6k2xnt4kakkajl7y2eydxw3jf4ll7z8ql64v9hvjdm8svh5psjxxz3l
  - &metis    age1<harvested-recipient>

creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *nixos-vm
          - *metis
```

`[vm]` Re-encrypt for the new recipient set, commit, push:

```bash
nix shell nixpkgs#sops -c sops updatekeys secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "sops: add metis recipient"
git push
```

Verify the diff: `secrets/secrets.yaml` should gain new sops metadata for
metis with the nixos-vm metadata intact. The encrypted payload itself is
unchanged.

For the bus-factor caveat (this re-encryption depends on already-having
a decryption identity), see the equivalent section in
[headless-bootstrap-aws.md](./headless-bootstrap-aws.md#phase-2--update-sops-recipients-on-the-operators-machine)
and the TODO under "Bus-factor — sops decryption identity for the
operator".

## Phase 6 — First flake switch on Metis

`[metis]` SSH in as `root` (Mac key). Clone the flake into a temporary
location — `/home/dbf` doesn't exist yet because the declarative user is
created by the switch itself:

```bash
nix shell nixpkgs#git -c git clone \
  https://github.com/dannyfaris/nix-config.git /root/nix-config
cd /root/nix-config
```

`[metis]` **Pre-flight sops decryption before activating.** This is the
load-bearing check from the AWS runbook: if `/etc/ssh/ssh_host_ed25519_key`
has been regenerated between Phase 5 and now, `dbf-password` won't
decrypt and `dbf` will end up with an empty hashedPasswordFile.

```bash
nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml > /dev/null && \
  echo "sops decryption OK"
```

If this fails, stop. Recovery sequence — note the location changes back
and forth, so mind the `[vm]` / `[metis]` labels:

- `[vm]` re-harvest Metis's current host key (Phase 5 commands), then
  `sops updatekeys secrets/secrets.yaml`, commit, push.
- `[metis]` `git pull` in `/root/nix-config`, then re-run the
  decryption pre-flight above. Retry the switch only after it prints OK.

`[metis]` Switch into the flake:

```bash
nixos-rebuild switch --flake /root/nix-config#metis
```

The first switch will:

- Create `dbf` declaratively (per `modules/core/nixos/users.nix`).
- Apply `users.mutableUsers = false`, removing the temporary root SSH key.
- Decrypt `dbf-password` via sops using Metis's SSH host key as the age
  identity (the one whose pubkey you harvested in Phase 5).
- Set up SSH key-only inbound auth for `dbf` with the Mac SSH key.
- Bring up NetworkManager, Tailscale, and rootless Docker.

## Phase 7 — Move the clone to dbf, real hardware.nix, Tailscale

`[metis]` SSH back in as `dbf` (the Mac key now lets you in as the user,
not root). Move the clone into `dbf`'s home and fix ownership:

```bash
ssh dbf@metis
sudo mv /root/nix-config /home/dbf/
sudo chown -R dbf:users /home/dbf/nix-config
cd ~/nix-config
```

`[metis]` Replace the placeholder kernel-module blocks in
`hosts/metis/hardware.nix` with the real values from
`nixos-generate-config`. **Do NOT overwrite the whole file** — the
committed `hardware.nix` is hand-authored (btrfs subvolume layout,
`zramSwap.enable`, `boot.supportedFilesystems`, the `btrfsOpts`
let-binding) and the auto-generated version doesn't know any of that.
Wrong initrd modules can mean an unbootable next-generation, so this
step matters more on bare metal than on AWS.

Generate the reference config to a temp path and diff:

```bash
sudo nixos-generate-config --no-filesystems --show-hardware-config \
  > /tmp/generated-hardware.nix
diff -u hosts/metis/hardware.nix /tmp/generated-hardware.nix | less
```

Copy ONLY the following blocks from `/tmp/generated-hardware.nix` into
the committed `hosts/metis/hardware.nix`, replacing the placeholder
values in place:

- `boot.initrd.availableKernelModules` — the real list for this
  ProDesk's storage/USB stack (NVMe controller, USB hubs, etc.).
- `boot.initrd.kernelModules` and `boot.kernelModules` — confirm or
  replace; the placeholder has `kvm-intel` speculatively.
- `hardware.cpu.intel.updateMicrocode = lib.mkDefault true;` — add if
  not already present (the placeholder doesn't have it).

Leave everything else in `hosts/metis/hardware.nix` exactly as
committed — the rule is "replace only the kernel-modules placeholder
block(s) and add Intel microcode if missing; preserve everything else."
At time of writing, "everything else" is: the `let btrfsOpts = ... in`
block, the three `fileSystems` entries for `/`/`/home`/`/nix`,
`fileSystems."/boot"`, `boot.supportedFilesystems`, `zramSwap.enable`,
`swapDevices`, and `nixpkgs.hostPlatform`. If `hardware.nix` has been
extended in the meantime (e.g. firmware enablement, extra mounts),
those additions are also kept.

`[metis]` Join the tailnet. `services.tailscale.enable` brought the
daemon up but joining requires interactive auth. Two options:

- Pre-mint a one-shot auth key in the Tailscale admin console and:
  `sudo tailscale up --auth-key=tskey-…`
- Or run `sudo tailscale up` and open the printed URL in a browser on
  another device.

Confirm no existing tailnet node is already named `metis` before
joining; rename in the admin console first if there's a collision.

`[metis]` Activate, commit, push (ensure you're in the flake checkout —
intermediate steps above may have taken you elsewhere):

```bash
cd ~/nix-config
nh os switch
git add hosts/metis/hardware.nix
git commit -m "metis: real hardware.nix from nixos-generate-config"
git push
```

`nh` resolves the flake via `NH_FLAKE`, set from
`hostContext.flakePath = "/home/dbf/nix-config"` in
`hosts/metis/default.nix`.

## Phase 8 — Verification

Run these from the VM or your Mac.

- `ssh dbf@metis` succeeds key-only, no password prompt.
- `echo $SHELL` → `/run/current-system/sw/bin/fish`.
- `helix` opens a `.nix` file with nixd LSP working (hover over
  `programs.git` should show the option's type).
- Dual git identity (Metis imports `git-identity-dual.nix`):
  - `git config user.email` returns the personal address by default.
  - Inside `~/work/<repo>`, `git config user.email` returns the work address.
- All four agent CLIs resolve: `which claude cursor-agent codex gemini`.
  Metis imports `agent-clis-extras.nix`, unlike Mercury.
- `which gh` resolves — Metis imports `gh.nix`.
- `mosh dbf@metis` connects; a laptop-sleep cycle survives.
- Tailscale up: `tailscale status` lists metis and its peers.
- Btrfs check: `findmnt -t btrfs` lists exactly three mounts (`/`,
  `/home`, `/nix`), each with `subvol=<name>` and `compress=zstd:1` in
  the options column.
- zram check: `swapon --show` lists `/dev/zram0` (no disk swap entries);
  `zramctl` reports the device's compression algorithm and disksize.
- Periodic scrub timer: `systemctl list-timers btrfs-scrub-*` shows the
  monthly scrub timer armed.
- Rootless Docker (per ADR-021):
  - `systemctl --user status docker` → `active (running)`.
  - `groups` does NOT include `docker`.
  - `docker run --rm hello-world` succeeds as `dbf` with no sudo, no
    `DOCKER_HOST` override.
  - `docker compose version` and `docker-compose --version` both respond.
- Macchina login banner shows on SSH login (the
  `home/core/nixos/macchina.nix` module is a role default wired in
  `modules/core/nixos/home-manager.nix`).
- Power-loss recovery test (optional but worth it the first time, since
  it's the reason there's no LUKS): pull the power, wait 10s, plug back
  in. The box should boot unattended and Tailscale should rejoin within
  a minute or two.

## Break-glass

Until you've finished Phase 8 verification, keep the monitor and USB
keyboard physically attached to Metis. The console is your only recovery
if:

- The Mac SSH key in `users.nix` is wrong at the moment of the Phase 6
  switch.
- A bad `firewall.allowedTCPPorts` change locks SSH out.
- A bad hardware.nix change makes the next generation unbootable (boot
  the previous generation from systemd-boot's menu).

Equivalent to the UTM console window from `CLAUDE.md`'s break-glass
section — physical, out-of-band, always works.

## Security group / firewall

NixOS-side, the firewall is enabled by `modules/core/nixos/firewall.nix`,
which the `headless` role imports. `services.openssh.openFirewall = true`
opens TCP 22, `programs.mosh.enable = true` opens UDP 60000-61000, and
`services.tailscale.openFirewall = true` opens UDP 41641.

There is no cloud security group on a bare-metal box. The perimeter is
whatever's between Metis and the internet — typically a home router. If
Metis isn't reachable from the public internet (it shouldn't need to
be), Tailscale is the only inbound path that matters and the NixOS
firewall handles the rest.

## What this runbook does NOT cover

- BIOS recovery if a firmware flash bricks the board (HP's recovery USB
  procedure — see HP support docs).
- Disk failure / replacement (btrfs single-device; no RAID, no backup
  policy declared in this config yet).
- Moving Metis to a different physical location (tailnet survives; ISP
  / NAT may need attention; static IP if you rely on one).
- Decommissioning Metis later (remove `&metis` from `.sops.yaml`,
  `sops updatekeys`, remove host from `parts/nixos.nix` and the
  `hosts/metis/` directory).
