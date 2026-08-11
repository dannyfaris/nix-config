# File manager — Thunar + gvfs

**Selection:** Thunar (Xfce's file manager, standalone) with gvfs virtual backends, tumbler thumbnails, and shared freedesktop trash with a declarative 30-day purge. Complement to yazi, not a replacement (#762).

## Premise

Yazi remains the terminal browse surface and keeps the removable-media safe-eject role ([removable-media.md](./removable-media.md)). This selection adds the capabilities a TUI structurally cannot provide: drag-and-drop into browser upload dialogs and GUI apps, thumbnail-grid visual browsing, and the virtual backends — phone (MTP), network shares (SMB/NFS), `trash://`. This is the revisit clause in removable-media.md §Alternatives firing: "gvfs earns its place only if phone/MTP or network shares become a need; revisit then." Both needs are now real.

Premise verified before designing (selecting-tooling step 0): the running closure carries zero gvfs, no GUI file manager, no thumbnailer — the gap is real, not a config oversight.

## Rationale

**The virtual-backend need is settled by gvfs, not by the file-manager pick.** Every maintained GTK-family candidate sits on the same gvfs/GIO daemon set; only Dolphin (KIO) differs. The nixpkgs gvfs default build already includes the MTP, SMB, NFS, and archive backends, and `services.gvfs.enable` wires D-Bus services, FUSE, and libmtp udev rules in one switch. The frontend tiebreakers are therefore outside-DE cleanliness, toolkit, theming, and NixOS wiring — and they all point the same way:

- **GTK3 = full theming fidelity for free.** Thunar rides the existing 34-key `@define-color` render (`gtk3-{dark,light}.css`, ADR-044) with real widget-theme coverage — unlike libadwaita surfaces, which consume only the named colours (the mechanism documented in [audio.md](./audio.md)). No new render target, no new Stylix target.
- **The only candidate with a first-class NixOS module.** `programs.thunar` (+ `plugins`) exists in the pin and auto-enables `programs.xfconf`; `services.tumbler.enable` covers thumbnails. Declarative reach without hand-rolled wiring — the criterion that has decided selections before (ADR-006's ENHANCE skip).
- **Reinforces the existing portal design.** `modules/nixos/xdg-portal.nix` deliberately routes the portal `FileChooser` to the gtk backend to avoid `xdg-desktop-portal-gnome`'s hard Nautilus dependency (niri#3765). A non-Nautilus pick keeps that rationale intact; Nautilus would rewrite it.
- **No indexer baggage.** Thunar's only outside-DE dependency is xfconf (D-Bus-spawned settings storage). Nautilus links `tinysparql` + `localsearch` and is a degraded, less-tested configuration without the miner running.
- **Measured marginal closure is modest.** Against the live alcyone closure: thunar 28 MiB + gvfs 112 MiB (samba is 85 of it) + tumbler 14 MiB + trash-cli 2 MiB ≈ 156 MiB, ~45 paths. Both GTK3 and GTK4 toolkit bases were already present (portal-gtk, mate-polkit, adw-gtk3, pwvucontrol).
- **Maintenance is healthy.** Active maintainer, Xfce 4.20 train (Dec 2024), Thunar runs Wayland-native since the libxfce4windowing work; pin carries 4.20.9. It is also the community-conventional pick for wlroots-family compositors.

Accepted costs: the xfconf dependency (Thunar preferences live in xfconf's runtime store, not declaratively pinned — accepted as app-internal state, same as other GUI apps here), and GTK3's long-horizon aging, already flagged as a multi-year concern in [polkit.md](./polkit.md).

## Alternatives considered

- **Nautilus (GNOME Files)** — the one serious rival: best polish, GNOME-core maintenance, historically the strongest drag-and-drop citizen. Passed over: libadwaita partial theming (colours follow, widget fidelity doesn't), the localsearch/tinysparql runtime dependency with documented instability when the miner is absent, and it inverts `xdg-portal.nix`'s deliberately non-Nautilus FileChooser routing.
- **Dolphin (KDE)** — KIO is a parallel backend universe to gvfs, largest marginal closure, re-imports the twice-evicted Qt stack, and has an open nixpkgs issue (#409986) where "Open with" is broken under non-Plasma WMs, niri named specifically. The "objectively best" folk wisdom does not survive this host's constraints.
- **PCManFM (GTK)** — effectively unmaintained (libfm's last real release 2021, lone caretaker release since). Fails the maintenance bar outright.
- **PCManFM-Qt (LXQt)** — the credible near-miss: actively maintained, cleanest outside-DE story (no settings daemon, no indexer), gvfs-backed. Passed over solely on toolkit: it would re-import a full Qt6 stack (removed twice from this desktop, most recently #644), resurrect `stylix.targets.qt`, and add a theme-menu render target — for a frontend no more capable than Thunar.
- **Nemo (Cinnamon)** — alive under Mint, but the project's testing culture is X11-first (Cinnamon Wayland support is years out); weakest Wayland provenance among the maintained GTK options.
- **Caja (MATE)** — no capability the others lack, slower cadence, older lineage. No reason to pick it.
- **COSMIC Files** — healthy upstream, but themes via cosmic-config rather than GTK/Qt — outside the theme-menu conductor's reach entirely.

## Trash

**Policy: trash-by-default on both surfaces, bounded by a declarative purge.** Yazi's stock keymap already follows the freedesktop Trash spec (`d` trashes, `D` deletes permanently) and Thunar's delete does the same, so both surfaces share one spec'd location (`~/.local/share/Trash`, per-volume `.Trash-1000/` on other filesystems) with interoperable restore metadata. With ADR-034's no-host-data-backup stance, trash is the only undo layer the fleet has — and a GUI makes accidental deletion (mis-drag, fumbled selection) more likely than a typed command ever did, so adding the GUI without the safety net would be the worst combination.

The bound: a systemd user timer runs `trash-empty -f 30` (trash-cli) daily — deleted files are recoverable for 30 days, then genuinely gone. No native module exists for this in NixOS or home-manager (verified in the locked sources); the hand-authored-unit-in-Nix pattern is the accepted shape here (polkit agent, noctalia units, ephemeral-root purge). GNOME's `remove-old-trash-files` gsetting was rejected as inert on this stack — it is enforced by gsd-housekeeping, which only runs inside a GNOME session (set ≠ enforced).

Ephemeral root does not interact: the boot rollback archives only the `@root` subvolume; `/home` — where the trash, xfconf state, and thumbnail cache all live — is untouched, so no persist-whitelist entry is needed.

## Configuration

- **System** (`modules/nixos/file-manager.nix`, in the system desktop-env bundle): `programs.thunar.enable` with `plugins = [ ]` — thunar-volman overlaps udiskie's automount role and the archive plugin needs an archive manager this config doesn't carry; each can earn its place later. `services.gvfs.enable` (default full-backend build from the binary cache — the deliberate whitelist act is enabling gvfs at all; trimming build flags would force source rebuilds of gvfs on every nixpkgs bump for marginal gain). `services.tumbler.enable` for thumbnails.
- **Home** (`home/nixos/file-manager.nix`, in the home desktop-env bundle): the daily trash purge timer (§Trash) + `trash-cli`; `xdg.mimeApps` registers Thunar for `inode/directory` only — the register-only-exercised-types discipline ([firefox.md](./firefox.md) precedent).
- **Keybind**: `Hyper+F` → Thunar, as one cross-platform capability with macOS's focus-or-launch Finder (the former `open-finder` entry folded in) — exact chord parity, in the bind registry per [keybinds.md](./keybinds.md) cadence (own commit). The chord was freed by an operator taxonomy call in this work: the window-geometry cluster (`F`/`M`/`C`/`R`/`−`/`=`) migrated from bare `Hyper` to `Hyper+Shift`, sharpening the principle to "bare Hyper navigates and launches; Shift acts on the window" — see keybinds.md §The organizing principle.
- **Icons + cursor**: a GUI file manager is the first surface where the unwired icon theme (#110) becomes visible, so that gap lands on this work's critical path — as its own selection, [pointer-icons.md](./pointer-icons.md).
- **SMB credentials**: deferred until an authenticated share exists; gnome-keyring + libsecret are already present, so the path is there when needed.

## Sharp edges

- **Drag-and-drop is gated on niri, not Thunar.** Open niri issues cover native-Wayland DnD (YaLTeR/niri#2446 — FM→browser drops failing; #3162 — missing drag icons), and Wayland→XWayland DnD doesn't work at all (Firefox runs native Wayland, so the critical path avoids it). Runtime probe required before this selection is called done.
- **gvfs mounts need the polkit agent.** mate-polkit's still-pending smoke test (polkit.md §Sharp edges) names exactly this trigger — mounting from a file manager discharges it.
- **home-manager #7143**: `dconf.enable` can clobber `GIO_EXTRA_MODULES` and silently break gvfs. This config enables dconf (GTK theming), so the interaction must be probed at activation.
- **Thunar settings are runtime state.** Preferences live in xfconf, imperative like other GUI-app state here; nothing is lost on reprovision beyond preferences.
- **samba is the closure bulk.** Most of gvfs's marginal closure (§Rationale) is the SMB client stack — the price of the network-shares requirement, not of Thunar.

## Verification (runtime, before done)

Per the set ≠ enforced rule, on a desktop host after activation: thunar launches themed (dark and light via `theme` switch, restart to pick up polarity); drag a file from Thunar into a Firefox upload dialog; trash a file in yazi → restore it in Thunar's `trash://`; trash on a USB stick → `.Trash-1000/` appears at the stick's root; connect a phone → MTP mount appears; mount an SMB share by `smb://` URI (auth prompt via mate-polkit — discharges the polkit smoke test); confirm the purge timer with `systemctl --user list-timers`.

## References

- [#762](https://github.com/dannyfaris/nix-config/issues/762) — intent + operator-confirmed decisions; [#110](https://github.com/dannyfaris/nix-config/issues/110) — pointer/icon cohesion (companion selection); [#105](https://github.com/dannyfaris/nix-config/issues/105) — removable media (amended by this work).
- [removable-media.md](./removable-media.md) — the yazi-side mount/eject surface this complements; [polkit.md](./polkit.md); [audio.md](./audio.md) — the GTK3-vs-libadwaita theming mechanism; ADR-006 (yazi's role), ADR-032, ADR-034 (trash interplay), ADR-044 (render-list obligation).
- Upstream: [YaLTeR/niri#2446](https://github.com/YaLTeR/niri/issues/2446), [YaLTeR/niri#3162](https://github.com/YaLTeR/niri/issues/3162), [nixpkgs#409986](https://github.com/NixOS/nixpkgs/issues/409986) (Dolphin), [home-manager#7143](https://github.com/nix-community/home-manager/issues/7143).
