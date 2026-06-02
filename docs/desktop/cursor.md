# Cursor IDE — Darwin install path

**Scope note.** Cursor-vs-alternatives (Helix, VSCode, Zed, etc.)
is settled and lives in the module head comments at
[`home/nixos/cursor-ide.nix`](../../home/nixos/cursor-ide.nix)
per the [README §"Deliberate no-doc"](./README.md#index)
exception — Cursor is a foregone install across all the
operator's hosts, not a selection weighed against alternatives.
**This doc covers only the Darwin install-path selection under
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)** —
cask vs. `pkgs.code-cursor`. The IDE-selection question is not
re-litigated here.

Picked because it's the IDE the operator uses at work; the
IDE-selection rationale itself is the foregone-install case
recorded upstairs.

## Selection

Darwin: Homebrew cask `cursor`, declared in
`modules/darwin/homebrew.nix` per ADR-031's **clause 2** (this
doc owns the carve-out — see Rationale).

Update stance: **silent via Cursor's built-in ToDesktop
auto-updater**. No `CustomUserPreferences` keys (Cursor doesn't
use Sparkle). Suppression fallback is an in-app toggle, not a
`defaults` key — see §Update behaviour. Same shape as
[obsidian.md](./obsidian.md).

## Rationale

**MAS unavailable.** Cursor ships only via direct-download
`.dmg` from cursor.com; there is no Mac App Store listing.
Rejected at ADR-031 Step 0; clause 3 cannot apply.

**Clause-2 carve-out, framed operationally.** `pkgs.code-cursor`
is available on `aarch64-darwin` (`meta.platforms` covers all
four primary platforms, `meta.broken = false`, `src.url` is the
official `Cursor-darwin-arm64.dmg`). The binaries converge.

The cask is chosen because the nixpkgs Darwin derivation has a
named, load-bearing degradation:

- **Named integration:** Cursor's auto-updater is **ToDesktop's
  Electron-based auto-update path** (Cursor is distributed via
  the ToDesktop platform; the cask's livecheck queries
  `api2.cursor.sh/updates/api/update/darwin-<arch>/cursor/...`
  directly). It downloads release packages and replaces
  `/Applications/Cursor.app` in place on its own cadence.
  Silent point-release updates are how Cursor ships features
  and AI-model-side updates between flake bumps — a load-bearing
  channel for an actively-developed IDE.
- **Named degradation:** `pkgs.code-cursor` on Darwin installs
  the `.app` under the Nix store —
  `installPhase = "mkdir -p \"$out/Applications/Cursor.app\" \"$out/bin\" && cp -r ./* \"$out/Applications/Cursor.app\""`,
  so the bundle lives at
  `/nix/store/...-cursor-X.Y.Z/Applications/Cursor.app`. Nix
  store paths are immutable; ToDesktop's auto-updater cannot
  replace the bundle. The derivation does not pre-disable the
  updater, so update attempts at runtime either fail silently or
  surface error/toast notifications inside the IDE. Effective
  update cadence collapses to `nix flake update` + `nh darwin
  switch` — operator-cadence on a tool whose Anysphere-side
  features ship multiple times per week.
- **Named verification path:** if a contributor wants to flip
  to `pkgs.code-cursor`, verify: (1) Cursor's ToDesktop updater
  can be cleanly disabled (no toast spam, no in-IDE banners)
  when the bundle is immutable, (2) operator-cadence flake
  bumps land Cursor updates often enough to keep up with
  Anysphere's release cadence. If both pass, clause 2's
  degradation premise dissolves and ADR-031 Migration trigger 1
  applies.

The nixpkgs derivation does expose a `cursor` CLI wrapper at
`$out/bin/cursor` (a symlink to the bundle-internal launcher),
which the cask doesn't directly. The cask installs Cursor's
own "Install 'cursor' command" via the Cursor command-palette
(operator-side, one-time per machine) — same end-state, just
operator-initiated rather than declarative. Not load-bearing
for the install-path decision.

## Alternatives considered

**MAS** — not on MAS. Rejected at ADR-031 Step 0.

**`pkgs.code-cursor` on Darwin** — viable mechanism; carved out
on the operational grounds above (updater silently broken by
immutable nix-store path; release cadence vs. flake-bump cadence
mismatch on an actively-developed AI IDE). Worth revisiting if a
contributor lands a clean updater-disable path AND the operator
finds flake-bump cadence acceptable.

**Other IDEs** — settled out of scope; see scope note at the
top of this doc.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "cursor" ];
```

No `CustomUserPreferences` keys in the default configuration —
Cursor's updater is not Sparkle; the SU\* keys do not apply.
ToDesktop's update mechanism runs on its default cadence.

## Update behaviour

**Default (this config):** Cursor's ToDesktop auto-updater
runs on its default cadence, downloads release payloads, and
replaces `/Applications/Cursor.app` in place. No
`defaults`-domain key controls this — the toggle lives inside
Cursor at Settings → Application → Update Mode (options:
automatic / manual / disabled).

**Fallback if the auto-updater's `/Applications/` writes trigger
Mosyle admin-permission prompts:** set Cursor's in-IDE Update
Mode to `manual` (or `disabled`). **Adopting the fallback shifts
Cursor to operator-cadence updates via `brew update && brew
upgrade --cask --greedy cursor`** — the operator must remember
to run the brew command frequently enough to keep up with
Anysphere's release stream.

The toggle is stored in Cursor's per-user config under
`~/Library/Application Support/Cursor/`, not in a `defaults`-
domain plist. Same shape as Obsidian — no declarative
suppression path. Re-applying the suppression on a fresh Mac
would require re-toggling in-IDE on first launch.

## Sharp edges

**Suppression fallback is operator-side, not declarative.**
Same caveat as [obsidian.md](./obsidian.md): unlike Sparkle/MAU/
Keystone-shaped apps, there is no `system.defaults` key to flip.
Don't pretend otherwise; the in-IDE toggle is the mechanism.

**Bundle ID is a ToDesktop-generated string.** Cursor is built
on the ToDesktop platform; its bundle ID follows the pattern
`com.todesktop.<projectid>-<appname>` — the upstream Homebrew
cask uses a `com.todesktop.*` wildcard in its `zap` block rather
than pinning a specific ID. If a future operator needs the
exact ID for `defaults`-domain work, find it on the live host
with:

```bash
defaults domains | tr , '\n' | grep -i todesktop
# or: mdls -name kMDItemCFBundleIdentifier /Applications/Cursor.app
```

(No `defaults` work needed today — listed for completeness so a
future contributor doesn't waste time looking for a stable
documented ID.)

**Cursor ships fast.** Anysphere releases point updates multiple
times per week; lagging behind via flake-bump cadence is a real
feature-delivery cost. This is part of why the clause-2 carve-
out lands as it does — the cost-of-being-stale is higher for
Cursor than for, say, 1Password.

**Cursor's CLI is installed by user action, not the cask.**
Run the IDE command palette → "Shell Command: Install 'cursor'
command in PATH" to get `cursor` on the operator shell. The
cask doesn't pre-install this symlink. (The nixpkgs derivation
does provide one declaratively, which is a small clause-1-
favouring detail; not load-bearing.)

**Migration candidate to nixpkgs.** Per §Rationale's
verification path: if a contributor lands a clean updater-
disable path for `pkgs.code-cursor` on Darwin AND the operator
accepts flake-bump cadence on an AI IDE, the clause-2 carve-
out's premise weakens and ADR-031 Migration trigger 1 may fire.
Reconciling Cursor's release cadence with flake-bump cadence is
the harder half of that test.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing Cursor on the Mac via cask under
  clause 2; this doc owns the Darwin install-path carve-out
  justification only (the IDE-selection rationale lives in
  [`home/nixos/cursor-ide.nix`](../../home/nixos/cursor-ide.nix)
  per the README "Deliberate no-doc" precedent).
- Homebrew `cursor` cask source (JSON livecheck against
  `api2.cursor.sh`) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/c/cursor.rb
- ToDesktop (Cursor's app-distribution platform) — context for
  the `com.todesktop.*` bundle-ID pattern.
