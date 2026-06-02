# Obsidian

Knowledge-base / personal-notes app, vault model (each vault is
a directory of markdown files on disk). Picked because it's the
operator's existing notes/PKM tool and the vaults already live
on this Mac.

## Selection

Darwin: Homebrew cask `obsidian`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

Update stance: **silent via Obsidian's built-in updater** (an
Electron-style in-app path). No
`CustomUserPreferences` keys; suppression fallback is an in-app
toggle, not a `defaults` key — see §Update behaviour.

## Rationale

**MAS unavailable — vendor-disrecommended.** Obsidian's
developer has publicly stated they do not ship to MAS because
the sandbox restrictions on filesystem access would break vault
management — Obsidian needs free access to wherever the operator
stores their vault (often outside the standard sandboxed paths
like `~/Documents`). This is exactly the disqualifier ADR-031
clause 3 names ("vendor recommends against MAS distribution");
clause 3 fails on the named-disqualifier test.

**Clause-2 carve-out, framed operationally.** `pkgs.obsidian`
is available on `aarch64-darwin` (`meta.platforms` covers all
four primary platforms, `meta.broken = false`, `src` is the
official `Obsidian-X.Y.Z.dmg`). The binaries converge.

The cask is chosen because the nixpkgs Darwin derivation has a
named, load-bearing degradation:

- **Named integration:** Obsidian ships its own in-app updater
  (Obsidian is an Electron app; the observed download-`.zip`-
  and-replace behaviour is consistent with `electron-updater`'s
  macOS path, but Obsidian doesn't publish its updater
  internals so the specific library is inferred rather than
  confirmed). Either way the updater replaces
  `/Applications/Obsidian.app` in place. Silent point-release
  updates are the channel through which features, sync fixes,
  and plugin-API changes ship between flake bumps.
- **Named degradation:** `pkgs.obsidian` on Darwin installs the
  `.app` under the Nix store — `installPhase = "mkdir -p
  $out/{Applications/Obsidian.app,bin} && cp -R . $out/Applications/Obsidian.app"`,
  so the bundle lives at `/nix/store/...-obsidian-X.Y.Z/Applications/Obsidian.app`.
  Nix store paths are immutable; the in-app updater cannot
  replace the bundle. Obsidian's updater either fails at runtime
  or (more annoyingly) keeps surfacing "update available" toasts
  the operator cannot dismiss without disabling auto-update in
  Settings. Effective update cadence collapses to flake bumps.
- **Named verification path:** if a contributor wants to flip
  to `pkgs.obsidian`, verify: (1) Obsidian's in-app updater can
  be cleanly disabled (no toast spam) when the bundle is
  immutable, (2) operator-cadence flake bumps land Obsidian
  updates often enough — note that Obsidian's plugin ecosystem
  occasionally needs core-app updates for plugin API changes,
  which raises the cost of lagging. If both pass, clause 2's
  degradation premise dissolves and ADR-031 Migration trigger 1
  applies.

The nixpkgs derivation also exposes an `obsidian-cli` wrapper
under `$out/bin/`, which the cask does not. Useful if the
operator ever scripts vault operations from the command line —
worth noting, but not load-bearing (the same binary inside the
cask-installed bundle at `/Applications/Obsidian.app/Contents/MacOS/obsidian-cli`
is reachable with a one-line shell alias).

## Alternatives considered

**MAS** — not on MAS; vendor explicitly avoids it. Rejected at
ADR-031 Step 0.

**`pkgs.obsidian` on Darwin** — viable mechanism; carved out on
the operational grounds above (updater silently broken by
immutable nix-store path). Worth revisiting as a follow-up if a
contributor wants to verify the equivalence test in §Rationale.

**Other PKM/notes tools** (Apple Notes, Logseq, plain markdown
in Helix, Bear) — out of scope; the operator's existing vaults
and plugin set are the selection rationale.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "obsidian" ];
```

No `CustomUserPreferences` keys in the default configuration —
Obsidian's updater is not Sparkle; the SU\* keys do not apply.
Obsidian's own in-app updater runs on its default cadence.

## Update behaviour

**Default (this config):** Obsidian's electron-builder /
Squirrel.Mac-derived updater runs on its default cadence,
downloads release `.zip`s and replaces `/Applications/Obsidian.app`
in place. No `defaults`-domain key controls this — the toggle
lives in Obsidian's in-app Settings → About → "Automatic
updates".

**Fallback if the in-app updater's `/Applications/` writes
trigger Mosyle admin-permission prompts:** disable the in-app
toggle (Settings → About → Automatic updates: off). **Adopting
the fallback shifts Obsidian to operator-cadence updates via
`brew update && brew upgrade --cask --greedy obsidian`** — the
operator must remember to run the brew command periodically.

There is no `system.defaults.CustomUserPreferences` key for this
suppression — the toggle is stored in Obsidian's per-vault /
global config under `~/Library/Application Support/obsidian/`
in app-internal format, not in `~/Library/Preferences/md.obsidian.plist`.
This is a deliberate departure from Sparkle/MAU/Keystone-shaped
apps; do not try to wire a `system.defaults` key for it.

## Sharp edges

**Suppression fallback is operator-side, not declarative.**
Unlike Ghostty / Tailscale / Typora (Sparkle keys via
`CustomUserPreferences`) or Keystone / MAU (vendor `defaults`-
domain keys), Obsidian's update toggle is stored in app-internal
config. Re-applying the suppression on a fresh Mac would require
re-toggling in-app on first launch. Don't pretend otherwise.

**License is free for personal use; paid add-ons are separate.**
Obsidian itself is free for personal use; Obsidian Sync and
Obsidian Publish are subscription add-ons activated in-app. Not
a packaging concern — the cask installs the free binary; any
paid features sign in via account credentials at runtime.

**`auto_updates true` in the upstream cask is metadata, not
runtime behaviour.** The flag tells Homebrew "this cask self-
updates, don't manage version bumps". Runtime behaviour is
controlled by Obsidian's in-app toggle described above. Worth
remembering when scanning the cask source for clues about how
updates flow.

**Bundle ID is `md.obsidian`.** Verified against the upstream
cask's `zap` block. Useful for any future `defaults`-domain
work, though as noted there is no `defaults` key for the
auto-update toggle today.

**Migration candidate to nixpkgs.** Per §Rationale's
verification path: if a contributor lands a clean updater-disable
path for `pkgs.obsidian` on Darwin (no toast spam) AND the
operator's plugin set tolerates flake-cadence updates, the
clause-2 carve-out's premise weakens and ADR-031 Migration
trigger 1 may fire.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing Obsidian on the Mac via cask under
  clause 2; this doc owns the carve-out justification.
- Homebrew `obsidian` cask source (custom JSON livecheck against
  the obsidian-releases GitHub repo) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/o/obsidian.rb
