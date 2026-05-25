# Headless bootstrap

Operational procedure for bringing a `headless` role host from clean state
(running Ubuntu / live USB / fresh hardware) to a fully-managed `nh os
switch` target.

Single procedure for both AWS and bare metal — the install step is
identical (`nixos-anywhere` + `disko` with pre-injected SSH host keys);
only the preconditions differ.

See [ADR-022](../decisions/ADR-022-headless-bootstrap-nixos-anywhere.md)
for the bootstrap decision and [ADR-023](../decisions/ADR-023-host-config-three-file-structure.md)
for the per-host file layout this runbook assumes.

> The previous host-specific runbooks at
> [`headless-bootstrap-aws.md`](./headless-bootstrap-aws.md) and
> [`headless-bootstrap-metis.md`](./headless-bootstrap-metis.md) are
> superseded by this document. They remain in git history for reference.

## Operator prerequisites

Run once per fresh clone of this repo on the operator machine:

- `nix` with flakes enabled. `just` available — not yet a home-manager
  package, so use ad-hoc invocation: `nix shell nixpkgs#just -c just
  <recipe>` or `nix run nixpkgs#just -- <recipe>`.
- This repo cloned, with `just install-hooks` run once (use the ad-hoc
  invocation above for this first call too). `core.hooksPath` isn't
  versioned, so every fresh clone needs this. The hook enforces ADR-023's
  "don't hand-edit `hardware-configuration.nix`" rule.
- An existing age decryption identity for `secrets/secrets.yaml`. Today
  the UTM VM's host SSH key (`/etc/ssh/ssh_host_ed25519_key`) is the
  only such identity; `sops updatekeys` (step 2 below) must therefore
  run on the VM. Before first use, derive the operator-side age key
  from the SSH host key:

  ```bash
  just setup-sops-identity
  ```

  One-time-per-fresh-clone; idempotent. Creates
  `~/.config/sops/age/keys.txt` so subsequent `sops -d` /
  `sops updatekeys` work as `dbf` without env-var ceremony. Without
  this, the bootstrap pre-flight will refuse to proceed.
- An `~/.ssh/config.local` entry for the host being bootstrapped, so
  the operator can `ssh <host>` without typing the full target string.
  `home/core/nixos/ssh.nix` includes this file at file scope; entries
  there survive `nh os switch` (unlike `~/.ssh/config`, which
  home-manager owns). Example for an AWS host:

  ```
  Host mercury
    User ubuntu
    HostName ec2-x-x-x-x.<region>.compute.amazonaws.com
    IdentityFile ~/.ssh/mercury.pem
  ```

  The matchBlock is needed only during bootstrap (the `ubuntu` /
  `nixos` account is gone post-install and `root` SSH is disabled;
  you'll SSH as `dbf` from your Mac afterwards). You can leave the
  entry in place or remove it post-bootstrap — either is fine.
- Daniel's Mac SSH key in `modules/core/nixos/users.nix` matches the
  private key on the laptop you'll SSH from. Once `nixos-anywhere`
  completes, that key is the sole inbound credential — get it right
  before, not after.

## Per-host preconditions

### AWS host (Mercury, future AWS instances)

- A running Linux instance (Ubuntu, Debian, Amazon Linux — any modern
  kernel that supports kexec). Ubuntu 26.04 LTS or similar tested.
- SSH reachable as a sudo-capable user (typically `ubuntu` on Ubuntu
  AMIs; `admin` on Debian; `ec2-user` on Amazon Linux). The user must
  have passwordless sudo.
- Security group: TCP 22 open to the operator's public IP. Restrict;
  don't use `0.0.0.0/0`.
- Instance type with at least **1.5 GiB free RAM during install** —
  `nixos-anywhere` kexecs into a NixOS installer that runs from
  memory. t3.micro (1 GiB) is borderline; t3.small (2 GiB) is fine;
  t3.medium (4 GiB) is comfortable.
- EBS root volume ≥20 GiB (30 GiB comfortable for a dev box). Resize
  *before* conversion — non-destructive bump in the AWS console.
- `hosts/<host>/disko.nix` references the correct `/dev` path. On
  Nitro hypervisor (t3.\*, m5.\*, c5.\* and later) this is
  `/dev/nvme0n1`. Pre-Nitro instances (t2.\*, m4.\*, c4.\*) use
  `/dev/xvda` — verify with `lsblk` from the target host and update
  `disko.nix` if needed.
- *Optional but recommended:* snapshot the EBS volume **before**
  invoking `just bootstrap`. `nixos-anywhere` is destructive (wipes
  the disk); a pre-install snapshot gives you a true rollback option
  via terminate + relaunch if Instance Connect and Serial Console
  both fail. See Break-glass below.

### Bare-metal host (Metis, future bare-metal hosts)

> **Metis specifically requires physical access.** Its config is
> committed but the install is pending hardware availability. Do not
> attempt to bootstrap Metis remotely.

- Latest NixOS 25.11 minimal ISO flashed to a ≥4 GiB USB stick.
  (Wi-Fi-only targets may need the unfree-firmware ISO build.)
- Target booted from USB to a `nixos@nixos` shell. Enable sshd
  (`sudo systemctl start sshd`), set a temporary `nixos` password
  (`sudo passwd nixos`), and add the operator's Mac SSH key to
  `/home/nixos/.ssh/authorized_keys` (or `/root/.ssh/authorized_keys`
  if connecting as root). The live USB's `nixos` user has passwordless
  sudo by default, so `nixos-anywhere` can elevate as needed during
  step 3.
- Network reachable from operator. Wired ethernet picks up DHCP
  automatically; Wi-Fi needs `sudo systemctl start wpa_supplicant`
  then `wpa_cli` (or `nmtui` if present).
- BIOS prepared: Secure Boot off, UEFI on (Legacy/CSM off), "After
  Power Loss: On" (or "Previous State") for unattended reboot,
  Wake-on-LAN optional. Update BIOS firmware while you're here — much
  easier from the pre-OS HP updater than from Linux later.
- `hosts/<host>/disko.nix` device path verified with `lsblk` from the
  live USB. The HP ProDesk Mini 600 G9 ships in multiple storage
  variants — `/dev/nvme0n1` is most common but not universal.
- A monitor and USB keyboard physically attached to the target until
  verification completes — your only console if anything goes wrong.

## Install (shared procedure)

Run from the operator machine, inside this repo. Steps 1, 2, and 4
require operator action; step 3 is the `nixos-anywhere` invocation.

### Step 1 — Generate the host SSH key

```bash
just gen-host-key <host>
```

This:
- Stages an ed25519 host key in `/dev/shm/nix-bootstrap-<host>/etc/ssh/`
  (in-memory tmpfs on Linux; disk-backed but unlinked on cleanup on
  macOS).
- Prints the age recipient (e.g. `age1abc…`) for adding to
  `.sops.yaml`.
- Prints the YAML snippet to merge into `.sops.yaml`.

The recipe is idempotent against stale runs — if `/dev/shm/nix-bootstrap-<host>`
already exists, it errors and tells you to run `just bootstrap-clean`.

### Step 2 — Add the host as a sops recipient

Manual; intentionally out-of-band because automated YAML editing is
fragile.

1. Edit `.sops.yaml`. Add the new anchor under `keys:` (preserving
   existing anchors) and reference it in the relevant `key_groups`.
   Example end state after adding `mercury`:

   ```yaml
   keys:
     - &nixos-vm  age1wwg6k2xnt4kakkajl7y2eydxw3jf4ll7z8ql64v9hvjdm8svh5psjxxz3l
     - &mercury   age1<recipient-from-step-1>

   creation_rules:
     - path_regex: secrets/.*\.yaml$
       key_groups:
         - age:
             - *nixos-vm
             - *mercury
   ```

2. Re-encrypt `secrets/secrets.yaml` for the expanded recipient set:

   ```bash
   nix shell nixpkgs#sops -c sops updatekeys secrets/secrets.yaml
   ```

3. Commit and push:

   ```bash
   git add .sops.yaml secrets/secrets.yaml
   git commit -m "sops: add <host> recipient"
   git push
   ```

### Step 3 — Run the install

```bash
just bootstrap <host> <user>@<target>
```

Substitute `<user>`:
- AWS: the AMI's default sudo-capable user (e.g. `ubuntu`).
- Bare metal: `nixos` (live USB default) or `root`.

The recipe:
1. Pre-flight 1: confirms the new host's age recipient is in
   `secrets/secrets.yaml` (catches forgotten step 2 directly).
2. Pre-flight 2: confirms operator-side sops decryption works (failure
   here means `just setup-sops-identity` wasn't run — see Operator
   prerequisites).
3. Invokes `nixos-anywhere` (pinned to 1.13.0) with:
   - `--extra-files` pointing at the staged host key
   - `--generate-hardware-config` writing the real hardware config back
     to `hosts/<host>/hardware-configuration.nix`
   - `--kexec-extra-flags --kexec-syscall` to force the legacy
     `kexec_load` syscall. Necessary on Ubuntu's `-aws` kernels (which
     ship with `CONFIG_KEXEC_BZIMAGE_VERIFY_SIG=y` and reject NixOS's
     unsigned bzImage via `kexec_file_load` with `EADDRNOTAVAIL` even
     when Secure Boot is disabled and lockdown is none). Harmless on
     every other kernel — kexec-tools' option parser is last-wins, so
     this overrides nixos-anywhere's default `--kexec-syscall-auto`.
4. Cleans up `/dev/shm/nix-bootstrap-<host>` on success.

On failure mid-install, the staged key is preserved so you can retry
`just bootstrap` without regenerating (which would invalidate the
recipient already committed to `.sops.yaml`). `just bootstrap-clean`
removes all staged keys if you're abandoning the bootstrap.

### Step 4 — Review and commit `hardware-configuration.nix`

`nixos-anywhere --generate-hardware-config` overwrites
`hosts/<host>/hardware-configuration.nix` with the real hardware
probe output (the stub is gone). Review and commit:

```bash
git diff hosts/<host>/hardware-configuration.nix
git add hosts/<host>/hardware-configuration.nix
git commit -m "<host>: real hardware-configuration.nix from nixos-anywhere"
git push
```

The pre-commit hook (`just install-hooks`) accepts the new banner
from `nixos-generate-config`. Do not hand-edit this file — re-run
`just bootstrap` to regenerate.

## Post-install

SSH in as `dbf` (your Mac key is now the sole inbound credential
— the original `ubuntu` / `root` / `nixos` user is gone, replaced
declaratively by `modules/core/nixos/users.nix`):

```bash
ssh dbf@<host>
cd ~/nix-config   # clone fresh if not already present:
                  #   git clone https://github.com/dannyfaris/nix-config.git ~/nix-config
nh os switch
```

`nh` resolves the flake via `NH_FLAKE`, set from `hostContext.flakePath`
in each host's `default.nix` (ADR-019).

## Verification

Run from the new host's `dbf` shell unless noted otherwise.

### Shared (all headless hosts)

- `ssh dbf@<host>` succeeds key-only, no password prompt.
- `echo $SHELL` → `/run/current-system/sw/bin/fish`.
- `helix` opens a `.nix` file with `nixd` LSP working — hover over
  `programs.git` shows the option's type. `:lsp-restart` if uncertain.
- `mosh dbf@<host>` connects; a laptop-sleep cycle survives the
  reconnect.
- `which claude` and `which cursor-agent` both resolve — the base
  agent set is on every host (ADR-008).
- Rootless Docker (ADR-021):
  - `systemctl --user status docker` → `active (running)`.
  - `groups` does NOT include `docker` (rootless doesn't need it).
  - `docker run --rm hello-world` succeeds as `dbf` with no sudo and
    no `DOCKER_HOST` override.
  - `docker compose version` and `docker-compose --version` both
    respond.

### Per-host divergences

**Mercury (work-only):**
- `git config user.email` → `daniel.faris@gotaxi.co.nz` (single work
  identity per `git-identity-work.nix`).
- `~/work/` exists; `~/personal/` does not (ADR-020).
- `which gh` → nothing (Mercury doesn't import `gh.nix`).
- `which codex` and `which gemini` → nothing (no `agent-clis-extras`).
- `glab auth login` interactively works; token persists to
  `~/.config/glab-cli/`.
- `boot.growPartition` filled the EBS volume:
  `df -h /` shows ~the full EBS size.

**Metis (personal dev box):**
- Dual git identity:
  - `git config user.email` returns the personal address by default.
  - Inside `~/work/<repo>`, `git config user.email` returns the work
    address (via `git-identity-dual.nix`'s `gitdir` rules).
- All four agent CLIs resolve:
  `which claude cursor-agent codex gemini`.
- `which gh` resolves (Metis imports `gh.nix`).
- Tailscale up: `tailscale status` lists `metis` and its peers.
- btrfs layout: `findmnt -t btrfs` shows exactly three mounts (`/`,
  `/home`, `/nix`), each with `subvol=@<name>` and `compress=zstd:1`
  in the options column.
- zram: `swapon --show` lists `/dev/zram0` (no disk swap entries);
  `zramctl` reports the device's algorithm and disksize.
- Periodic scrub: `systemctl list-timers btrfs-scrub-*` shows the
  monthly timer armed.
- Macchina login banner shows the Tailscale interface (per the
  interface-detection logic in `home/core/nixos/macchina.nix`,
  shipped to all hosts by `modules/core/nixos/home-manager.nix`).
- Power-loss recovery test (do this once — it's the reason there's
  no LUKS): pull the power, wait 10 s, plug back in. The box should
  boot unattended and Tailscale should rejoin within a minute or two.

## Break-glass

### AWS

If you lose SSH access:

1. **EC2 Instance Connect** — web console "Connect" tab in AWS, or
   `aws ec2-instance-connect send-ssh-public-key` CLI. Pushes a
   temporary SSH key via the Instance Connect agent on the instance.
   Requires the SG to allow TCP 22 from AWS's Instance Connect
   prefix list and the operator IAM user to have the relevant
   permissions — pin those *before* you need them, not at 2 AM.
2. **EC2 Serial Console** — must be enabled at the account level
   one-time. Direct serial access via the AWS console regardless of
   network state.
3. **Terminate + relaunch from a pre-install EBS snapshot** if both
   Instance Connect and Serial Console fail. Requires having
   snapshotted the EBS volume *before* `just bootstrap` (see Per-host
   preconditions above for the recommendation).

### Bare metal

1. **Physical console** (monitor + USB keyboard) — equivalent to the
   UTM VM's console window. Always works; pre-attach during install.
2. **systemd-boot previous-generation entry** — if a bad
   `hardware-configuration.nix` or other change makes the next
   generation unbootable, pick the previous generation from
   systemd-boot's menu at startup.
3. **Boot from the live USB again** if needed for offline repair
   (mount the btrfs root, chroot, fix, reboot).

## Troubleshooting

### Build OOMs on `sops-install-secrets` (memory-constrained targets)

On small instances (t3.medium with 4 GiB RAM and no default swap, or
similar), the Go compiler can be OOM-killed while building
`sops-install-secrets`'s `aws-sdk-go-v2/service/s3` dependency. Visible
signal: `signal: killed` in the last log lines of the failed build.

The kexec installer is still alive after the failure and the disk is
already partitioned via disko — recover without restarting the whole
bootstrap:

1. From the operator, add disk-backed swap on the disko-mounted future
   root (the installer's own `/` is tmpfs, so it can't host swap):

   ```bash
   ssh root@<host> 'fallocate -l 4G /mnt/_temp_swap && \
     chmod 600 /mnt/_temp_swap && \
     mkswap /mnt/_temp_swap && \
     swapon /mnt/_temp_swap'
   ```

2. Re-run nixos-anywhere with `--phases install,reboot` (skip the
   already-completed kexec + disko phases). Note the target-host
   becomes `root@<host>` for the installer:

   ```bash
   nix run github:nix-community/nixos-anywhere/1.13.0 -- \
       --flake .#<host> \
       --target-host root@<host> \
       --extra-files /dev/shm/nix-bootstrap-<host> \
       --phases install,reboot \
       --kexec-extra-flags --kexec-syscall \
       --generate-hardware-config nixos-generate-config \
                                  hosts/<host>/hardware-configuration.nix
   ```

3. After the new system boots and you've SSHed in as `dbf`, the
   swapfile persists as an orphan at `/_temp_swap` (4 GiB unused on
   disk). Clean up:

   ```bash
   sudo swapoff /_temp_swap   # may print "Invalid argument" if not
                              # active in the new system — harmless
   sudo rm /_temp_swap
   ```

Larger instances (t3.large 8 GiB+, m5.large+) won't need this — the
AWS SDK Go build fits in RAM. The justfile's `bootstrap` recipe doesn't
add swap by default because most targets won't need it; this section
is the documented workaround for when they do.

## What this runbook does NOT cover

- BIOS recovery on bare metal if a firmware flash bricks the board
  (HP's recovery USB procedure — see HP support docs).
- Disk failure / replacement (single-device btrfs on Metis; no RAID,
  no backup policy declared in this config yet).
- Decommissioning a host: remove its anchor from `.sops.yaml`, run
  `sops updatekeys secrets/secrets.yaml`, remove its entry from
  `parts/nixos.nix` and its directory under `hosts/`.
- Moving a bare-metal host to a different physical location (Tailscale
  survives; ISP / NAT may need attention; static IP if you rely on
  one).
