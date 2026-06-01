# Darwin bootstrap

Operational procedure for bringing a macOS host from clean state to a
fully-managed `nh darwin switch` target.

See [ADR-027](../decisions/ADR-027-foundation-and-bundles.md) for the
foundation + bundles composition model the Darwin tree mirrors and the
[`#11` epic](https://github.com/dannyfaris/nix-config/issues/11) for
the broader mac-mini onboarding context.

> This runbook is initially a forecast — written before first activation
> against the staged Darwin scaffolding (`modules/darwin/`,
> `lib/mk-darwin-host.nix`, the per-host palette entry). It will be
> refined post first activation with whatever the real sequence
> surfaces. Update freely as you learn.

## Operator prerequisites

Run once per fresh clone of this repo on the operator machine (the
*existing* operator host — for the first Mac, that's the UTM VM or
metis, since the Mac being bootstrapped doesn't yet have a working
sops decryption identity):

- `nix` with flakes enabled. The repo cloned, devShell entered once.
- An existing age decryption identity for `secrets/secrets.yaml`. On
  Linux operator hosts this comes from `just setup-sops-identity`
  (see [`headless-bootstrap.md`](./headless-bootstrap.md) §Operator
  prerequisites).
- Daniel's Mac SSH key in `modules/nixos/users.nix` matches the
  private key you intend to *carry over* to the new Mac (see
  pre-bootstrap step 1 below). If you're minting a brand-new key on
  the Mac instead, plan to update `modules/nixos/users.nix` and
  re-key sops *before* attempting first activation — both `dbf@mac`
  in `.sops.yaml` and the inbound-SSH whitelist on every Linux host
  derive from the same keypair.

## Pre-bootstrap (operator-side, on the Mac)

The Mac Mini and MacBook Air both follow the same sequence. Steps
must run in order — each depends on the previous.

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

Copy the existing keypair (private + public) onto the new Mac at
`~/.ssh/`:

```bash
# From the source Mac (or a USB key, or 1Password):
scp ~/.ssh/id_ed25519{,.pub} dbf@<new-mac>:~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

If you've genuinely lost the old keypair, the recovery path is:
generate a new key, update `modules/nixos/users.nix:authorizedKeys`,
update `.sops.yaml`'s `mac` anchor (use `nix shell nixpkgs#ssh-to-age -c
ssh-to-age -i ~/.ssh/id_ed25519.pub` to derive the new age
recipient — drop the old anchor value at the same time so it can't
be silently re-used), `sops updatekeys secrets/secrets.yaml` on an
existing operator host, and push the changes to the repo *before*
continuing.

### 2 — Install Nix

Determinate Systems installer, **upstream Nix variant** (not
Determinate Nix), per PRD §11.2:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix \
  | sh -s -- install --determinate=false
```

Restart your terminal to pick up the new PATH.

> Determinate's installer writes its own `/etc/nix/nix.conf`. After
> first `nix run nix-darwin -- switch` lands, nix-darwin owns that
> file and overwrites it with the flake's settings (`nix.enable =
> true` in `modules/darwin/foundation.nix`). The Determinate
> installer's content is discarded; the flake becomes source of truth
> for the daemon config.

### 3 — Clone the repo

```bash
git clone https://github.com/dannyfaris/nix-config.git ~/nix-config
cd ~/nix-config
```

The expected path is `/Users/dbf/nix-config` — this matches
`hostContext.flakePath`'s Darwin default in
`modules/darwin/host-context.nix` (`${operator.darwinHome}/${operator.flakeRepoDirname}`).

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

This step runs *after* macOS's first-boot setup has created the
`dbf` user account — without that, `id -u dbf` returns nothing.

```bash
id -u dbf
```

Pin this value in `hosts/<host>/default.nix` as `users.users.dbf.uid
= <value>;` *and* `users.knownUsers = [ "dbf" ];` (see
`modules/darwin/users.nix` — the foundation declares the rest, but
the UID is host-specific and must match what macOS assigned during
first-boot setup; nix-darwin refuses to manage a user with a
mismatched UID).

### 7 — Expect TCC prompts on first activation

When nix-darwin writes to `/Library/LaunchDaemons/`, macOS may
prompt for Full Disk Access for the activation process. Approve via
System Settings → Privacy & Security as the prompts surface. None of
the steps below auto-dismiss the prompt; first activation pauses
until you confirm.

## First activation

> The `mac-mini` (and eventually `mba`) darwinConfiguration is a
> separate PR — the host file at `hosts/<host>/default.nix` plus the
> mkDarwinHost invocation in `parts/darwin.nix`. This runbook lands
> ahead of that work so the operator can read the sequence before
> authoring the host file. If `nix flake show .#darwinConfigurations`
> returns an empty attrset, the host PR hasn't landed yet — finish
> that first.

```bash
cd ~/nix-config
nix run nix-darwin -- switch --flake .#<host>
```

After this, `darwin-rebuild` is on PATH. Subsequent activations use
either:

```bash
darwin-rebuild switch --flake .#<host>
# or
nh darwin switch
```

`nh darwin switch` is the canonical command (parallel to `nh os
switch` on NixOS); `NH_FLAKE` is set from `hostContext.flakePath` per
ADR-019.

## Verification

Run from the new Mac's user shell.

### Shared (all Darwin hosts)

- `echo $SHELL` → fish at the operator's expected path. `chsh -s
  $(which fish)` should be a no-op (the shell is already declared via
  `users.users.dbf.shell` in `modules/darwin/users.nix`, and
  `environment.shells` carries the entry).
- `sops --decrypt secrets/secrets.yaml` succeeds (age identity wired
  end-to-end).
- macchina banner renders at every new interactive fish shell — every
  Ghostty tab, every zellij pane. The Apple-logo ASCII should display
  with colour. **If the `$2`/`$3`/etc. characters render literally
  rather than as colour escapes**, see Troubleshooting below.
- `helix` opens a `.nix` file with `nixd` LSP working — hover over
  `programs.git` shows the option's type. `:lsp-restart` if uncertain.
- `which claude` and `which cursor-agent` both resolve — the base
  agent set is on every host (ADR-008).
- `which codex` and `which gemini` both resolve (mac-mini imports
  `agent-clis-extras.nix` for the full agent set).
- `programs.fish.interactiveShellInit` honours the operator's
  every-shell trigger — every new shell sees the macchina banner
  (login or otherwise).

### SSH-context stack from the Mac into the Linux fleet

For each of `nixos-vm`, `mercury`, `metis`, `ssh dbf@<host>` and
verify five signals visible and distinct:

1. Per-host palette in helix, bat, zellij, fish — the Mac uses
   gruvbox-dark-hard; each Linux host uses its own family
   (catppuccin-mocha / tokyo-night-dark / rose-pine).
2. Starship hostname segment in the prompt.
3. Ghostty tab title reflects the host name (via
   `programs.fish.functions.fish_title` in `home/shared/shell.nix`,
   which Ghostty reads at title-update time — there's no
   Ghostty-specific module).
4. macchina banner on shell launch shows the NixOS snowflake (each
   host's two-tone palette derived from its Stylix base16 entries).
5. Claude Code statusline colours derived from the host's palette.

### linux-builder

If the host imports `modules/darwin/linux-builder.nix`, the launchd
job provisions a Linux VM (persistent at `/var/lib/linux-builder/`)
on first activation. The VM image is built on first invocation.

```bash
nix build .#nixosConfigurations.nixos-vm.config.system.build.toplevel
```

This should succeed and produce a closure path in `/nix/store/`. The
build runs inside the VM; the Mac's daemon offloads via SSH at
`/etc/nix/builder_ed25519`. The module declares
`nix.settings.trusted-users` for `@admin` so `nix build` invoked from
the operator shell can drive the remote build — without it, the
build silently falls back to local-only.

`x86_64` hosts (mercury, metis) need a follow-up that adds the
second builder package; today only `aarch64-linux` is in
`nix.linux-builder.systems`.

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

### Determinate's `/etc/nix/nix.conf` vs nix-darwin's

After first activation, `/etc/nix/nix.conf` is owned by nix-darwin
(written from `modules/shared/nix-daemon.nix` + sibling Darwin
overrides). Determinate's installer settings are discarded. If you
need to add daemon settings, edit the Nix module — not the file
directly.

### `users.users.dbf.uid` mismatch

If first activation errors with "user `dbf` exists but is not managed
by nix-darwin" or similar, the host file's `users.users.dbf.uid`
doesn't match the value macOS assigned. Re-run `id -u dbf`, update
the host file, re-stage, re-activate.

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
- `nix-homebrew` integration. Deferred indefinitely per the epic
  scope; if a future PR adopts it, document the boundary alongside
  the module.
