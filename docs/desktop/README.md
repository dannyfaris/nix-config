# Desktop environment selections

Living documents for the operator's desktop tools — primarily the
Wayland desktop environment on metis (and any future Linux desktop
host), and also the per-tool selections on macOS clients (mac-mini
and any future Mac) where a tool is the operator's daily-driver
GUI for that platform. Each per-tool document captures a selection,
the rationale, alternatives considered, configuration choices,
sharp edges, and references.

The per-tool doc shape transfers cleanly across the platform line:
selections that span Linux desktop and macOS (e.g., a terminal where
one variant ships on each side, or a cross-platform GUI app like
Tailscale) land here as a single doc covering both platforms.

This directory complements `docs/decisions/` (Architecture Decision
Records). Where ADRs record *decisions at a moment in time* (immutable
except for §History amendments), the documents here are *living
selections + rationale*: they update as the desktop evolves. A new
binding, a new font, a new sharp edge — those amend the doc in-place
rather than creating a new artifact.

## Index

### Linux desktop (metis)

| Doc | Subject | Landed |
|---|---|---|
| [keybinds.md](./keybinds.md) | Niri keybindings + three-namespace philosophy | #80 |
| [fonts.md](./fonts.md) | Stylix-driven font selections + two-wires install model | #81 + #82 |
| [niri.md](./niri.md) | Niri compositor selection rationale | #71 |
| [foot.md](./foot.md) | Foot terminal selection (Linux); Ghostty retained on macOS clients | #72 |
| [fuzzel.md](./fuzzel.md) | Fuzzel application launcher (Mod+Space) | #73 |
| [fnott.md](./fnott.md) | Fnott notification daemon (third dnkl-family member) | #74 |
| [waybar.md](./waybar.md) | Waybar status bar (top of screen; tray + workspaces + clock + network) | #75 |
| [firefox.md](./firefox.md) | Firefox browser (Gecko engine; native Wayland; default URL handler) | #76 |
| [gnome-keyring.md](./gnome-keyring.md) | Secret Service / keyring for desktop app credentials (PAM auto-unlock) | #104 |

### macOS clients (mac-mini)

| Doc | Subject | Landed |
|---|---|---|
| [ghostty.md](./ghostty.md) | Ghostty terminal (Mac-only; GPU-accelerated); nix-homebrew cask | #13 |
| [slack.md](./slack.md) | Slack chat client (work daily-driver); MAS via `homebrew.masApps` — first managed MAS app | _pending_ |
| [chrome.md](./chrome.md) | Google Chrome (daily-driver browser); Homebrew cask + silent-via-Keystone | _pending_ |
| [microsoft-365.md](./microsoft-365.md) | Microsoft 365 — Word, Excel, PowerPoint, Outlook, Teams; MAS via `homebrew.masApps` | _pending_ |
| [amphetamine.md](./amphetamine.md) | Amphetamine keep-awake utility; MAS via `homebrew.masApps` (MAS-only distribution) | _pending_ |
| [typora.md](./typora.md) | Typora markdown editor; Homebrew cask + Sparkle silent (clause-2 carve-out) | _pending_ |
| [obsidian.md](./obsidian.md) | Obsidian PKM / notes; Homebrew cask + in-app updater (clause-2 carve-out) | _pending_ |
| [cursor.md](./cursor.md) | Cursor IDE Darwin install-path only (IDE-selection rationale stays in module head per "Deliberate no-doc"); Homebrew cask + ToDesktop updater (clause-2 carve-out) | _pending_ |
| [colima.md](./colima.md) | colima container runtime (CLI/daemon — not a GUI tool); nixpkgs clause-1 default. Deeper decision in ADR-021. | _pending_ |

### Cross-platform (NixOS desktop + macOS)

| Doc | Subject | Landed |
|---|---|---|
| [tailscale.md](./tailscale.md) | Tailscale mesh-VPN (NixOS service + macOS cask) | #13 |
| [1password.md](./1password.md) | 1Password password manager (macOS cask today; NixOS desktop adoption tracked separately) | #13 |

**Deliberate no-doc:** #77 (Cursor IDE) landed without a per-tool
selection doc — Cursor is a foregone install across all the
operator's hosts, not a selection weighed against alternatives.
Rationale + Wayland-enablement notes live in the module head
comments at [`home/nixos/cursor-ide.nix`](../../home/nixos/cursor-ide.nix)
and [`modules/nixos/electron-wayland.nix`](../../modules/nixos/electron-wayland.nix).
This is the documented exception to the §"Doc precedes
implementation" rule in [workflow.md](../workflow.md): it
applies to *selections*, not to foregone installs where no
alternative was weighed.

The Darwin install-path selection (cask vs. `pkgs.code-cursor`)
*is* an ADR-031 selection-with-alternatives at a different
layer, and it lives in [`cursor.md`](./cursor.md) — narrowly
scoped to the install-path question, with the IDE-selection
question explicitly out of scope. The "no-doc" precedent for
IDE-vs-IDE remains intact.

## Document structure

Two shapes have emerged so far:

**Per-tool selection docs** (e.g., `niri.md`, `foot.md`):

- **Selection** — what we chose, in one line.
- **Rationale** — why this over the alternatives.
- **Alternatives considered** — short, each with the reason it was passed over.
- **Configuration** — key choices made and where they live in the code.
- **Sharp edges** — known gotchas, version skews, things to revisit.
- **References** — ADRs, GitHub issues, upstream docs.

**Cross-cutting docs** (e.g., `keybinds.md`, `fonts.md`) don't fit the
per-tool shape because they span tools. They're structured around the
topic — for keybinds, that's modifier-namespace philosophy + bind
tables; for fonts, that's selections + installation model + sharp edges.

Both shapes share:
- Lead with selections/decisions, not background.
- Honest sharp-edges section with rationale.
- See-also or References at the end with cross-links.

## Conventions for evolution

**Doc precedes implementation.** Every selection (tool, font,
application, bind) lands its rationale here BEFORE the implementing
commit. The doc captures *why* at the moment of decision; future
readers follow the trail from doc → implementation.

**Commit-count cadence per PR:**
- Doc-only changes: 1 commit.
- Selection landing with implementation: 2 commits (doc, then code).
- Selection landing with a keybind: 3 commits (doc, code, bind manifest update).

The doc commit is always first regardless of count.

**Living documents — small, regular updates.** Add one bind / font /
configuration toggle at a time. Don't batch up large doc-rewrites — a
small targeted addition is easier to review than multi-week accretion.

**No silent additions.** If the codebase has a binding/font/tool not
represented in the relevant doc here, that's a cadence bug — fix the
doc.

## ADR or `docs/desktop/`?

Both kinds of artifact live in `docs/`. They serve different purposes:

- **ADR** — load-bearing project-level decisions with explicit
  consequences and migration triggers. Immutable historical record.
  Example: "DMS retracted; niri-only direction"
  ([ADR-029](../decisions/ADR-029-niri-only-desktop.md)).
- **`docs/desktop/`** — selection-level decisions for the desktop env.
  Living, updateable. Example: "niri's scrollable-tiling over
  sway/river/Hyprland" (see [niri.md](./niri.md)).

When in doubt, ADR for direction-shaping decisions; `docs/desktop/`
for tool-level selections. Cross-link freely between them.

## See also

- [`docs/decisions/`](../decisions/) — Architecture Decision Records
  (the immutable history). ADR-028 + ADR-029 frame the desktop's
  overall posture.
- [`docs/README.md`](../README.md) — top-level reference-documentation
  entry point.
- [`CLAUDE.md`](../../CLAUDE.md) — the AI-entry-point; the desktop-env
  section references this directory's documents.
