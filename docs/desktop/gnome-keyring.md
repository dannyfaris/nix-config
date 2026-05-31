# gnome-keyring — Secret Service for desktop app credentials

## Selection

Selection: **gnome-keyring** as the `org.freedesktop.secrets` provider for
the niri desktop, with the keyring **intended to auto-unlock at login via
PAM on the greetd service** (pending on-host verification — see Sharp
edges). Only the Secret Service component is wired into the session; the
SSH-agent component is left unwired (see [Why secrets-only](#why-secrets-only-no-ssh-component)).

This is invisible infrastructure: humans never interact with it. Its sole
job is to give desktop applications a place to store and retrieve their
own credentials. The human-facing password manager is 1Password, tracked
separately (#112) — see [Relationship to sops and 1Password](#relationship-to-sops-and-1password)
below.

## Rationale

### The need

Electron/VSCode-family apps — Cursor IDE in particular, and the OAuth
tokens for MCP servers it authenticates (e.g. Atlassian) — store their
own secrets by *pushing* them to the OS Secret Service
(`org.freedesktop.secrets`) over D-Bus via libsecret, and reading them
back on next launch. With no Secret Service provider running, those
writes either fail or fall back to an insecure store, and **logins don't
persist** (re-authenticate every session). metis currently has no
provider at all.

### Why gnome-keyring

- **It is the reference `org.freedesktop.secrets` implementation** and the
  backend Electron/VSCode/Cursor target first (`gnome-libsecret`). KWallet
  is the only other backend Cursor speaks, and it is the wrong ecosystem
  for a niri/GTK-leaning host.
- **Standalone daemon — no GNOME desktop required.** `gnome-keyring-daemon`
  is the standard Secret Service provider in sway/niri setups; it does not
  pull in a GNOME session.
- **Auto-unlockable via PAM** (see below), which is what makes it usable
  in a compositor that has no graphical unlock prompter.
- **No Stylix surface needed** — it has no UI, so there is nothing to
  theme.

### Why PAM auto-unlock at greetd

The unlock mechanism is the real design point. niri runs no graphical
unlock prompter (`gcr-prompter`), so an on-demand "unlock the keyring"
dialog would have nowhere to appear — apps would silently fail to read
their secrets. PAM auto-unlock is the mechanism that avoids needing one:

- `security.pam.services.greetd.enableGnomeKeyring = true` adds
  `pam_gnome_keyring` to greetd's PAM stack. When it works, the login
  keyring unlocks with the password entered at the greetd/tuigreet prompt
  as the session starts, so by the time any app asks, the Secret Service
  is already present **and unlocked**.
- metis's login password is **sops-managed and immutable**
  (`users.dbf.hashedPasswordFile` ← `sops.secrets.dbf-password`), so the
  password the keyring is keyed to is stable — no drift between login
  password and keyring password.

The load-bearing caveat: `pam_gnome_keyring` only unlocks if the *same*
PAM service runs both its `auth` phase (to capture the password into the
PAM token) and its `session` phase (to unlock with it). The greetd +
`useTextGreeter` + tuigreet path is exactly the combination where that
auth→session hand-off is known to be fragile, so this is **intended, not
yet verified on metis** — it is treated as the primary sharp edge below,
not an assumption.

### Why secrets-only (no SSH component)

gnome-keyring can also run an SSH agent. There is no `services.gnome.gnome-keyring`
option to switch that component off — the module is essentially
enable-only. The secrets-only outcome is therefore achieved by the
*absence* of wiring, not a toggle: nothing in this config exports
gnome-keyring's ssh-agent socket into `SSH_AUTH_SOCK` (and the autostart
`gnome-keyring-ssh.desktop` is not pulled into the niri session), so the
ssh component never becomes the agent even though the daemon is capable of
it.

This is deliberate: the SSH-agent role belongs to 1Password (#112).
Leaving `SSH_AUTH_SOCK` unclaimed today keeps it free for 1Password to
own when that lands. (Today nothing in-repo sets `SSH_AUTH_SOCK` — see
`home/core/shared/ssh.nix` — so this is forward-looking design intent, not
an already-live arrangement.)

## Alternatives considered

| Option | Why not |
|--------|---------|
| **KeePassXC** (Secret Service integration) | Attractive only as a visible, portable vault — but that role is going to 1Password (#112), so running KeePassXC too would be a redundant second vault. Also requires a running GUI app and manual unlock every login (no seamless PAM unlock). |
| **KWallet** | Provides Secret Service, but drags the KDE/Qt wallet stack into a deliberately niri/GTK-minimal host. Wrong ecosystem unless the desktop ever goes KDE. |
| **1Password as the provider** | 1Password does **not** implement `org.freedesktop.secrets`; it is pull/retrieve, not a libsecret push target. It cannot catch Cursor's auto-store writes. Complementary, not a substitute (see below). |
| **On-demand unlock via gcr prompter** | Needs a running `gcr-prompter` on the session bus, which niri does not provide; clunky and failure-prone. PAM auto-unlock is strictly better here. |
| **No keyring — Cursor `--password-store=basic`** | Stores secrets in a file encrypted with a hardcoded key (obfuscation, not security). Rejected against the repo's security posture. |

## Relationship to sops and 1Password

Three secret layers, deliberately kept distinct:

- **sops** — declarative secrets *at rest*, provisioned at deploy time
  (host keys, the login hash itself). Operator-authored. **Not** a source
  for keyring contents — different lifecycle; do not wire one from the
  other.
- **1Password** (#112) — the human-facing password manager and SSH agent.
  *Pull/retrieve*: you deliberately ask for a secret (`op read`, the
  desktop app). Owns `SSH_AUTH_SOCK`.
- **gnome-keyring** (this doc) — invisible *push/auto-store* for app
  tokens (Cursor, MCP, anything libsecret). Humans never touch it.

## Configuration

Lands as a **system-side module** under `modules/core/nixos/`, imported
by the system desktop-env bundle so it only fires on desktop hosts. It is
nixos/-placed (not shared/) because both surfaces are Linux-only: PAM is a
Linux mechanism and `services.gnome.gnome-keyring` has no Darwin analogue,
so there is no cross-platform variant to factor into shared/ per the
shared-purity rule (ADR-027). Headless hosts (mercury, nixos-vm) never
import it and pay no closure cost; the desktop host pays the gcr / p11-kit
/ libgcrypt dependency chain gnome-keyring pulls in (modest, and already
adjacent to the GTK stack the desktop carries).

Key choices:

- `services.gnome.gnome-keyring.enable = true` — starts the daemon /
  registers the Secret Service.
- `security.pam.services.greetd.enableGnomeKeyring = true` — adds
  `pam_gnome_keyring` to greetd's PAM stack for login auto-unlock (subject
  to the auth→session caveat in Sharp edges).
- **Secrets component only — by omission.** Nothing wires gnome-keyring's
  ssh-agent socket into `SSH_AUTH_SOCK`, so the ssh component never takes
  over (there is no explicit off switch; see [Why secrets-only](#why-secrets-only-no-ssh-component)).

## Sharp edges

- **(Primary) PAM auto-unlock may not fire under tuigreet.**
  `pam_gnome_keyring` unlocks only if greetd's PAM service runs both its
  `auth` phase (capturing the password into the PAM token) and its
  `session` phase (unlocking with it). The greetd + `useTextGreeter` +
  tuigreet combination is the known-fragile case for that hand-off — the
  token does not always propagate from auth to session the way
  `login`/GDM/SDDM stacks do. **Must be verified on metis at implementation
  time**, not assumed. Verification: after login, with no manual unlock,
  confirm the Secret Service is present *and unlocked* — a `secret-tool
  store`/`lookup` round-trip should succeed without prompting, or
  `busctl --user list | grep secrets` shows the name. If auto-unlock
  fails, the fallbacks are (a) ensure `pam_gnome_keyring` is on the
  session as well as auth phase, or (b) accept a one-time interactive
  unlock on first secret access. The whole point of choosing PAM was to
  avoid a prompter, so a failure here is the thing most likely to send the
  design back for rework.
- **First-login bootstrap.** The login keyring is created with the current
  login password the first time it is unlocked, and is consistent
  thereafter. **If the sops-managed login password is ever rotated, the
  keyring password desyncs** and must be reset (delete and recreate the
  login keyring, or re-key it). Note this whenever `dbf-password` changes.
- **First-activation D-Bus visibility.** gnome-keyring registers the
  `org.freedesktop.secrets` bus name. As documented for fnott
  ([fnott.md](./fnott.md) §Sharp edges), `dbus-broker` caches its service
  scan at session start, so a name introduced mid-session by the
  activation that first enables this module may not be visible until the
  broker rescans (`systemctl --user reload dbus.service`) or the session
  is restarted. PAM-started gnome-keyring largely sidesteps this (it is
  launched by the PAM stack at login, not D-Bus-activated on demand), but
  the same first-activation shape is worth knowing when verifying on the
  introducing rebuild — a clean logout/login is the reliable check.
- **Cursor/Electron backend detection.** Cursor should auto-detect
  `gnome-libsecret` once Secret Service is present; if it misfires, the
  lever is `--password-store=gnome-libsecret`. A verification step, not
  expected to be needed.
- **Keep the ssh component unwired.** gnome-keyring has no off switch for
  its ssh agent; secrets-only is preserved by *not* exporting its
  ssh-agent socket into `SSH_AUTH_SOCK`. If a future change ever wires
  that socket (or pulls in `gnome-keyring-ssh.desktop`), it will seize
  `SSH_AUTH_SOCK` and collide with 1Password (#112). Leave it unwired.

## References

- `modules/core/nixos/gnome-keyring.nix` — the implementing system module
  (planned location; lands with the implementation commit per
  doc-precedes-code).
- [`modules/core/nixos/bundles/desktop-env.nix`](../../modules/core/nixos/bundles/desktop-env.nix)
  — the system desktop-env bundle this module is imported into.
- [`modules/core/nixos/greetd.nix`](../../modules/core/nixos/greetd.nix)
  — the greetd/tuigreet service whose PAM stack carries the auto-unlock.
- [`modules/core/nixos/users.nix`](../../modules/core/nixos/users.nix)
  — sops-managed, immutable login password the keyring keys against.
- [`home/core/shared/ssh.nix`](../../home/core/shared/ssh.nix) — where the
  `SSH_AUTH_SOCK` ownership (left free for 1Password) will be settled.
- #104 — this slice (secure credential storage).
- #112 — 1Password adoption (human-facing PM + SSH agent); complementary.
- #103 — graphical authentication prompts (polkit); adjacent, not required
  for gnome-keyring auto-unlock.
- ADR-028 (desktop environment foundation), amended by ADR-029.
- `CLAUDE.md` — `users.mutableUsers = false` + sops-managed password
  stances that keep the keyring password stable across rebuilds.
