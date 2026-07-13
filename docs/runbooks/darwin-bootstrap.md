# Darwin bootstrap

Operational procedure for bringing a macOS host from clean state to a
fully-managed `nh darwin switch` target.

See [ADR-027](../decisions/ADR-027-foundation-and-bundles.md) for the
foundation + bundles composition model the Darwin tree mirrors and the
[`#11` epic](https://github.com/dannyfaris/nix-config/issues/11) for
the broader mac-mini onboarding context.

> The initial forecast version of this runbook (PR #164) was retired
> after the live mac-mini bootstrap on 2026-06-02 surfaced the real
> sequence. This document is the operational pass.

## Operator prerequisites

Run once per fresh clone of this repo on the operator machine:

- `nix` with flakes enabled. Repo cloned. devShell entered once
  (`nix develop`, or direnv-reload via the repo's `.envrc`). The
  devShell's `shellHook` installs the pre-commit hooks (ADR-025) and
  exports `SOPS_AGE_KEY_FILE` so `sops --decrypt` works in-repo
  without env-var ceremony.
- Vault access (1Password) from the new Mac or a neighbouring signed-in device. Nothing key-shaped is carried between machines: the Mac's sops identity is populated from the vault in pre-bootstrap step 1, and its fleet SSH key is minted on-box at §Fleet SSH enrolment and lands via a normal PR (docs/design/fleet-key-custody.md).

## Pre-bootstrap (operator-side, on the Mac)

The Mac Mini and MacBook Air both follow the same sequence. Steps
must run in order — each depends on the previous.

### 0 — macOS Setup Assistant

Walk through Setup Assistant. The only setting that matters downstream
is **Account Name** (the Unix short name shown under "Username" /
"Account Name" — Setup Assistant auto-derives one from the Full Name).
It **must** be `dbf` exactly. `lib/operator.nix`'s `name` field is the single source of truth; `users.users.dbf`, `home-manager.users.dbf`, `/Users/dbf`, and the sops `age.keyFile` path (`~/.config/sops/age/keys.txt` under `darwinHome`) all key off this string.

The Full Name (the display name) can be anything.

Take Setup Assistant's other offers where they appear: **Touch ID fingerprint enrolment** (without it the declared `pam_tid` sudo silently falls back to password — docs/darwin/touch-id.md §Prerequisite) and **FileVault** (turning the §FileVault step below into verify-only; saturn's declared Phase-1 build has FileVault on from bring-up — `hosts/saturn/default.nix`, leaned on by the key-custody chain, ADR-043).

### 1 — Install the operator age identity from the vault

The Mac edits fleet secrets with the standalone operator age key — the fleet's edit + disaster-recovery root (docs/design/fleet-key-custody.md). It is held in 1Password (item "sops age key - operator", with a second offline copy) and has no SSH ancestry: nothing is carried over from another machine, and no key is derived from any SSH keypair.

1Password itself isn't installed yet at this point (its cask arrives at first activation) — use 1Password's web vault in Safari, or copy from another signed-in device via Universal Clipboard.

Populate `~/.config/sops/age/keys.txt`. Type the command first and press Enter only after the copy — the 1Password item's full contents must be the *last* thing copied (any copy in between, including re-copying the command itself, silently clobbers the clipboard and writes junk):

```bash
umask 077
mkdir -p ~/.config/sops/age
pbpaste > ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt && pbcopy < /dev/null
```

Verification is step 4 — it needs `nix` (installed in step 2) for `age-keygen`.

### 2 — Install Nix

The canonical path is the **NixOS official installer**:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Restart your terminal to pick up the new PATH.

> The Determinate Systems installer was the prior recommendation per
> PRD §11.2 ("upstream Nix variant, not Determinate Nix"). The
> `--determinate=false` flag was removed upstream and its replacement
> `--prefer-upstream-nix` is past its documented availability cutoff;
> on the live mac-mini bootstrap the Determinate installer aborted
> with a marketing nudge. The NixOS official installer produces
> upstream Nix unambiguously and is now the canonical entry point.

Enable flake features (the NixOS installer doesn't set them by default):

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Without this step, every subsequent `nix shell` / `nix flake`
invocation fails with `experimental Nix feature 'nix-command' is
disabled`. This is per-user config; nix-darwin's foundation enables
the same flags at system level after first activation, at which point
the per-user file becomes redundant-but-harmless.

### 3 — Clone the repo

macOS ships without `git`. First `git` invocation triggers Xcode
Command Line Tools install — a GUI prompt and 5–10 minutes of download:

```bash
git clone https://github.com/dannyfaris/nix-config.git ~/nix-config
cd ~/nix-config
```

The CLT prompt *aborts* the triggering command (`xcrun: error: invalid active developer path`) — re-run the clone once the install completes.

The expected path is `/Users/dbf/nix-config` — this matches
`hostContext.flakePath`'s Darwin default in
`modules/darwin/host-context.nix` (`${operator.darwinHome}/${operator.flakeRepoDirname}`).

If you want to skip the CLT install, the `nix shell` alternative
works (CLT is otherwise nix-darwin-unmanaged Apple state per PRD §2.2,
but provides useful `cc`/`clang`/headers as a side-effect — keeping
it isn't a problem):

```bash
nix shell nixpkgs#git -c git clone https://github.com/dannyfaris/nix-config.git ~/nix-config
```

### 4 — Verify the operator age identity

```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

Output must match the `operator` recipient in `.sops.yaml` (currently `age12dv25pjp7xccjagz2mmpg0pcwutee8eut34tuaqzaqn9wvqmvysqumvgx8`). If it doesn't, **stop** — the pasted vault item wasn't the operator key, or the clipboard was clobbered mid-procedure; re-do step 1.

With the repo cloned (step 3), run the functional check — the new Mac's first decrypt. The `SOPS_AGE_KEY_FILE` prefix is required at this point: on macOS, sops does not search `~/.config/sops/age/keys.txt` unless `XDG_CONFIG_HOME` is set (it looks in `~/Library/Application Support` instead), and the devShell that exports the variable only arrives with first activation.

```bash
cd ~/nix-config
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml >/dev/null && echo OK
```

### 5 — Collect the operator UID for the host file

This step runs *after* macOS Setup Assistant has created the `dbf`
user account — without that, `id -u dbf` returns nothing.

```bash
id -u dbf
```

macOS's first-user default is 501. Pin this value in `hosts/<host>/default.nix` as `users.users.dbf.uid = <value>;` — only the UID is host-specific; `users.knownUsers` is already declared foundation-wide via `modules/darwin/users.nix`, so don't restate it. The UID must match what macOS assigned during first-boot setup; nix-darwin refuses to manage a user with a mismatched UID.

### 6 — Move aside `/etc/{bashrc,zshrc}` (NixOS-installer safety guard)

The NixOS official installer modifies `/etc/bashrc` and `/etc/zshrc`
to source `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.
nix-darwin refuses to overwrite these files on first activation as a
safety check. Move them aside so nix-darwin can write its own:

```bash
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc  /etc/zshrc.before-nix-darwin
```

(The Determinate installer doesn't touch these files, which is why
the old runbook didn't list this step.)

### 7 — One-time interactive App Store sign-in (if the host declares `masApps`)

`homebrew.masApps` apps are installed via `mas-cli` at activation, and
`mas install` can only fetch apps already associated with the
signed-in Apple ID — `mas signin` was removed from mas-cli in late
2025 (PR #1167) after Apple's account-flow changes broke the
headless path.

Before the first activation that adds a `masApps` entry — whether
that's a fresh-Mac `nix run nix-darwin -- switch` or a later
`nh darwin switch` on an already-bootstrapped host — open the
App Store app and sign in with the Apple ID that owns the apps
in question. One-time per machine.

If you skip this step, activation surfaces an authentication error
from `mas install`; the fix is to sign in and re-activate.

**Loosen Media & Purchases password requirements for the first
activation.** Even with the App Store signed in, macOS by default
prompts for the Apple ID password on *every* `mas install`
invocation — that's at minimum one prompt per declared masApps
entry, and re-prompts on any per-app retry. The first activation
on a fresh Mac with the full app set easily surfaces a dozen
prompts. Before kicking off the activation, navigate to
**System Settings → Apple ID → Media & Purchases → Password
Settings** and set:

- **Free Downloads:** `Don't Require` — all of `homebrew.masApps`
  today (Slack, the Microsoft 365 suite, Amphetamine) are free
  downloads from MAS's perspective (Microsoft 365 features are
  subscription-locked at runtime, not at download), so this
  toggle eliminates the prompt for every one of them.
- **Purchases and In-App Purchases:** `Never Require` (or the
  loosest option available — exact label varies by macOS version;
  some versions only offer `Require After 15 Minutes` as the
  loosest non-`Always Require` choice, which is also acceptable).
  This covers the edge case where a future paid `masApps` entry
  is added and prevents the activation from stalling on its
  prompt.

Operator's experience on the 2026-06-03 mac-mini bring-up: even
with the App Store signed in and `mas` declaratively installed,
the activation will surface the FIRST `mas install`'s password
prompt as a foregrounded macOS dialog the operator must
type-in-and-dismiss. **Plan to sit with the App Store window
open during the start of the first activation** — once the
first prompt is dismissed, the loosened Media & Purchases
settings carry the rest of the run.

After the first activation completes cleanly, tighten the
settings back to whatever the operator prefers as a steady-state
posture. This carve-out exists for first-bootstrap-only; future
incremental masApps additions trigger at most one prompt each.

**The `mas` CLI itself is installed declaratively** via
`homebrew.brews = [ "mas" ];` in `modules/darwin/homebrew.nix`.
nix-darwin's `homebrew.masApps` option doesn't add the `mas`
formula to the brews list automatically — and although `brew
bundle` has a lazy fallback that tries to install `mas`
on-demand when it first hits a `mas "..."` entry, that path is
fragile (it raises if the on-demand install fails for any
reason, and surfaces diagnostics inconsistently when the failure
is actually downstream in mas-cli's auth-state logic).
Declaring `mas` in the brews list makes the dependency a
deterministic explicit step; brew bundle processes the Brewfile
in strict file-line order with `--jobs=1`, so `brew "mas"`
installs ahead of every `mas` entry on a single first
activation. The 2026-06-03 mac-mini activation surfaced this
empirically: every cask installed cleanly, but the MAS section
produced zero installs — root cause was the lazy-fallback path
interacting with the App Store sign-in requirement (the
prerequisite this very step covers).

(Currently relevant only on hosts whose modules declare
`homebrew.masApps` — see `modules/darwin/homebrew.nix`.)

### 8 — Expect TCC prompts on first activation

When nix-darwin writes to `/Library/LaunchDaemons/`, macOS may
prompt for Full Disk Access for the activation process. Approve via
System Settings → Privacy & Security as the prompts surface. None of
the steps below auto-dismiss the prompt; first activation pauses
until you confirm. (On the 2026-06-02 mac-mini bootstrap no TCC
prompt surfaced; treat this as "may appear, may not".)

## First activation

> A new host's darwinConfiguration is its own PR — the host file at `hosts/<host>/default.nix` plus the mkDarwinHost invocation in `parts/darwin.nix`. If `nix flake show .#darwinConfigurations` returns an empty attrset for your host, the host PR hasn't landed yet — `git pull` the merge before continuing.

The first activation needs `sudo` because `nix run nix-darwin -- switch`
doesn't escalate on its own:

```bash
cd ~/nix-config
sudo nix run nix-darwin -- switch --flake .#<host>
```

(If the run errors part-way through with a `/etc/bashrc` /
`/etc/zshrc` safety message, you skipped step 6 — fix it and re-run.)

After this, `darwin-rebuild` is on PATH. Subsequent activations use
either:

```bash
sudo darwin-rebuild switch --flake .#<host>
# or
nh darwin switch   # self-elevates
```

`nh darwin switch` is the canonical command going forward (parallel
to `nh os switch` on NixOS); `NH_FLAKE` is set from
`hostContext.flakePath` per ADR-019.

## Post-activation — first-run grants, sign-ins, and staged installers (manual, per-tool)

The app set carries non-declarable first-run ceremony beyond AeroSpace's own section below. Walk these once per Mac; each per-tool doc has the detail:

- **Karabiner-Elements — without this, every Hyper bind is dead.** Three prompts (docs/desktop/karabiner.md §Sharp edges): the pkg installer's admin password; **DriverKit driver-extension approval** — System Settings → General → Login Items & Extensions → Driver Extensions → enable `Karabiner-DriverKit-VirtualHIDDevice`; and **Input Monitoring** for `karabiner_grabber`, `karabiner_observer`, and the Karabiner-Elements UI. Until the driver extension is approved, Karabiner runs but no remaps fire — Caps→Hyper never happens and every AeroSpace chord is silently inert, the same "running but does nothing" failure mode as the AeroSpace Accessibility grant.
- **Tailscale — sign the Mac into the tailnet and approve its NetworkExtension** on first launch (docs/desktop/tailscale.md). Fleet SSH and Verification Phase 2's MagicDNS names depend on this.
- **Installer-manual casks are staged, never run** (Homebrew records the receipt regardless — docs/desktop/logi-tune.md §Sharp edges). Today that's Logi Tune: `open "$(ls -d /opt/homebrew/Caskroom/logitune/*/LogiTuneInstaller.app | tail -1)"`, click through, expect the one-time Camera TCC prompt on first app launch.
- **colima — one-time first start with explicit resources** (`colima start --cpu 4 --memory 4 --disk 100`; flag-less defaults are usually too tight, and the flags persist in the profile — docs/desktop/colima.md). Verify: `colima status` and `docker run --rm hello-world`.
- **AltTab** (Accessibility + Screen Recording) and **Wispr Flow** (Accessibility + Microphone) prompt on first launch — approve per their docs.
- **Touch ID:** confirm a fingerprint is enrolled (System Settings → Touch ID & Password) if Setup Assistant didn't do it (§0) — without enrolment the declared `pam_tid` sudo silently falls back to password (docs/darwin/touch-id.md).

## Post-activation — author `~/.ssh/config.local`

`home/shared/ssh.nix` declares `programs.ssh.includes = [
"~/.ssh/config.local" ]`. The Include target is operator-maintained
and survives every activation. Author it with a self-describing
header so a future operator opening it understands the nix-managed
vs operator-maintained boundary:

```sshconfig
# ~/.ssh/config.local — operator-maintained, NOT managed by nix-config.
#
# The parent ~/.ssh/config is a home-manager-generated symlink into the
# nix store (source: home/shared/ssh.nix), and contains only
# `Include ~/.ssh/config.local`. THIS file is where one-off Host blocks
# live so they survive `nh darwin switch` without being clobbered.
# See docs/decisions/ADR-010-ssh.md.
#
# Fleet hosts (mercury, metis, neptune) are declared in git since #517
# — do NOT re-add them here: this file renders BEFORE the declared
# blocks and would silently shadow them. Break-glass fallbacks only.

Host metis-lan
  HostName <metis's LAN IP>
  User dbf
```

(neptune's own `config.local` also carries a `mercury-aws` EC2 entry — neptune-era break-glass for a retiring host; new hosts don't add it.)

Fleet hosts need **no entry here** — `home/shared/ssh.nix` declares
them by bare MagicDNS name (#517), resolvable once the Mac is signed
into Tailscale (the `tailscale-app` cask is installed via
`modules/darwin/homebrew.nix` per ADR-031, but the operator still has
to sign the Mac into the tailnet on first launch; use the break-glass
entries above until then). This file carries only the non-tailnet
fallbacks.

## Post-activation — fleet SSH enrolment (#517 / #524 / ADR-042)

Same steps as the headless runbook (see [headless-bootstrap.md](./headless-bootstrap.md) §Fleet SSH enrolment): generate this host's passphrase-less outbound user key (`ssh-keygen -t ed25519 -N "" -C dbf@<host> -f ~/.ssh/id_ed25519 -q`), add its pubkey to `lib/operator.nix` `hostKeys`, add/extend the relevant `sshEdges` entries (ADR-042's declared-edge model), and commit this host's `/etc/ssh/ssh_host_ed25519_key.pub` to `hosts/<host>/` with its `ssh-known-hosts.nix` and `ssh.nix` entries. Existing hosts pick all of it up at their own next switch.

Client-only hosts (saturn today) run the first three steps only — mint the key, add it to `hostKeys`, and add this host to the source lists of the destinations it should reach (metis, neptune). Committing a host public key + `ssh-known-hosts`/`ssh.nix` entries is the *destination flip's* work — saturn's pending flip has its own subsection in that runbook. The enrolment lands via a normal PR: run `gh auth login` first (git is HTTPS+token per ADR-009 — nothing earlier in this runbook sets up push auth).

## Post-activation — enable FileVault (manual, not declarable)

`modules/darwin/system-prefs.nix` declares the screen-lock posture (`screensaver.askForPassword` + `askForPasswordDelay = 0`), but that only defends against shoulder-surfing a woken screen. At-rest disk encryption is orthogonal and **cannot be declared** — nix-darwin has no FileVault toggle; it is enabled out-of-band and the recovery key is generated once at enable time. A host with screen-lock-on but FileVault-off is still exposed to physical theft: on Apple Silicon the internal volume is always hardware-encrypted, but **without FileVault the Secure Enclave releases the volume key with no password gate**, so anyone with physical access reads the data by booting into macOS Recovery or Share Disk mode. That matters on every Darwin host, and the threat differs by role: neptune is the SSH bastion holding shared fleet state, while saturn is a laptop that physically travels — theft or loss is its dominant threat. The step below applies to both.

Enable it once, after first activation — or take Setup Assistant's offer at §0 and make this step verify-only. On saturn this is required from bring-up — the declared Phase-1 build (`hosts/saturn/default.nix`; ADR-043's theft-at-rest bound leans on it) — not optional:

```bash
# Prompts for the unlocking user's password, then prints the recovery key to
# stdout — store the key in the operator password manager (1Password), NOT in
# this repo.
sudo fdesetup enable

# Confirm status (expect "FileVault is On."):
fdesetup status
```

Notes:

- On Apple Silicon, FileVault keys to the Secure Enclave, so encryption is effectively instant (no multi-hour conversion pass) and the operator login already unlocks the disk at boot.
- On an always-on host that imports `modules/darwin/power.nix` (neptune): `restartAfterPowerFailure = true` still auto-reboots after an outage, but with FileVault on the host stops at the boot-time unlock screen (shown before macOS finishes booting) and waits for an operator to authenticate — it will not reach a logged-in, SSH-serving state unattended. `sudo fdesetup authrestart` caches the unlock key for a single *planned* restart, but does nothing for an unexpected power-failure reboot; accept the manual unlock as the cost of at-rest security on an always-on host. This interaction does not arise on a laptop such as saturn, which omits `power.nix` (no unattended-reboot expectation).

## Post-activation — enable Screen Sharing (manual, not declarable)

Inbound Screen Sharing (reach this host's desktop from another Mac over the tailnet, e.g. `vnc://neptune`) **cannot be declared.** nix-darwin has no option for it, and while the underlying `com.apple.screensharing` LaunchDaemon *is* loadable from the command line (`launchctl enable system/com.apple.screensharing`), that only brings the daemon up to listen on 5900 — it does **not** authorize the service. Apple changed Screen Sharing / Remote Management handling in macOS Monterey 12.1 and the "permitted" state is now TCC-gated: it can only be written through the System Settings UI, not by `sudo`, `launchctl`, `defaults`, or `kickstart`. A daemon-only enable connects, then fails with *"Screen Sharing is not permitted on this Mac. Disable and re-enable Screen Sharing or Remote Management in System Settings."* This was verified on neptune (macOS 26 Tahoe); a `launchctl`-driven activation module was prototyped and dropped for exactly this reason.

**Per-host: enable on neptune** (the always-on mini serving inbound desktop access); **skip on saturn** — a roaming laptop's declared posture is outbound-only (`hosts/saturn/default.nix` — no inbound surfaces), and once enabled, inbound VNC:5900 passes the ALF unconditionally (Apple-signed daemon).

Where wanted, enable it once, after first activation:

- **System Settings → General → Sharing → Screen Sharing → on.**

Notes:

- No access-control step is needed for the operator. The `com.apple.access_screensharing` group nests the `admin` group, and `dbf` is an admin, so the login password authenticates the VNC session. A non-admin account *would* need adding (`dseditgroup -o edit -a <user> -t user com.apple.access_screensharing`).
- No firewall change is needed. The host ALF (`modules/darwin/firewall.nix`) runs with `allowSigned = true`, and the screen-sharing daemon is Apple-signed, so inbound VNC (5900) passes without a rule.
- **Hyper hotkeys don't fire over Screen Sharing — use the literal `Ctrl+Opt` chord.** Karabiner remaps the *physical* keyboard (DriverKit virtual-HID); Screen Sharing *injects* CGEvents that bypass Karabiner's grab, so `Caps Lock → Hyper` never happens remotely (Caps is also a locking key, delivered as a state-toggle). Workaround, confirmed working on neptune: press the literal `Ctrl+Opt+<key>` on the remote keyboard — the window manager's global hotkeys catch the injected chord directly. This is WM-independent (a property of the Karabiner Hyper substrate, true of any Hyper hotkey — AeroSpace or otherwise).

## Post-activation — grant AeroSpace Accessibility + Mission Control settings (manual, not declarable)

The Macs' window manager is **AeroSpace** ([ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md); `home/darwin/aerospace.nix`), with **JankyBorders** drawing the focus-border (`modules/darwin/jankyborders.nix`). Activation installs and launchd-starts both, but AeroSpace needs one manual grant before it can tile, and one Mission Control setting cleared. Neither is declarable — the grant is TCC-gated (same wall as Screen Sharing above), the setting is a per-user Dock preference AeroSpace reads at runtime.

### AeroSpace needs the Accessibility permission

AeroSpace moves windows through the macOS Accessibility (AX) API, so it **cannot tile anything** until it is granted Accessibility. Until then it launches and its menu-bar item appears, but windows stay where they are — the failure mode is "AeroSpace is running but does nothing," not a crash. AeroSpace prompts on first launch; approve via:

- **System Settings → Privacy & Security → Accessibility → enable AeroSpace.**

**The grant is lost on every AeroSpace upgrade — expect to re-grant.** The `pkgs.aerospace` bundle is **ad-hoc signed with no Team Identifier** (verified: `codesign -dv` reports `flags=…(adhoc,linker-signed)`, `TeamIdentifier=not set`), so macOS keys the Accessibility grant to the binary's *store path + cdhash* rather than a stable signing identity. Both change whenever `pkgs.aerospace` bumps version, so after a `nix flake update` that moves AeroSpace, the old grant no longer matches and tiling silently stops. Fix: in the Accessibility list, remove the stale AeroSpace entry (`−`) and re-add / re-toggle the new one, then relaunch AeroSpace (`aerospace reload-config` is not enough — the *process* needs the grant). This is intrinsic to running a store-path-installed unsigned app under TCC; it is not a misconfiguration.

### JankyBorders needs no grant

Deliberately called out so a future operator doesn't hunt for a missing permission: **JankyBorders requires no Accessibility (or any TCC) grant** in this config. By design it tracks windows through the window-server API rather than the AX API (that is its speed advantage), and `ax_focus` — the one option that would opt into the slower Accessibility path — is left off. Borders render immediately after activation with no prompt.

### Disable "Automatically rearrange Spaces based on most recent use"

- **System Settings → Desktop & Dock → Mission Control → turn *off* "Automatically rearrange Spaces based on most recent use"** (verified on macOS 26 Tahoe). Equivalent from the shell: `defaults write com.apple.dock mru-spaces -bool false && killall Dock` (`mru-spaces` = `0` when disabled).

AeroSpace recommends this so macOS doesn't reorder Spaces out from under the tiler's Space-index tracking. The Macs each run a **single** native Space (AeroSpace owns the workspace layer — ADR-040), so there is little for macOS to rearrange, but the setting is cleared as a precaution and to match AeroSpace's documented baseline. AeroSpace's guide lists further optional macOS tweaks (e.g. "Displays have separate Spaces", "Group windows by application") aimed at multi-monitor setups; none are needed on these single-display hosts.

## Verification

### Phase 1 — local on the new Mac

Run from the new Mac's user shell.

- `echo $SHELL` → fish at `/run/current-system/sw/bin/fish`. `chsh -s
  $(which fish)` should be a no-op (the shell is already declared via
  `users.users.dbf.shell` in `modules/darwin/users.nix`, and
  `environment.shells` carries the entry).
- `cd ~/nix-config && sops --decrypt secrets/secrets.yaml | head -3`
  prints `dbf-password:` + hash. The repo's devShell auto-activates
  via direnv and exports `SOPS_AGE_KEY_FILE`, so no env-var
  ceremony is needed. (If you see "no identity found", verify you
  `cd`d into the repo — outside it, the env var is not set.)
- macchina banner renders at every new interactive fish shell — every
  terminal tab, every zellij pane. The Apple-logo ASCII should display
  with colour. **If the `$2`/`$3`/etc. characters render literally
  rather than as colour escapes**, see Troubleshooting below.
- `hx` opens a `.nix` file with `nixd` LSP working — hover over
  `programs.git` shows the option's type. `:lsp-restart` if
  uncertain. (The binary is `hx`, not `helix` — `which helix`
  returns "not found"; that's expected.)
- `which claude` and `which cursor-agent` both resolve — the base
  agent set is on every host (ADR-008).
- `which codex` and `which agy` both resolve (both Mac daily-drivers import `agent-clis-extras.nix` for the full agent set).

### Phase 2 — SSH-context stack into the fleet

Prerequisite: this host's §Fleet SSH enrolment PR has landed **and each destination host has run its own switch** to pick up the new key — until then every hop below is refused. Realistic targets at bring-up: `metis` (and `neptune`, Mac-to-Mac). `mercury` and `nixos-vm` are retiring — mercury never learns a new host's key, and nixos-vm is a keyless sink (break-glass only, ADR-042).

For each target, `ssh dbf@<host>` and verify the SSH-context signals. Do **not** expect a terminal palette shift: ADR-041 deliberately retired the per-host palette repaint (TUIs follow the local terminal's palette; the Stylix fish target that emitted the OSC escapes was removed fleet-wide).

- **Starship prompt host marker** — the over-SSH `[custom]` block fires and names the remote host. This is *the* SSH-context signal post-ADR-041.
- **macchina banner** — renders on the remote's interactive fish init with the distro logo. Capture-mode smoke test without eyeballing: `ssh -t <host> 'fish -ic exit'` emits the banner + prompt block to stdout (`interactiveShellInit` fires regardless of TTY presence).
- **Terminal tab title** reflects the remote host (Ghostty is the `ghostty` cask on Darwin per ADR-031; tab-title behaviour matches Linux Ghostty).
- Claude Code statusline per-host colours are **#411-pending** — don't gate the bring-up on them.

Per-host palettes remain defined in `lib/host-palettes.nix` (saturn included); post-ADR-041 they no longer repaint terminals over SSH — the statuslines' ANSI conversion (#411) is the palette consumer still pending.

### Phase 3 — linux-builder

If the host imports `modules/darwin/linux-builder.nix`, the launchd
plist `org.nixos.linux-builder.plist` is registered and
`/var/lib/linux-builder/{keys,nixos.qcow2}` is created at first
activation. The VM image expands on first invocation.

```bash
nix build .#nixosConfigurations.nixos-vm.config.system.build.toplevel \
  --no-link --print-out-paths --print-build-logs 2>&1 | tee /tmp/phase3.log
```

Expected: succeeds and produces a closure path in `/nix/store/`.
**First-build baseline on a fresh aarch64-darwin host: ~30 minutes**
from a substitute-cache-warm starting point. Subsequent builds are
much faster (cache reuse).

The failure mode that's invisible without active verification is
**silent local fallback** — if `trusted-users` isn't wired correctly,
`nix build` succeeds without offloading to the VM and you get an
empty positive signal. Grep the log to confirm the remote builder
was actually used:

```bash
grep -c "on 'ssh-ng://builder@linux-builder'" /tmp/phase3.log
```

A non-zero count is the positive-evidence check. Zero count means
the build ran locally despite the linux-builder being available
— investigate `trusted-users` in `/etc/nix/nix.conf` (should
contain `@admin`; set in `modules/darwin/nix-daemon-darwin.nix`)
and `builders-use-substitutes = true`.

The VM listens on `:31022` for SSH. IPv4 may return
"connection refused" while IPv6 accepts; harmless. Verify:

```bash
nc -zv localhost 31022
```

`x86_64` hosts (mercury, metis) need a follow-up that adds the
second builder system to `nix.linux-builder.systems` — today only
`aarch64-linux` is declared.

Two calibration notes: the build target above rides `nixos-vm`, a retiring host — re-point this check at the then-current aarch64-linux target once it decommissions; and the ~30-minute first-build baseline was measured on an actively-cooled Mac mini — expect longer on a fanless MacBook Air.

## Subsequent updates

Day-to-day:

```bash
cd ~/nix-config
git pull
nh darwin switch
```

Generation rollback if something breaks:

```bash
sudo darwin-rebuild --rollback
# or pick a specific generation:
darwin-rebuild --list-generations   # list is fine unprivileged
sudo darwin-rebuild --switch-generation <N>
```

(The `sudo` is load-bearing: the pinned darwin-rebuild hard-errors on switch/rollback/activate as non-root — "system activation must now be run as root".)

## Break-glass

If `nh darwin switch` / `darwin-rebuild switch` produces a broken
generation:

1. **Roll back** — `sudo darwin-rebuild --rollback` reverts to the previous generation. Reliable because the rollback works entirely from local generations and requires no network.
2. **Physical console** — if you can't log in (broken shell config, etc.), boot into Recovery (on Apple Silicon: shut down, then hold the power button until "Loading startup options" → Options) or the Apple-keyboard admin login. macOS itself remains functional even when the
   nix-darwin generation is broken — the OS isn't replaced by
   nix-darwin, only configured.
3. **Disable the launchd job temporarily** — if a managed service
   misbehaves, `sudo launchctl bootout system/<plist-name>` removes
   the launchd entry until next activation.

There is no "kexec into an installer" equivalent on Darwin; macOS
itself is always the substrate.

## Troubleshooting

### `experimental Nix feature 'nix-command' is disabled`

You skipped step 2's experimental-features enablement. Apply the
single-line fix and reopen the shell:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### First activation errors with a `/etc/bashrc` or `/etc/zshrc` safety message

You skipped step 6. Move them aside and re-run:

```bash
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin 2>/dev/null
sudo mv /etc/zshrc  /etc/zshrc.before-nix-darwin  2>/dev/null
sudo nix run nix-darwin -- switch --flake .#<host>
```

### Determinate's `/etc/nix/nix.conf` vs nix-darwin's

If you used the Determinate installer (not the canonical path),
post-activation `/etc/nix/nix.conf` is owned by nix-darwin (written
from `modules/shared/nix-daemon.nix` + sibling Darwin overrides).
Determinate's installer settings are discarded. If you need to add
daemon settings, edit the Nix module — not the file directly.

### `users.users.dbf.uid` mismatch

If first activation errors with "user `dbf` exists but is not managed
by nix-darwin" or similar, the host file's `users.users.dbf.uid`
doesn't match the value macOS assigned. Re-run `id -u dbf`, update
the host file, re-stage, re-activate.

### `which helix` returns "not found"

The helix binary is named `hx`, not `helix`. The package is
installed; the verification check is `which hx` (returns
`/etc/profiles/per-user/dbf/bin/hx`) and `hx --version`.

### sops "no identity found" outside the repo

The devShell exports `SOPS_AGE_KEY_FILE`, but the env var only
exists inside `~/nix-config` (direnv auto-activation). Running
`sops` from elsewhere needs an explicit `SOPS_AGE_KEY_FILE=…`
prefix, or `cd ~/nix-config` first.

### Determinate installer marketing noise / abort

If you tried the Determinate installer (not the canonical path),
note that:
- It prints "use our macOS package instead" nudges both pre- and
  post-install regardless of the flag passed. Not an error.
- If it reports failure, run `which nix` before retrying — partial
  installs sometimes report failure on a late step despite Nix being
  functional. If `nix` resolves to a path, try a fresh terminal and
  `nix --version` before falling back to the NixOS-installer path.

### Stylix Darwin gaps

Upstream Stylix has known platform-specific gaps on Darwin
(`stylix.cursor`, `stylix.opacity` — issues
[nix-community/stylix#2078](https://github.com/nix-community/stylix/issues/2078)
and
[nix-community/stylix#440](https://github.com/nix-community/stylix/issues/440)).
Neither is used in this config, so the gaps don't block activation,
but if a future module reaches for those options, expect eval
failures until upstream lands fixes.

### macchina ASCII art renders `$2`/`$3` literally

The Apple-logo `ascii.txt` in `home/darwin/macchina-shell-init.nix`
uses macchina's `$N` palette-index colour-escape syntax (operator-
supplied). If the colours don't apply and you see literal `$2`,
`$3`, etc. characters in the banner output, the syntax isn't
honoured by the macchina version we ship. Mitigation: replace the
`$N` markers with explicit ANSI 4-bit colour escapes
(`\033[3{N}m...\033[0m`) in the module — same pattern the NixOS
sibling uses for Stylix-driven colours.

## What this runbook does NOT cover

- Recovery from a corrupted nix store on macOS — `/nix` repair via
  `nix-store --verify --check-contents --repair` from a working
  generation.
- Migrating an existing macOS install with extensive pre-nix-darwin
  state. Best path: snapshot, then run this runbook on top — the
  generations system lets you back out.
- Declarative iCloud / Apple-service state, Mosyle MDM
  interactions — out of scope per PRD §2.2. Mac App Store apps
  *are* covered now: declarative install via `homebrew.masApps`
  per ADR-031 clause 3. The cleanup asymmetry (entries dropped
  from `masApps` are not auto-uninstalled) means retirement is a
  two-step operation:

  ```bash
  # 1. Remove the entry from modules/darwin/homebrew.nix and
  #    activate. The app remains installed.
  # 2. Run by hand to actually uninstall:
  mas uninstall <numeric-id>
  ```

  Per-tool docs under `docs/desktop/` record both the numeric ID
  and the uninstall command for every managed MAS app.
- Ghostty inbound-SSH terminfo on Darwin. `pkgs.ghostty` is
  Linux-only in nixpkgs, so the Darwin side doesn't ship
  `xterm-ghostty` terminfo (neptune imports `modules/darwin/sshd.nix`
  directly; only NixOS hosts add it, via
  `modules/nixos/ghostty-terminfo.nix` in their remote-access bundle).
  Ghostty clients SSHing into a Darwin host either rely on Ghostty's
  shell-integration ssh-terminfo push (the client copies terminfo
  over on connect), fall back to `TERM=xterm-256color` with reduced
  rendering fidelity, or wait for a nix-homebrew Ghostty cask (#13)
  that ships terminfo system-wide. Operator uses Darwin hosts
  primarily as SSH clients, not servers — acceptable posture.
