# Graphical authentication prompts (polkit agent)

The polkit authentication agent for the niri desktop on metis (#103) — the GUI that prompts for a password when a graphical app needs elevated privileges (mounting removable media in a file manager, a privileged settings change, a disk tool). This doc records a *swap*, not an addition: a graphical agent already runs, and this replaces it with a lighter, theme-cohesive one. The text-mode elevation path (`sudo`/`pkexec` in a terminal) is unaffected and out of scope.

## Premise correction

The issue framed this as "nothing surfaces a graphical authentication prompt." That is not the case: **niri-flake's nixosModule already runs the KDE agent** (`polkit-kde-authentication-agent-1`) via a `niri-flake-polkit` systemd user service, alongside the polkit daemon and gnome-keyring. Verified live on metis: the unit is active and the KDE agent is the process serving prompts. So #103 is really "keep niri-flake's KDE/Qt agent, or deliberately swap it" — and this doc swaps it.

## Selection

**mate-polkit** (GTK3, `polkit-mate-authentication-agent-1`), run as a hand-rolled `systemd.user.services` unit bound to `graphical-session.target`, replacing niri-flake's KDE agent (`systemd.user.services.niri-flake-polkit.enable = false`). Because the KDE agent being removed is the only thing on metis pulling the Qt/KDE stack, the now-vestigial **`stylix.targets.qt`** is dropped in the same change. (Activation is smoke-test-pending on metis — see Sharp edges.)

## Rationale

**Architecture, briefly.** polkit has two halves: the **daemon** (`polkitd`, system-wide, decides whether an action is authorised) and an **authentication agent** (per-session GUI that prompts for the password). The daemon is compositor-agnostic; the agent is the toolkit-specific, swappable, session-side piece. `security.polkit.enable` only runs the daemon — the agent is a separate systemd user service. niri does not spawn one itself; niri-flake supplies the KDE agent by default.

**The swap is justified on styling first, dependency-minimalism second — and both point the same way.**

*Styling (the primary driver).* The KDE agent is a KDE/Kirigami app, and KDE apps read their colours from `kdeglobals` (KColorScheme), **not** from the qt6ct/qt5ct/Kvantum theming that Stylix configures. metis has **no `kdeglobals`** (Stylix is not a Plasma setup and does not write one), so the prompt falls back to **stock Breeze** — an off-theme KDE window on an otherwise base16-cohesive desktop. This matches the documented "Plasma polkit will not respect the user's Qt theme" behaviour. (The off-theme rendering is *inferred* from the verified absence of `kdeglobals` plus that documented KDE behaviour — observed in the session config on metis, not captured as a screenshot here.) mate-polkit is plain GTK3 (no libadwaita), so it inherits the existing `stylix.targets.gtk` base16 theme like the file pickers and GTK chrome — the prompt looks like part of the desktop. On a finished desktop, the authentication dialog matching the surface is exactly the kind of detail that should be right.

*Dependency-minimalism (the corroborating driver).* The KDE agent is the **only Qt application on metis** — verified by walking the system closure: the sole Qt6 consumers are the agent plus the Stylix Qt-theming tools (qt6ct/Kvantum) whose entire purpose is to theme Qt apps, and Qt5's only consumer is qt5ct. So the whole Qt presence is circular: theming machinery that exists to theme one off-theme dialog. Swapping to a GTK agent leaves **zero** Qt apps, which makes `stylix.targets.qt` vestigial. Removing the agent's KDE-Frameworks layer **and** the now-pointless Qt target together trims a measured **573 MiB across 62 store paths** (measured on metis via `nix path-info` over the paths reachable only through the agent + the Qt-theming tools: the full Qt5 + Qt6 stacks, KDE Frameworks, Kvantum, qt6ct/qt5ct — biggest chunks qtdeclarative 176 MiB, qtbase 83, breeze-icons 67). This is a different figure from the `+585 MiB` gtk+qt-together number recorded in `stylix-targets-desktop.nix` (that gates *both* toolkits off on headless mercury; this is qt-only-plus-the-KDE-agent on metis) — they are not in conflict. mate-polkit reuses the GTK3 already present (waybar + adw-gtk3), so it adds back essentially nothing. This aligns with the repo's "tight-from-the-start, whitelist > blanket" posture: a whole toolkit stack kept for a single dialog is exactly what that posture exists to question.

**Why mate-polkit specifically.** Of the maintained GTK agents, mate-polkit is the conservative, institutionally-maintained choice: it rides the MATE release train (multiple maintainers, not a hobby repo — the right backing for a component on the privilege-escalation path), it is a contained GTK3 binary (runtime deps just `gtk3` + `polkit` + `gettext`), and it explicitly respects the GTK theme. It is the community's de-facto maintained replacement for the abandoned polkit-gnome.

## Alternatives considered

**Keep niri-flake's KDE agent (`polkit-kde`).** Zero-effort, niri's own documented default, actively maintained. Passed over: it renders off-theme (stock Breeze, no `kdeglobals`), and it is the sole reason the Qt/KDE stack (the 573 MiB measured above) sits on metis at all — to serve one dialog. The "it already works" case is real but weak against the styling + closure win.

**soteria** (Rust + GTK4). The most modern option — purpose-built to be stylable, plain GTK4 (no libadwaita), and it even ships a NixOS module (`security.soteria.enable`) upstreamed into nixpkgs. Passed over on **viability risk for a security component**: it is a young, overwhelmingly single-maintainer pre-1.0 project with a low user base, the maintainer disclaims the community-packaged installs, and its issue tracker shows recent (now-fixed) registration/start-up failures *in exactly the non-DE NixOS scenario this is* — the worst failure class for an auth agent. It also carries an `XDG_SESSION_ID` env-import footgun and a niri-specific GTK4 startup-timing theming race (a sleep workaround to pick up the colour-scheme). (Sourced from soteria's repo + issue tracker, 2025–2026.) Revisit after a 1.0 and a broader contributor base.

**polkit-gnome.** The historical GTK default. Abandoned/unmaintained for 12+ years; the niri maintainer explicitly recommends against it. Not considered.

**lxqt-policykit / hyprpolkitagent.** lxqt-policykit (Qt) offers no Stylix advantage over the KDE agent we already have, while pulling a bit of LXQt. hyprpolkitagent themes from Hyprland's own toolkit palette, outside Stylix entirely — wrong ecosystem for a Stylix desktop.

## Configuration

- `home/nixos/` — a small module wiring `systemd.user.services.<mate-polkit>`: `ExecStart` the `polkit-mate-authentication-agent-1` binary, `PartOf`/`After`/`WantedBy = graphical-session.target` (the standard agent-registration pattern; mirrors how the home-manager `services.polkit-gnome` module builds its unit, since there is no home-manager module for mate-polkit). Imported via the desktop-env home bundle.
- **Disable the KDE agent:** `systemd.user.services.niri-flake-polkit.enable = false` (the niri-flake-documented lever) so the two agents do not both register.
- **Drop the vestigial Qt target:** remove the `qt.enable` line from `home/nixos/stylix-targets-desktop.nix`, leaving the `gtk.enable` block — and the `gtk.gtk4.theme` line directly below it, which is gtk-coupled, not qt — untouched. This realises the bulk of the 573 MiB; Stylix's qt target also sets `QT_QPA_PLATFORMTHEME`/`QT_STYLE_OVERRIDE`, so dropping it removes that session env, which no longer has a consumer.

## Sharp edges

**Smoke-test on metis before trusting it (prerequisite).** The viability research found no first-party "mate-polkit on niri" success report — it is strong inference from "standalone GTK3 polkit binary with no MATE-session deps," not a cited result. So the first activation must be verified on the box: trigger a GUI elevation (e.g. mount removable media in a file manager, or `pkexec` a GUI program from within the niri session) and confirm the mate-polkit dialog **appears, is themed (base16, not Breeze), and actually authenticates**. A polkit agent that registers but fails to authorise would be the worst outcome; metis break-glass is the physical console, and terminal `sudo` is unaffected, so recovery is unimpeded — but verify before relying on it.

**Agent registration depends on the session environment.** The agent must register with `polkitd` for the logind session; this works because the unit is ordered after `graphical-session.target` and niri's session imports the environment. If the dialog never appears, an unregistered agent (missing session env) is the first thing to check — the generic version of the footgun that bites soteria harder.

**Dropping `qt.enable` means a future Qt app would render unthemed.** There are no Qt apps today, so the target is dead weight now; but if one is ever installed, re-adding `qt.enable` (one line) restores Qt theming. This is the deliberate whitelist trade: theme it when there is something to theme.

**GTK3 is a multi-year-horizon concern.** mate-polkit is GTK3, which is maintained and ubiquitous today but aging on a long horizon. Not a near-term issue; flagged so a future GTK4 reconsideration (soteria post-1.0, or a successor) has a recorded starting point.

**No home-manager module for mate-polkit.** Unlike `services.polkit-gnome`, the unit is hand-rolled. The `services.polkit-gnome` module is the canonical pattern to copy for the `graphical-session.target` wiring.

## References

- mate-polkit (mate-desktop) — GTK3 polkit agent, 1.28.1 (upstream / nixpkgs facts); runtime deps `gtk3` + `polkit` + `gettext`; respects the GTK theme.
- niri-flake README — the `niri-flake-polkit` service and the `systemd.user.services.niri-flake-polkit.enable = false` lever; niri "Important Software" wiki (agents are user-configured; KDE agent is the example).
- home-manager `services.polkit-gnome` — the canonical graphical-session.target agent-unit pattern to mirror.
- Verified on metis (this work): the KDE agent runs off-theme (no `kdeglobals`); the KDE agent is the only actual Qt *app* (qt6ct/qt5ct/Kvantum are theming tools); the combined agent + qt-target removal measures 573 MiB / 62 paths via `nix path-info`.
- soteria (ImVaskel) + nixpkgs `security.soteria` — the modern GTK4 alternative, passed over on viability; revisit post-1.0.
- [gnome-keyring.md](./gnome-keyring.md) — the Secret Service, independent of polkit (often conflated; both happen to be enabled by niri-flake).
- [screen-lock.md](./screen-lock.md) — the same minimal/native posture applied to another surface.
- ADR-028 (Stylix as surface source-of-truth), ADR-029 (niri-only desktop).
