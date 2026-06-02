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

Run once per fresh clone of this repo on the operator machine (the
*existing* operator host — for the first Mac, that's the UTM VM or
metis, since the Mac being bootstrapped doesn't yet have a working
sops decryption identity):

- `nix` with flakes enabled. Repo cloned. devShell entered once
  (`nix develop`, or direnv-reload via the repo's `.envrc`). The
  devShell's `shellHook` installs the pre-commit hooks (ADR-025) and
  exports `SOPS_AGE_KEY_FILE` so `sops --decrypt` works in-repo
  without env-var ceremony.
- An existing age decryption identity for `secrets/secrets.yaml`. On
  Linux operator hosts this comes from `just setup-sops-identity`
  (see [`headless-bootstrap.md`](./headless-bootstrap.md) §Operator
  prerequisites).
- Daniel's Mac SSH key in `modules/nixos/users.nix` matches the
  private key you intend to *carry over* to the new Mac (see
  pre-bootstrap step 1 below). If you're minting a brand-new key on
  the Mac instead, plan to update `modules/nixos/users.nix` and
  re-key sops *before* attempting first activation — both `dbf@mac`
  in `.sops.yaml` and the inbound-SSH whitelist on every NixOS host
  derive from the same keypair.

## Pre-bootstrap (operator-side, on the Mac)

The Mac Mini and MacBook Air both follow the same sequence. Steps
must run in order — each depends on the previous.

### 0 — macOS Setup Assistant

Walk through Setup Assistant. The only setting that matters downstream
is **Account Name** (the Unix short name shown under "Username" /
"Account Name" — Setup Assistant auto-derives one from the Full Name).
It **must** be `dbf` exactly. `lib/operator.nix:24` is the single source
of truth; `users.users.dbf`, `home-manager.users.dbf`, `/Users/dbf`,
and the `&mac` sops recipient pathway all key off this string.

The Full Name (the display name) can be anything.

### 1 — Carry over the operator SSH keypair

The `dbf@mac` recipient in `.sops.yaml` is derived from a specific
ed25519 keypair the operator has been using. The same public key is
whitelisted in `modules/nixos/users.nix:authorizedKeys` for inbound
SSH on every NixOS host. **Minting a new key on the Mac breaks both
ends silently**:

- Sops decryption will fail at activation when it can't open
  `secrets/secrets.yaml` for the `dbf@mac` recipient.
- `ssh dbf@<linux-host>` from the new Mac will be refused because the
  whitelisted key doesn't match.

Identify the right keypair on the source machine. **Filename is not
authoritative** — `id_ed25519` / `id_ed25519_personal` / etc. may
coexist, and the key comment (`dbf@mac`) is not an identity guarantee.
The keypair-of-record is identified by public-key body. Disambiguate:

```bash
# On the source machine, find the .pub whose key body matches the
# `&mac` recipient's public key from lib/operator.nix:
grep -l "AAAAC3NzaC1lZDI1NTE5AAAAIPNUroaa0Z3VyMJVnnQWTtuaosFL30E6xDsSUEAuS8MI" \
  ~/.ssh/*.pub
```

Transfer to the new Mac via Remote Login + `scp` (the canonical path):

1. On the new Mac: System Settings → General → Sharing → Remote Login
   on. Restrict access to "Only these users: dbf".
2. From the source machine:

   ```bash
   scp ~/.ssh/<the-right-key>{,.pub} dbf@<new-mac>:~/.ssh/
   ```

3. On the new Mac, fix permissions (`scp` doesn't preserve them):

   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

   Rename the private key to `id_ed25519` if it had a non-default name
   on the source — every downstream step (age derivation, ssh defaults)
   assumes that filename.

AirDrop and USB-stick variants work and may be more convenient if
Remote Login can't reach the source. Either way, end state must be the
same two files at `~/.ssh/id_ed25519{,.pub}` with the perms above.

If you've genuinely lost the old keypair, the recovery path is:
generate a new key, update `modules/nixos/users.nix:authorizedKeys`,
update `.sops.yaml`'s `mac` anchor (use `nix shell nixpkgs#ssh-to-age -c
ssh-to-age -i ~/.ssh/id_ed25519.pub` to derive the new age
recipient — drop the old anchor value at the same time so it can't
be silently re-used), `sops updatekeys secrets/secrets.yaml` on an
existing operator host, and push the changes to the repo *before*
continuing.

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

### 4 — Install the operator age identity

The Darwin sops module reads `~/.config/sops/age/keys.txt` (see
`modules/darwin/sops.nix`). Derive the age key from the SSH key
carried over in step 1:

```bash
mkdir -m 700 -p ~/.config/sops/age
nix shell nixpkgs#ssh-to-age -c \
  ssh-to-age -private-key -i ~/.ssh/id_ed25519 \
                          -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

### 5 — Verify the age key matches the `&mac` recipient

```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

Output must match `&mac` in `.sops.yaml` (currently
`age1qh0dm468a2pqr9rs4wr0zxslfmart8as8s7md93ah6dgd9rw55kqu94frp`). If
it doesn't, **stop** — the SSH key you carried over isn't the one
that produced the `dbf@mac` recipient. Re-do step 1 with the correct
key, or update `.sops.yaml` per the step 1 recovery path.

### 6 — Collect the operator UID for the host file

This step runs *after* macOS Setup Assistant has created the `dbf`
user account — without that, `id -u dbf` returns nothing.

```bash
id -u dbf
```

macOS's first-user default is 501. Pin this value in
`hosts/<host>/default.nix` as `users.users.dbf.uid = <value>;` *and*
`users.knownUsers = [ "dbf" ];` (see `modules/darwin/users.nix` — the
foundation declares the rest, but the UID is host-specific and must
match what macOS assigned during first-boot setup; nix-darwin refuses
to manage a user with a mismatched UID).

### 7 — Move aside `/etc/{bashrc,zshrc}` (NixOS-installer safety guard)

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

### 8 — Expect TCC prompts on first activation

When nix-darwin writes to `/Library/LaunchDaemons/`, macOS may
prompt for Full Disk Access for the activation process. Approve via
System Settings → Privacy & Security as the prompts surface. None of
the steps below auto-dismiss the prompt; first activation pauses
until you confirm. (On the 2026-06-02 mac-mini bootstrap no TCC
prompt surfaced; treat this as "may appear, may not".)

## First activation

> The `mac-mini` (and eventually `mba`) darwinConfiguration is its
> own PR — the host file at `hosts/<host>/default.nix` plus the
> mkDarwinHost invocation in `parts/darwin.nix`. If `nix flake show
> .#darwinConfigurations` returns an empty attrset for your host, the
> host PR hasn't landed yet — `git pull` the merge before continuing.

The first activation needs `sudo` because `nix run nix-darwin -- switch`
doesn't escalate on its own:

```bash
cd ~/nix-config
sudo nix run nix-darwin -- switch --flake .#<host>
```

(If the run errors part-way through with a `/etc/bashrc` /
`/etc/zshrc` safety message, you skipped step 7 — fix it and re-run.)

After this, `darwin-rebuild` is on PATH. Subsequent activations use
either:

```bash
darwin-rebuild switch --flake .#<host>
# or
nh darwin switch
```

`nh darwin switch` is the canonical command going forward (parallel
to `nh os switch` on NixOS); `NH_FLAKE` is set from
`hostContext.flakePath` per ADR-019.

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

Host mercury
  User dbf
  HostName <mercury's current AWS DNS>

Host metis
  HostName metis.<tailnet>.ts.net
  User dbf

Host metis-lan
  HostName <metis's LAN IP>
  User dbf
```

Entries depend on what's reachable from the Mac. `mercury` (public
AWS DNS) works from anywhere. `metis` via tailnet resolves only once
the Mac runs tailscale (gated on issue #13 — see "What this runbook
does NOT cover" below); use the `metis-lan` LAN entry until then.

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
- `which codex` and `which gemini` both resolve (mac-mini imports
  `agent-clis-extras.nix` for the full agent set).

### Phase 2 — SSH-context stack into the Linux fleet

For each reachable Linux host (`mercury`, `metis`, `nixos-vm`),
`ssh dbf@<host>` and verify the five signals visible and distinct.

There are **two verification modes**, with different coverage:

| Signal | Interactive `ssh mercury` | Capture via `ssh -t mercury 'fish -ic exit'` |
|---|---|---|
| 1. Palette shift (per-host base16) | visual | OSC palette escapes (`]4;0;rgb:…`) emitted to stdout |
| 2. Starship hostname segment | visual | starship `[custom]` over-SSH block fires in `~/.config/starship.toml` |
| 3. Terminal tab title reflects the host | visual; **deferred on Darwin** | not observable without terminal-frontend support |
| 4. macchina banner with NixOS logo + two-tone Stylix palette | visual | full banner emitted, escapes intact |
| 5. Claude Code statusline colours | visual; requires `claude` over SSH | not observable without launching the agent |

The interactive mode is the canonical full check. The capture mode
is useful for smoke-testing 1+2+4 without operator eyeballing
(handy for CI or AI-assisted bootstrap); `interactiveShellInit` fires
regardless of TTY presence so macchina's banner and the palette OSC
escapes round-trip cleanly into stdout.

Per-host palettes are defined in `lib/host-palettes.nix`:
`nixos-vm` → catppuccin-mocha, `mercury` → tokyo-night-dark,
`metis` → rose-pine, `mac-mini` → gruvbox-dark-hard.

**Signal 3 on Darwin hosts is deferred until issue #13 (nix-homebrew
cask bundle) lands** — Ghostty (the target terminal for tab-title
verification) distributes as a native `.app` on macOS, not via
nixpkgs (see issue #167 root cause). Until then, signal 3 is "not
verifiable on Darwin"; signals 1, 2, 4, 5 remain in scope.

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
contain `@admin`) and `builders-use-substitutes = true`.

The VM listens on `:31022` for SSH. IPv4 may return
"connection refused" while IPv6 accepts; harmless. Verify:

```bash
nc -zv localhost 31022
```

`x86_64` hosts (mercury, metis) need a follow-up that adds the
second builder system to `nix.linux-builder.systems` — today only
`aarch64-linux` is declared.

## Subsequent updates

Day-to-day:

```bash
cd ~/nix-config
git pull
nh darwin switch
```

Generation rollback if something breaks:

```bash
darwin-rebuild --rollback
# or pick a specific generation:
darwin-rebuild --list-generations
darwin-rebuild --switch-generation <N>
```

## Break-glass

If `nh darwin switch` / `darwin-rebuild switch` produces a broken
generation:

1. **Roll back** — `darwin-rebuild --rollback` reverts to the previous
   generation. Reliable because the rollback works entirely from
   local generations and requires no network.
2. **Physical console** — if you can't log in (broken shell config,
   etc.), boot into Recovery (Cmd-R at boot) or the Apple-keyboard
   admin login. macOS itself remains functional even when the
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

You skipped step 7. Move them aside and re-run:

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

### Mosh ALF prompt

ALF (`networking.applicationFirewall.enable = true`) passes signed
binaries by default. `pkgs.mosh` is a signed nixpkgs binary, so
inbound mosh should work without an extra prompt. If you adopt the
stealth posture (`enableStealthMode = true` in the host file), an
explicit allow may be needed; observe at activation.

## What this runbook does NOT cover

- Recovery from a corrupted nix store on macOS — `/nix` repair via
  `nix-store --verify --check-contents --repair` from a working
  generation.
- Migrating an existing macOS install with extensive pre-nix-darwin
  state. Best path: snapshot, then run this runbook on top — the
  generations system lets you back out.
- Mac App Store apps, declarative iCloud/Apple-service state, Mosyle
  MDM interactions — all explicitly out of scope per PRD §2.2.
- `nix-homebrew` integration. Deferred to issue
  [#13](https://github.com/dannyfaris/nix-config/issues/13). Until
  that lands, macOS-native apps that don't ship in nixpkgs
  (Ghostty, Tailscale, 1Password, etc.) are operator-installed by
  hand. Signal 3 of Phase 2 verification (terminal tab title) is
  gated on the Ghostty cask landing under #13.
- Ghostty inbound-SSH terminfo on Darwin. `pkgs.ghostty` is
  Linux-only in nixpkgs, so `modules/darwin/bundles/remote-access.nix`
  doesn't ship `xterm-ghostty` terminfo (the NixOS variant of the
  bundle does, via `modules/nixos/ghostty-terminfo.nix`). Ghostty
  clients SSHing into a Darwin host either rely on Ghostty's
  shell-integration ssh-terminfo push (the client copies terminfo
  over on connect), fall back to `TERM=xterm-256color` with reduced
  rendering fidelity, or wait for a nix-homebrew Ghostty cask (#13)
  that ships terminfo system-wide. Operator uses Darwin hosts
  primarily as SSH clients, not servers — acceptable posture.
