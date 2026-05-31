# gnome-keyring — Secret Service for desktop app credentials

## Selection

Selection: **gnome-keyring** (secrets component only) as the
`org.freedesktop.secrets` provider for the niri desktop, **auto-unlocked
at login via PAM on the greetd service**.

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
persist** (re-authenticate every session). Métis currently has no
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
their secrets. PAM auto-unlock sidesteps this entirely:

- `security.pam.services.greetd.enableGnomeKeyring = true` unlocks the
  login keyring with the password entered at the greetd/tuigreet prompt,
  as the session starts. By the time any app asks, the Secret Service is
  already present **and unlocked**.
- Métis's login password is **sops-managed and immutable**
  (`users.dbf.hashedPasswordFile` ← `sops.secrets.dbf-password`), so the
  password the keyring is keyed to is stable — no drift between login
  password and keyring password.

### Why secrets-only (no SSH component)

gnome-keyring can also run an SSH agent that hijacks `SSH_AUTH_SOCK`. We
deliberately **do not** enable that component: the SSH-agent role belongs
to 1Password (#112). Keeping gnome-keyring scoped to the secrets
component leaves `SSH_AUTH_SOCK` free for 1Password to own.

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

Lands as a **system-side module** (it is PAM + a system service, not
home-manager), imported by the system desktop-env bundle so it only fires
on desktop hosts. Headless hosts (mercury, nixos-vm) never import it and
pay no closure cost.

Key choices:

- `services.gnome.gnome-keyring.enable = true` — starts the daemon /
  registers the Secret Service.
- `security.pam.services.greetd.enableGnomeKeyring = true` — PAM
  auto-unlock at login.
- **Secrets component only** — the SSH agent component is left off so
  `SSH_AUTH_SOCK` stays free for 1Password (#112).

## Sharp edges

- **First-login bootstrap.** The login keyring is created with the current
  login password the first time it is unlocked, and is consistent
  thereafter. **If the sops-managed login password is ever rotated, the
  keyring password desyncs** and must be reset (delete and recreate the
  login keyring, or re-key it). Note this whenever `dbf-password` changes.
- **dbus / session ordering.** Auto-unlock relies on the user session
  being started by greetd's PAM stack (it is). Verify post-login that the
  Secret Service is present and unlocked — e.g. `secret-tool store`/
  `lookup` round-trips, or `busctl --user list | grep secrets`.
- **Cursor/Electron backend detection.** Cursor should auto-detect
  `gnome-libsecret` once Secret Service is present; if it misfires, the
  lever is `--password-store=gnome-libsecret`. A verification step, not
  expected to be needed.
- **SSH component must stay off.** If gnome-keyring's ssh component is ever
  enabled, it will seize `SSH_AUTH_SOCK` and collide with 1Password
  (#112). Keep it scoped to secrets.

## References

- #104 — this slice (secure credential storage).
- #112 — 1Password adoption (human-facing PM + SSH agent); complementary.
- #103 — graphical authentication prompts (polkit); adjacent, not required
  for gnome-keyring auto-unlock.
- ADR-028 (desktop environment foundation), amended by ADR-029.
- `CLAUDE.md` — `users.mutableUsers = false` + sops-managed password
  stances that make PAM auto-unlock robust.
