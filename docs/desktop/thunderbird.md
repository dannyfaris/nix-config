# Thunderbird

Mozilla's native desktop email client. Gecko toolkit (shared with Firefox). Native Wayland. The chosen mail client on metis for the operator's **personal Gmail + iCloud Mail** — work Microsoft 365 stays on mac-mini (see [microsoft-365.md](./microsoft-365.md)).

## Selection

**Thunderbird** on metis, enabled via `home/nixos/thunderbird.nix` (HM module `programs.thunderbird.enable = true`). **Install only** — no profile and no accounts are declared in Nix. The profile and both mail accounts are created and managed at runtime through the Thunderbird GUI.

This mirrors the Noctalia `settings.json` posture on this config: runtime/GUI-managed state, not Nix-pinned (see [noctalia.md](./noctalia.md)). The operator has no preference for declarative accounts, and runtime-managed is the simpler, lower-friction path for two plain IMAP/SMTP mailboxes.

No Stylix theming and no Noctalia template — theming defers entirely to Thunderbird's own engine plus desktop polarity. See [Theming](#theming) below.

## Rationale

**Native GUI requirement.** The operator wanted a real desktop mail client, not web/PWA mail. That ruled out the browser-tab path (Gmail + iCloud web in Firefox) and the TUI path (aerc / neomutt), both of which were viable on the merits but failed the GUI requirement. See [Alternatives considered](#alternatives-considered).

**Both accounts are plain IMAP/SMTP.** Personal Gmail and iCloud Mail are ordinary IMAP/SMTP — no Exchange/EWS, because the work Microsoft 365 account is deliberately out of scope (it lives on mac-mini; on Linux there is no native Outlook desktop anyway). Plain IMAP removes the usual mail-client setup friction and means any competent client would have worked; the choice came down to the GUI requirement and toolkit cost.

**Small marginal closure.** Firefox is already on metis (`home/nixos/firefox.nix`), so the Gecko toolkit is already in the closure. Thunderbird's *marginal* closure is much smaller than its standalone size, so the "big Gecko app" cost objection largely does not apply. (Marginal closure not measured here; measure with `nix path-info -S` set-math if a number is ever wanted, and single-source it.)

**In the pin, mature HM module.** `thunderbird` 151.0.1 is present in the locked nixpkgs; the `programs.thunderbird` HM module and the `accounts.email` framework are both present in the locked home-manager. Enabling is a one-liner; declarative accounts are available but deliberately unused (see Configuration).

## Alternatives considered

**aerc / neomutt (TUI)** — passed over. Philosophically the closest fit: both run in foot, inherit base16 by terminal inheritance, and sit naturally alongside the yazi/macchina TUI aesthetic, and both accounts being plain IMAP removes the usual Exchange pain that pushes people to GUI clients. Passed over solely because the operator wanted a full GUI client. (For reference, had the TUI path been taken, the pin also carries `aerc` 0.21.0, `neomutt` 20260105, `isync` 1.5.1, `msmtp` 1.8.32.)

**Browser web / PWA (Gmail + iCloud web in Firefox)** — passed over. Zero new packages and consistent with the Teams/M365 web precedent on mac-mini, but the operator is not keen on web mail and wanted a native client.

## Configuration

**HM module** — `home/nixos/thunderbird.nix`:

```nix
_: {
  programs.thunderbird.enable = true;
}
```

Install only. No `profiles.*` block is declared, so the `programs.thunderbird` one-default-profile assertion does not fire (it is gated on `cfg.profiles != { }`), and Thunderbird creates and manages its own profile on first launch. Accounts are added in the GUI.

Lives under `home/nixos/` for consistency with the rest of the desktop stack (the mail client is part of the metis Wayland session). Unlike foot/fuzzel/fnott — which don't build on Darwin at all — `pkgs.thunderbird` does build on Darwin, so this placement is a stack-cohesion call, not a portability constraint; the macOS mail client is a separate decision (work mail is Outlook on mac-mini per [microsoft-365.md](./microsoft-365.md)).

**Accounts are runtime/GUI-managed, not Nix-pinned.** The HM `accounts.email` + `programs.thunderbird.profiles.<p>.accounts` surface exists and could declare the mailboxes, but is deliberately not used. Credentials and account config live in Thunderbird's own store at runtime, consistent with the Noctalia settings posture on this config. This keeps mail secrets out of the Nix store and avoids declaring OAuth/app-password plumbing that the GUI handles natively.

**Wayland enablement** — none required. Thunderbird 151 is the same Gecko as Firefox and auto-detects `WAYLAND_DISPLAY` at startup; niri sets that variable for session-spawned processes, so Thunderbird launches Wayland-native with no env-var ritual. This deliberately matches the host's Firefox wiring, which relies on the same auto-detection — the historical `MOZ_ENABLE_WAYLAND=1` opt-in is now a no-op (see [firefox.md](./firefox.md) §Configuration), so it is **not** set here. The lever in the other direction (`MOZ_ENABLE_WAYLAND=0`) forces X11 if a future regression ever requires it.

### Theming

There is **no Thunderbird template** in Noctalia (its built-in templates are niri borders, GTK, foot, helix, starship, yazi, btop — see [noctalia.md](./noctalia.md) §Theming) and **no Thunderbird target** in Stylix (verified against the pin). So "Noctalia themes everything" resolves, for Thunderbird specifically, to:

- **Polarity (light/dark): yes, indirectly** — *if* Thunderbird is set to its "follow system" theme **and** the desktop's freedesktop `color-scheme` portal signal is being driven. Today that signal comes from the [`portal-color-scheme.nix`](../../home/nixos/portal-color-scheme.nix) bridge (`stylix.polarity` → the GNOME-portal dconf key), the same portal path Firefox's chrome and web-content `prefers-color-scheme` already follow. Then Thunderbird flips polarity with the rest of the desktop.
- **Full palette / accent: no.** The message list and content area are painted by Thunderbird's own theme engine.

The outcome is **"polarity-follows, palette-vanilla"**: vanilla Thunderbird light/dark with GTK chrome roughly matching, not a Noctalia-palette app. This is consistent with the "vanilla, idiomatic Noctalia" call and is accepted. Like the rest of Noctalia theming, the polarity-follow is on-box-pending — not provable headlessly.

## Sharp edges

**Account auth differs per provider, and lives in Thunderbird, not Nix.**

- **Gmail** — OAuth2 (interactive browser consent on first add) or an app password (requires 2FA). Either way the credential lands in Thunderbird's own store at runtime.
- **iCloud Mail** — `imap.mail.me.com:993` / `smtp.mail.me.com:587`; an **app-specific password is mandatory** (generated at appleid.apple.com — iCloud has no OAuth for third-party clients).
- **Custom-domain caveat** — `daniel@faris.co.nz` is a custom domain. Confirm at wire-up whether it is the Google Workspace ("Gmail") account or an iCloud-custom-domain mailbox, since that decides which auth path it uses.

**Polarity-follow depends on two switches.** Thunderbird must be on its "follow system" theme *and* Noctalia must be driving the `color-scheme` portal signal. If either is off, Thunderbird won't flip with the desktop. See [Theming](#theming).

## Open verifications (on-box pending)

- [ ] Thunderbird "follow system" theme actually flips polarity when Noctalia drives `color-scheme` on metis.
- [ ] Wayland-native session confirmed (Help → Troubleshooting Information → "Window Protocol" reads `wayland`), via Gecko auto-detection with no env var set.
- [ ] Gmail + iCloud accounts add successfully via the GUI (OAuth2 consent / app-specific password).
- [ ] Confirm `daniel@faris.co.nz` account type (Workspace vs iCloud-custom-domain).

## References

- [`home/nixos/thunderbird.nix`](../../home/nixos/thunderbird.nix) — the HM module enabling Thunderbird.
- [`home/nixos/bundles/desktop-env.nix`](../../home/nixos/bundles/desktop-env.nix) — bundle import.
- [firefox.md](./firefox.md) — the resident Gecko browser; shares the toolkit and the Wayland auto-detection path.
- [noctalia.md](./noctalia.md) §Theming — the built-in-template list that confirms no Thunderbird template; the engine Thunderbird's polarity follows.
- [microsoft-365.md](./microsoft-365.md) — why work mail is not in scope here (stays on mac-mini).
- Thunderbird upstream — https://www.thunderbird.net
- HM Thunderbird module — `programs.thunderbird` options reference at https://nix-community.github.io/home-manager/options.xhtml
- #388 — the selection issue this doc consolidates.
