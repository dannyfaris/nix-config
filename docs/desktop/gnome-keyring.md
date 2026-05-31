# gnome-keyring — Secret Service for desktop app credentials

## Selection

Selection: **gnome-keyring** as the `org.freedesktop.secrets` provider for
the niri desktop, **already active on metis as a transitive consequence of
the niri-flake nixosModule**. niri-flake's NixOS module sets
`services.gnome.gnome-keyring.enable = true` unconditionally (see
[niri-flake's `flake.nix`](https://github.com/sodiboo/niri-flake/blob/main/flake.nix) — every
host that imports niri's nixosModule gets it). nixpkgs's greetd module
then defaults `security.pam.services.greetd.enableGnomeKeyring` to
`config.services.gnome.gnome-keyring.enable` via `lib.mkDefault`, so PAM
auto-unlock at the greetd prompt is also wired by default. The
secrets-only outcome (no SSH component from gnome-keyring) is preserved
by *absence* of wiring — but **`gcr-ssh-agent`, a sibling daemon pulled in
by the same gnome-keyring activation, currently owns `SSH_AUTH_SOCK`**
(see [SSH_AUTH_SOCK ownership](#ssh_auth_sock-ownership) below).

This is invisible infrastructure: humans never interact with it. Its sole
job is to give desktop applications a place to store and retrieve their
own credentials. The human-facing password manager is 1Password, tracked
separately (#112) — see [Relationship to sops and 1Password](#relationship-to-sops-and-1password).

This doc records the *decision* to accept gnome-keyring as the chosen
provider — not the *implementation*, which we inherit. The only thing
this slice actually adds to the configuration is **`libsecret` on PATH**
so the `secret-tool` CLI is available for verification and scripting; the
keyring daemon itself is already running.

## Rationale

### The need

Electron/VSCode-family apps — Cursor IDE in particular, and the OAuth
tokens for MCP servers it authenticates (e.g. Atlassian) — store their
own secrets by *pushing* them to the OS Secret Service
(`org.freedesktop.secrets`) over D-Bus via libsecret, and reading them
back on next launch. With no Secret Service provider running, those
writes either fail or fall back to an insecure store, and logins don't
persist across sessions. metis has had a provider running since niri
landed (#69 / ADR-028 et seq.) — this doc retroactively records the
choice; it does not introduce the daemon.

### Why gnome-keyring (the inherited choice is the right one)

- **It is the reference `org.freedesktop.secrets` implementation** and the
  backend Electron/VSCode/Cursor target first (`gnome-libsecret`). KWallet
  is the only other backend Cursor speaks, and it is the wrong ecosystem
  for a niri/GTK-leaning host.
- **Standalone daemon — no GNOME desktop required.** `gnome-keyring-daemon`
  is the standard Secret Service provider in sway/niri setups; it does
  not pull in a GNOME session.
- **Auto-unlockable via PAM**, which is what makes it usable in a
  compositor with no graphical unlock prompter.
- **No Stylix surface needed** — no UI, nothing to theme.

If niri-flake ever stopped enabling gnome-keyring, metis would need to
enable it explicitly. This doc is the record of "yes, we still want it
running" — so if the inheritance ever flips, the prior decision is on
file.

### Why PAM auto-unlock at greetd

The unlock mechanism is the real design point. niri runs no graphical
unlock prompter (`gcr-prompter`), so an on-demand "unlock the keyring"
dialog would have nowhere to appear — apps would silently fail to read
their secrets. PAM auto-unlock avoids needing one:

- `security.pam.services.greetd.enableGnomeKeyring = true` (set by
  nixpkgs's greetd module as `lib.mkDefault config.services.gnome.gnome-keyring.enable`)
  adds `pam_gnome_keyring` to greetd's PAM stack. When it works, the
  login keyring unlocks with the password entered at the greetd/tuigreet
  prompt as the session starts, so by the time any app asks, the Secret
  Service is already present **and unlocked**.
- metis's login password is **sops-managed and immutable**
  (`users.dbf.hashedPasswordFile` ← `sops.secrets.dbf-password`), so the
  password the keyring is keyed to is stable — no drift between login
  password and keyring password.

The load-bearing caveat: `pam_gnome_keyring` only unlocks if the *same*
PAM service runs both its `auth` phase (to capture the password into the
PAM token) and its `session` phase (to unlock with it). The greetd +
`useTextGreeter` + tuigreet path is exactly the combination where that
auth→session hand-off is known to be fragile. The PAM stack on metis
today *does* carry `pam_gnome_keyring` in all three phases (`auth`,
`password`, `session auto_start`), and the auth→session hand-off has
been **verified to fire on metis** (2026-05-31, post-#116 merge — see
[Sharp edges](#sharp-edges) for the test record).

### SSH_AUTH_SOCK ownership

This is where the picture gets nuanced and the original framing of this
slice was wrong.

**gnome-keyring's own ssh-agent is not wired into the session.** The
`gnome-keyring-ssh.desktop` autostart entry does not ship in metis's
`/etc/xdg/autostart` directory (`gnome-keyring-pkcs11.desktop` and
`gnome-keyring-secrets.desktop` do — but no `-ssh`), so gnome-keyring's
ssh socket is never exported into `SSH_AUTH_SOCK`. So far so good.

**`gcr-ssh-agent`, however, *is* running and *does* own `SSH_AUTH_SOCK`.**
`gcr-ssh-agent.service` (from the `gcr` package, a sibling of
gnome-keyring also pulled in by gnome-keyring's activation) is enabled
out of the box. Its `.socket` unit's `ExecStartPost` actively sets
`SSH_AUTH_SOCK=%t/gcr/ssh` in the user systemd environment at
socket-activation time. On metis right now:

```
SSH_AUTH_SOCK=/run/user/1000/gcr/ssh
gcr-ssh-agent.service     active running   GCR ssh-agent wrapper
gcr-ssh-agent.socket      active running   GCR ssh-agent wrapper
```

So `SSH_AUTH_SOCK` is **not** free for 1Password to claim today; it is
claimed by `gcr-ssh-agent`. The original framing of "leave SSH_AUTH_SOCK
unwired so 1Password can own it when #112 lands" elided this.

**Resolution: punted to #112.** The 1Password adoption work
(#112) is the right place to decide what happens to `gcr-ssh-agent`
— either mask `gcr-ssh-agent.socket` and let 1Password claim the slot,
or override `SSH_AUTH_SOCK` later in the session env so 1Password wins
the priority race. That decision belongs with the 1Password design,
not here. This doc records the live state and the cross-reference;
#112 is amended to include the eviction question in its scope.

## Alternatives considered

| Option | Why not |
|--------|---------|
| **KeePassXC** (Secret Service integration) | Attractive only as a visible, portable vault — but that role is going to 1Password (#112), so running KeePassXC too would be a redundant second vault. Also requires a running GUI app and manual unlock every login (no seamless PAM unlock). |
| **KWallet** | Provides Secret Service, but drags the KDE/Qt wallet stack into a deliberately niri/GTK-leaning host. Wrong ecosystem unless the desktop ever goes KDE. |
| **1Password as the provider** | 1Password does **not** implement `org.freedesktop.secrets`; it is pull/retrieve, not a libsecret push target. It cannot catch Cursor's auto-store writes. Complementary, not a substitute (see below). |
| **On-demand unlock via gcr prompter** | Needs a running `gcr-prompter` on the session bus, which niri does not provide; clunky and failure-prone. PAM auto-unlock is strictly better here. |
| **No keyring — Cursor `--password-store=basic`** | Stores secrets in a file encrypted with a hardcoded key (obfuscation, not security). Rejected against the repo's security posture. |
| **Explicit ownership module (initially proposed)** | An earlier attempt to add `modules/core/nixos/gnome-keyring.nix` that set the two options the inheritance already sets. Rejected after measurement: derivation-level no-op (drvPath byte-identical to main), and the file's "SSH_AUTH_SOCK left free" comment was factually wrong about gcr-ssh-agent. The niri.cachix.org pattern of explicit-ownership applies to trust delegations (substituters/keys), not service activations — and the `xdg.portal.enable = true` precedent (also inherited from niri-flake, also not explicitly owned) shows the repo doesn't apply explicit-ownership as a blanket rule. |

## Relationship to sops and 1Password

Three secret layers, deliberately kept distinct:

- **sops** — declarative secrets *at rest*, provisioned at deploy time
  (host keys, the login hash itself). Operator-authored. **Not** a source
  for keyring contents — different lifecycle; do not wire one from the
  other.
- **1Password** (#112) — the human-facing password manager and SSH agent.
  *Pull/retrieve*: you deliberately ask for a secret (`op read`, the
  desktop app). When it lands, it will need to displace `gcr-ssh-agent`
  to own `SSH_AUTH_SOCK`.
- **gnome-keyring** (this doc) — invisible *push/auto-store* for app
  tokens (Cursor, MCP, anything libsecret). Humans never touch it.

## Configuration

What this repo actually configures:

- **`pkgs.libsecret` in `environment.systemPackages`** — installed via
  `modules/core/nixos/libsecret.nix`, imported by the system
  desktop-env bundle so it only fires on desktop hosts. This puts
  `secret-tool` on PATH for the verification round-trip below and for
  any future scripts that want to talk to the Secret Service from the
  shell. Closure cost: ~3 MiB (libsecret + its deps that aren't already
  in the desktop closure).
- **Everything else is inherited.** `services.gnome.gnome-keyring.enable
  = true` comes from niri-flake's nixosModule.
  `security.pam.services.greetd.enableGnomeKeyring = true` comes from
  nixpkgs's greetd module's default. Both are accepted as-is — the
  `xdg.portal.enable` precedent (also inherited from niri-flake, also
  not explicitly re-asserted) is the same call.

Nothing is wired for gnome-keyring's ssh-agent component (no
`gnome-keyring-ssh.desktop` autostart, no SSH-agent socket export). The
SSH-agent slot is currently held by `gcr-ssh-agent`; see [SSH_AUTH_SOCK
ownership](#ssh_auth_sock-ownership).

## Sharp edges

- **PAM auto-unlock under tuigreet — verified working on metis
  (2026-05-31).** `pam_gnome_keyring` only unlocks if greetd's PAM
  service runs both its `auth` phase (capturing the password into the
  PAM token) and its `session` phase (unlocking with it). The greetd +
  `useTextGreeter` + tuigreet combination is the known-fragile case for
  that hand-off — the token does not always propagate from auth to
  session the way `login`/GDM/SDDM stacks do. The PAM stack on metis
  carries `pam_gnome_keyring` in all three phases (`auth`, `password`,
  `session auto_start`), and a post-#116 verification run from a fresh
  tuigreet login showed:

  ```
  $ busctl --user get-property org.freedesktop.secrets \
      /org/freedesktop/secrets/collection/login \
      org.freedesktop.Secret.Collection Locked
  b false                                            # ← unlocked

  $ printf 'fresh-login-payload' | secret-tool store \
      --label=verify claude-fresh metis-2026-05-31          # exit 0, no prompt
  $ secret-tool lookup claude-fresh metis-2026-05-31
  fresh-login-payload                                # ← round-trip OK
  $ secret-tool clear claude-fresh metis-2026-05-31         # exit 0
  ```

  **Re-verify whenever any of the load-bearing pieces change**: the
  greetd module's PAM wiring, the
  tuigreet/useTextGreeter path, niri-flake's keyring activation, or the
  sops-managed login password (see "First-login bootstrap" below). If a
  future change ever breaks the hand-off, the fallbacks are (a) confirm
  `pam_gnome_keyring` is still on the `session` phase as well as `auth`,
  or (b) accept a one-time interactive unlock on first secret access (no
  prompter on niri — would break Cursor's silent token push).
- **`gcr-ssh-agent` claims `SSH_AUTH_SOCK`.** See [SSH_AUTH_SOCK
  ownership](#ssh_auth_sock-ownership). Resolution lives in #112.
- **First-login bootstrap.** The login keyring is created with the
  current login password the first time it is unlocked, and is
  consistent thereafter. **If the sops-managed login password is ever
  rotated, the keyring password desyncs** and must be reset (delete and
  recreate the login keyring, or re-key it). Note this whenever
  `dbf-password` changes.
- **First-activation D-Bus visibility.** gnome-keyring registers the
  `org.freedesktop.secrets` bus name. As documented for fnott
  ([fnott.md](./fnott.md) §Sharp edges), `dbus-broker` caches its
  service scan at session start, so a name introduced mid-session by an
  activation may not be visible until the broker rescans
  (`systemctl --user reload dbus.service`) or the session is restarted.
  In practice this is irrelevant here because gnome-keyring has been
  running since the niri landing.
- **Cursor/Electron backend detection.** Cursor should auto-detect
  `gnome-libsecret` once Secret Service is present; if it misfires, the
  lever is `--password-store=gnome-libsecret`. A verification step, not
  expected to be needed.
- **Keep gnome-keyring's ssh component unwired.** gnome-keyring has no
  off switch for its ssh agent; secrets-only is preserved by *not*
  pulling in `gnome-keyring-ssh.desktop` or exporting its ssh-agent
  socket. If a future change ever wires that socket, it will collide
  with whatever is currently holding `SSH_AUTH_SOCK` (today gcr-ssh-agent,
  tomorrow 1Password).

## References

- [`modules/core/nixos/libsecret.nix`](../../modules/core/nixos/libsecret.nix)
  — the only actual addition for this slice; installs the `secret-tool`
  CLI.
- [`modules/core/nixos/bundles/desktop-env.nix`](../../modules/core/nixos/bundles/desktop-env.nix)
  — the system desktop-env bundle that imports libsecret.nix.
- [`modules/core/nixos/niri.nix`](../../modules/core/nixos/niri.nix)
  — the import of niri-flake's nixosModule that transitively enables
  gnome-keyring.
- [`modules/core/nixos/greetd.nix`](../../modules/core/nixos/greetd.nix)
  — the greetd/tuigreet service whose PAM stack carries the auto-unlock.
- [`modules/core/nixos/users.nix`](../../modules/core/nixos/users.nix)
  — sops-managed, immutable login password the keyring keys against.
- #104 — this slice (secure credential storage).
- #112 — 1Password adoption (human-facing PM + SSH agent); will resolve
  `gcr-ssh-agent`'s current claim on `SSH_AUTH_SOCK`.
- #103 — graphical authentication prompts (polkit); adjacent, not
  required for gnome-keyring auto-unlock.
- ADR-028 (desktop environment foundation), amended by ADR-029.
- `CLAUDE.md` — `users.mutableUsers = false` + sops-managed password
  stances that keep the keyring password stable across rebuilds.
