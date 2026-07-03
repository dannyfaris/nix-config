# Fellow

Collaborative meeting agendas, notes, and action items. Picked
because it's the operator's workplace meeting-management tool —
shared agendas, post-meeting notes, action-item tracking flow
through Fellow alongside the Microsoft 365 calendar surface.

## Selection

Darwin: Homebrew cask `fellow`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 1** (no nixpkgs equivalent on Darwin).

Update stance: **silent via Fellow's Electron-style in-app
updater**. No `CustomUserPreferences` keys — the updater is not
Sparkle. Suppression fallback is an in-app toggle, not a
`defaults` key — same shape as Cursor, Obsidian, and Claude
desktop.

## Rationale

**Clause-1 carve-out, no comparison to weigh.** Fellow
distributes only as a direct `.dmg` from
`cdn.fellow.app/desktop/...`. No Mac App Store listing exists
(verified — Fellow's own download page lists no MAS link). The
package is not in nixpkgs on `aarch64-darwin`. Clauses 2 and 3
have nothing to evaluate.

## Alternatives considered

**MAS** — no listing. Rejected at ADR-031 Step 0.

**nixpkgs** — no Darwin package (verified via `nix eval`).
Rejected at Step 1.

**Web client at fellow.app in Chrome** — works, and the operator
has Chrome. Functional fallback; not a daily-driver substitute
for the in-meeting agenda surface where dock presence and
keyboard-shortcut access matter.

**Slack/Teams Fellow integrations** — complementary, not
substitutes. Fellow's Slack and Teams plugins surface notes in
the chat apps but don't replace the desktop client for agenda
editing.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "fellow" ];
```

No `CustomUserPreferences` keys in the default configuration —
the updater is not Sparkle; the SU\* keys do not apply.

## Update behaviour

**Default (this config):** Fellow's Electron-style in-app
updater runs on its default cadence. The cask's livecheck uses a
`header_match` strategy against
`fellow.app/desktop/download/darwin/latest/` for Homebrew's
bookkeeping; the runtime updater inside the app handles
self-updates by replacing `/Applications/Fellow.app` in place.

**Fallback if the auto-updater's `/Applications/` writes trigger
Mosyle admin-permission prompts:** disable the in-app auto-
update toggle (settings menu inside the app; exact path may
shift across versions). **Adopting the fallback shifts Fellow to
operator-cadence updates** via
`brew update && brew upgrade --cask --greedy fellow`. There is
no `system.defaults.CustomUserPreferences` key for this — the
toggle is stored in Fellow's per-user config under
`~/Library/Application Support/Fellow/`, not in a `defaults`-
domain plist.

## Sharp edges

**Suppression fallback is operator-side, not declarative.** Same
caveat as [obsidian.md](./obsidian.md),
[cursor.md](./cursor.md), and
[claude-desktop.md](./claude-desktop.md): unlike Sparkle / MAU /
Keystone apps, there is no `system.defaults` key to flip.
Re-applying the suppression on a fresh Mac would require
re-toggling in-app on first launch.

**Bundle ID is `com.electron.fellow`** (the `com.electron.*`
prefix is a generic Electron-app default — Fellow's developers
didn't rebrand their bundle ID). Verified against the upstream
cask's `zap` block (`~/Library/Preferences/com.electron.fellow.plist`).

**macOS Ventura or later required.** The cask declares
`depends_on macos: :ventura`. neptune's Sequoia install meets
this comfortably.

**Migration candidate to nixpkgs.** Not viable today — there is
no `pkgs.fellow` for Darwin. If a future packaging lands, the
install-path question reopens; the existing Electron-in-store
clause-2 shape (Obsidian, Cursor, Claude desktop) would
probably apply, with the in-app updater fighting the immutable
store path.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  clause 1: no Darwin nixpkgs equivalent.
- Homebrew `fellow` cask source (header_match livecheck against
  Fellow's download endpoint) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/f/fellow.rb
- Fellow's MCP integration (claude.ai Fellow.ai connector) is
  used in this conversational context; this doc covers only the
  desktop client install path.
