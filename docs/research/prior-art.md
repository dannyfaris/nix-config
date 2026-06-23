# Prior-art survey — repos worth mining for the niri + Stylix + Noctalia desktop

Status: **research note, not a decision.** Captured from a deep-research run (5 angles, 22 fetched sources, 109 claims → 25 adversarially verified via 3-vote, 1 killed → 9 findings) on 2026-06-22, plus two repos reviewed directly in-session (osyx, s13los). Curates external configs worth pillaging for design, dotfiles, launcher strategy, live theme-switching, Stylix tricks, and cross-app visual consistency. Nothing here is adopted; each item is a pattern to evaluate against rendered reality and our own principles. Feeds [`visual-identity.md`](../desktop/visual-identity.md) (#108), the runtime-theming issues (#411/#413/#414), and the live-switch open question below.

## 1. Strategic verdict

**No single repo combines all four of our pillars (niri + Stylix + Noctalia + flake-parts).** The move is to *compose* from a small set of references, not adopt one wholesale. The deep-research run ground-truthed against our own [`home/nixos/noctalia-shell.nix`](../../home/nixos/noctalia-shell.nix) and confirmed we are already on the canonical Noctalia path (`programs.noctalia-shell`, the `legacy-v4` pin) — so the *base* is sound. The genuine open capabilities are **live (rebuild-free) palette switching** across the Stylix-pinned surfaces and a deliberate **launcher strategy**; everything else is refinement.

Maturity was assessed by recent commit *content* (feature work, not doc/CI bumps) and README, per [our liveness rule](../workflow.md). Calls are dated 2026-06-22 and will drift.

## 2. The shortlist

| Repo | What's notable | What to steal | Relevance / portability | Maturity |
|---|---|---|---|---|
| [louis-thevenet/nixos-config](https://github.com/louis-thevenet/nixos-config) | Stylix + **darkman → home-manager specialisation `activate`** scripts auto-switch the whole session light/dark at sunset with **no rebuild** at switch time; also reloads swaync CSS, restarts albert, `SIGUSR1`s helix. niri is a first-class option (`pkgs.niri-unstable`, matches our pin). | `stylix-specialisation.nix` (declares `specialisation.{light,dark}.configuration.stylix` with polarity + `base16Scheme`) and `darkman.nix`'s switch-script that runs `$(find-hm-generation)/<theme>/activate` directly. | **The standout for our biggest gap.** Most Nix-native live-switch pattern found. *Caveat:* Hyprland-primary, niri secondary; HM-level (not NixOS-level) specialisations; themes per-app (waybar/mako/swaync) more than via broad Stylix targets. | Active (feature commits) |
| [ctknightdev/nixos](https://github.com/ctknightdev/nixos) | Active niri + Noctalia HM flake; niri config decomposed into per-concern modules under `home/niri/`: `applications.nix`, `autostart.nix`, `keybinds.nix`, `noctaliashell.nix`, `rules.nix`, `scripts.nix`, `settings.nix`. | The **module-decomposition layout** — maps cleanly onto our foundation+bundles model. `noctaliashell.nix` shows `imports = [ inputs.noctalia.homeModules.default ]` + declarative `programs.noctalia-shell.settings`. | Closest architectural analogue, directly portable as structure. *Caveat:* themes via **Catppuccin, not Stylix** — the theming layer does **not** transfer. | Active |
| [sodiboo/niri-flake](https://github.com/sodiboo/niri-flake) | The infra we already build on: `niri-stable`/`niri-unstable` packages, overlay, NixOS/HM modules, typed `programs.niri.settings` (schema-validated to the installed niri), and a **Stylix target** (`stylix.targets.niri`) that sets active/inactive border colours + xcursor and defaults `layout.border` on. | Re-read the Stylix-border + cursor integration — it intersects our runtime border→Noctalia handoff (ADR-036). | Foundational; already in use. | Active (upstream) |
| [Atemo-C/NixOS-configuration](https://github.com/Atemo-C/NixOS-configuration) | **Most complete real-world niri + Noctalia**: Noctalia as a full replacement for separate bar/launcher/notifications; committed `settings.json`/`plugins.json` (calculator, polkit-agent, privacy-indicator); `desktop/niri.nix` sets `noctalia-shell.enable` + symlinks Noctalia config. | The end-to-end *wiring* of Noctalia-as-everything, and the committed Noctalia settings/plugins as a reference config. | High-value pattern source. *Caveat:* **no flakes, no home-manager** — hand-port only. | Very active |
| [SceAce/niri-dotfiles](https://github.com/SceAce/niri-dotfiles) (non-Nix) | **Split-KDL niri config** via `include` (`animations/binds/colors/input/layout/output/rule.kdl`); a **matugen cache pipeline** (`hyprlock.conf` line 2: `source = ~/.cache/matugen/hypr/colors.conf`). Vendors Noctalia. | The split-config composition idea and the matugen-cache-as-runtime-palette pattern (pywal-style). | Pattern mine only. *Caveat:* young, 0 stars, no license; matugen "no rebuild" = per-process-start re-read. Our Nix world prefers specialisation-activate or Quickshell-IPC over a pywal cache. | Young/thin |
| [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS) | Mature DMS alternative to Noctalia: hybrid QML/Go Quickshell shell, drop-in **NixOS + HM flake module** (`inputs.dms.homeModules.dank-material-shell`), in nixpkgs 26.05. Live theme/wallpaper switching via `dms ipc call wallpaper set` → matugen regenerates GTK/Qt/editor templates in place. | Study its **IPC-driven live theming** and template-regeneration model as a counterpoint to Noctalia. | Counterpoint, not a switch. *Caveat:* **not Stylix/base16** (the "base16 alternative" framing was the run's one *refuted* claim); terminals still need a restart to re-read palettes. Consume via the AvengeMedia flake module, **not** the `danklinux` installer (NixOS unsupported there). | Active |
| [eduardofuncao/nixferatu](https://github.com/eduardofuncao/nixferatu) | Exact stack match: niri + Stylix + fish, NixOS flakes; `stylix.nix` drives `base16Scheme` from `pkgs.base16-schemes` with selectable tinted-theming schemes. | A small `base16Scheme`-selection pattern only. | Confirms our exact pattern. *Caveat:* **dormant** (~5 commits, ~8 months stale) and thin — not a refined reference. | Dormant |

Infra/reference (not user configs, but the engine for "clever Stylix"): [SenchoPens/base16.nix](https://github.com/SenchoPens/base16.nix) (the base16 engine under Stylix — for custom targets / slot discipline) and the [Stylix module docs](https://nix-community.github.io/stylix/modules.html).

Appeared in source-gathering but **did not survive verification into a finding** — treat as unvetted leads, not recommendations: [donovanglover/nix-config](https://github.com/donovanglover/nix-config), [RanXom/niri-dots](https://github.com/RanXom/niri-dots), [n70n10/nixfiles](https://github.com/n70n10/nixfiles), [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config).

## 3. Theme cross-cuts

**Live switching — three distinct routes surfaced:**

1. **darkman + HM-specialisation-`activate`** (louis-thevenet) — pre-build both palettes as specialisations, then run the target's activate script directly; no rebuild at switch time. Most Nix-native; the directly-portable answer to our live-switch gap.
2. **Quickshell-native IPC** (Noctalia `colorSchemes`/IPC; DMS `dms ipc call`) — runtime recolour within the shell. Our existing niri-border→Noctalia handoff (ADR-036) is essentially this route already; the open question is whether Stylix's base16 palette can be *pushed into* Noctalia's `colorSchemes` at runtime.
3. **matugen cache + per-process `source`** (SceAce) — pywal-style; least suited to our declarative model.

**Launcher strategy — honest gap.** The comparative launcher analysis (fuzzel/wofi/rofi/anyrun vs Quickshell-native) **did not survive verification**; only Noctalia's IPC-toggled launcher (`Mod+Space`) and DMS's spotlight were concretely documented. If launcher strategy matters, it needs a focused follow-up run.

**Cross-app visual consistency under Stylix specifically — weaker than hoped.** No clear "most seamless Stylix-driven cross-app" winner emerged; even louis-thevenet themes via per-app configs (waybar/mako/swaync) rather than broad Stylix targets. Our own fontconfig-as-conductor + theme-tokens approach may already be ahead of the surveyed field on this axis.

## 4. Two configs reviewed directly in-session

- **[rccyx/osyx](https://github.com/rccyx/osyx)** (non-Nix, Debian) — the standout idea is its **`flavors` runtime theming engine**: a palette TOML rendered through per-tool Jinja templates, cycled at runtime by writing a trigger file and `SIGUSR1`-ing every idle interactive shell (which re-runs `dircolors` + `zle reset-prompt`). The compositor-agnostic **signal→idle-shell→repaint** trick is the transferable part for our shell/TUI surfaces — the same mechanism louis-thevenet uses for helix. Most of osyx's other machinery (imperative apt provisioning, hand-rolled state files, prose-pinned Hyprland) is what Nix already deletes for us.
- **[JotaFab/s13los](https://github.com/JotaFab/s13los)** (NixOS) — a **maturity counterexample**: blanket `allowUnfree`, one giant flat `systemPackages` with duplicates, mutable users + unhardened sshd, niri as a stock 514-line static `config.kdl`. Validates our stances by inversion. Two genuinely useful takeaways: `programs.nix-ld.enable` (foreign-binary escape hatch for work tooling) and the gitignored-conditional-import idiom (`if pathExists ./hosts.nix then import … else {}`) — though s13los commits the file it claims is gitignored.

## 5. Open questions

- Can Stylix's base16 palette be pushed into Noctalia's `colorSchemes` at runtime (mirroring our niri-border handoff), versus the darkman + HM-specialisation-`activate` route — and which is the cleaner Nix-native live-switch for the Stylix-pinned surfaces (foot/TUI/Firefox/GTK)? (Ties to #411.)
- Launcher comparison for a scrollable-tiling niri workflow (Noctalia built-in vs DMS spotlight vs fuzzel/anyrun) — unaddressed by the verified evidence; needs its own pass.
- Which surfaced repo, if any, achieves the most seamless *Stylix-driven* cross-app cohesion — only partially answered.

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)). Update it as repos move or new references surface.
