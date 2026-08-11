# Pointer & icon theme — Colloid + phinger

**Selection:** Colloid icon theme (polarity pair `Colloid`/`Colloid-Dark`) via `stylix.icons`, and phinger cursors (`phinger-cursors-light`, static across polarity) via `stylix.cursor` + niri's `cursor` block. Discharges #110, on #762's critical path — a GUI file manager is the first surface where the unwired icon theme is visible (folder/MIME icons).

## Rationale

**The field was measured, and the measurements disqualified the canon.** The popular picks all fail this repo's own bars in nixpkgs packaging: Papirus, Tela, Kora, and Reversal propagate `breeze-icons`, whose library links **qtbase 6** — re-importing the Qt stack this desktop has evicted twice (#103, #644) — at ~1 GiB closures; Nordzy is a 445 MiB all-variants NAR; Bibata cursors 322 MiB, Nordzy cursors 846 MiB; Yaru (the Omarchy benchmark) was removed from nixpkgs outright. Every number here is marginal closure against the live alcyone system, computed by path set-math.

**Colloid** (39 MiB marginal, Qt-clean, GTK-complete: apps + folders + MIME + symbolic) is the current-generation pick from the Tela author, actively maintained. It won on mechanism as much as aesthetics: the 2025–26 scene treats icon sets as recolorable substrates for generated palettes, and Colloid's nixpkgs package uniquely exposes declarative `schemeVariants` (catppuccin/gruvbox/everforest/nord/dracula) and `colorVariants` (8 folder accents) via `.override` — the packaged approximation of a base16-aware icon set. This is precisely the shape Omarchy uses (verified in-tree: each theme pins a Yaru *accent variant* — `Yaru-purple`/`-olive`/`-sage`), done declaratively instead of via a gsettings side-file. Day 1 ships the default variant (blue folder accent ≈ the base0D focus role in [visual-identity.md](./visual-identity.md)); per-family scheme variants are a recorded follow-up, not day-1 scope.

**phinger cursors** (51 MiB, no deps) is the modern minimal scene default; upstream is finished-not-dead (Ubuntu still packages it). The light (white) variant is pinned *statically*: a white-with-border pointer is legible over both polarities and over arbitrary content (the reason it is every OS default), and a static pick means the cursor — unlike colour surfaces — is deliberately exempt from the runtime polarity flip, avoiding a stale-cursor sharp edge entirely. Omarchy parity was checked and debunked as a criterion: Omarchy pins **no** cursor theme (only `XCURSOR_SIZE 24`; stock Adwaita) — there was no alignment to mirror.

## Alternatives considered

- **Adwaita + MoreWaita** — the minimal-GNOME wing's convergence: symbolic-first, auto-tinted by GTK, fully palette-neutral, and Adwaita is already in the closure (0 MiB). The genuine runner-up; passed over for Colloid's fuller colour presence and accent-variant mechanism, which better matches the operator's stated modern-rice intent.
- **Fluent** (33 MiB, clean) — the end-4/illogical-impulse set; a louder Windows-11 aesthetic that didn't fit the visual-identity direction.
- **Papirus / Tela / Kora / Reversal** — the breeze→Qt6 contamination above. Tela remains the Hyprland-distro default; not at that price here.
- **Custom base16 recolor derivation** (Adwaita-colors-style sed-over-SVG fed by the palette) — the most distinctive truly-generated option; deferred as bespoke machinery this selection doesn't need day 1.
- **Cursors: Bibata and Nordzy** (disqualified on the sizes above; Bibata also dormant), **catppuccin** (11 MiB/variant but palette-locked), **google-cursor** (96 MiB), **vimix/volantes** (tiny but upstream dead), **Adwaita** (0 MiB, the no-decision default), **anything hyprcursor-only** (Hyprland format; useless on niri).

## Configuration

`home/nixos/pointer-icons.nix`, imported by the home desktop-env bundle: `stylix.icons` (enable/package/light/dark — Stylix resolves the name by build-time polarity into `gtk.iconTheme`) and `stylix.cursor` (name/package/size → `home.pointerCursor` with GTK + X11 wiring), plus `programs.niri.settings.cursor` referencing the same values so the compositor layer and the toolkit layer cannot drift. Both option shapes verified in the pinned stylix and niri-flake sources.

## Sharp edges

- **Icons follow build-time polarity, not the runtime flip.** The theme-menu conductor (ADR-044) switches polarity live, but `gtk.iconTheme` is baked at build — after a runtime flip, icons keep the built variant until rebuild/re-login. Consequence of ADR-044's "new colour-consuming surfaces must join the render list"; adding an icon-theme swap to the per-entry render list (and per-family Colloid scheme variants with it) is the recorded follow-up. The cursor is exempt by design (static variant).
- **Colloid's `index.theme` declares `Inherits=hicolor,breeze`.** breeze is deliberately absent; missing icons fall through the normal fallback chain (hicolor → Adwaita). Harmless, noted so nobody "fixes" it by installing breeze.
- **First icon-theme change may need app restarts** to repopulate GTK icon caches.

## References

- [#110](https://github.com/dannyfaris/nix-config/issues/110) — the issue this discharges (its niri focus-ring half was already discharged by ADR-044's theme-menu); [#762](https://github.com/dannyfaris/nix-config/issues/762) — the file-manager work that put it on the critical path.
- [file-manager.md](./file-manager.md) — the surface that made the gap visible; [visual-identity.md](./visual-identity.md) — accent roles; ADR-044 — render-list obligation.
- Upstream: [Colloid](https://github.com/vinceliuice/Colloid-icon-theme), [phinger-cursors](https://github.com/phisch/phinger-cursors), [Omarchy's per-theme icon mechanism](https://github.com/basecamp/omarchy) (`themes/*/icons.theme`).
