# Claude desktop

Anthropic's native macOS Claude client. Picked because it's the
operator's daily-driver AI assistant alongside the Claude
agentic CLI on every host (`agent-clis.nix`); the desktop app
covers UI-driven workflows that the CLI doesn't.

## Selection

Darwin: Homebrew cask `claude`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 1** (no nixpkgs equivalent on Darwin).

Update stance: **silent via Anthropic's custom in-app updater**.
No `CustomUserPreferences` keys — the updater is not Sparkle
(no SU\* keys to wire). Suppression fallback is an in-app toggle,
not a `defaults` key — same shape as Cursor and Obsidian.

## Rationale

**Clause-1 carve-out, no comparison to weigh.** Anthropic
distributes Claude desktop only as a direct `.dmg` from
`downloads.claude.ai`. No Mac App Store listing exists. The
package is not in nixpkgs on `aarch64-darwin`. Clauses 2 and 3
have nothing to evaluate. Cask is the only managed install path
available, which is what clause 1 covers.

## Alternatives considered

**MAS** — no listing. Rejected at ADR-031 Step 0.

**nixpkgs** — no package on Darwin (verified via `nix eval`).
Rejected at Step 1.

**Web client at claude.ai in Chrome** — works, and the operator
has Chrome. Functional fallback if the desktop app is ever
unavailable; not a daily-driver substitute when the desktop's
window management, Cmd-Tab presence, and OS-integration affordances
matter.

**Agentic CLI** — `claude` from `home/shared/agent-clis.nix` is
already on every host; covers a different workflow (terminal-
driven coding assistance). Complementary to the desktop app,
not a substitute.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "claude" ];
```

No `CustomUserPreferences` keys in the default configuration —
the updater is not Sparkle; the SU\* keys do not apply.

## Update behaviour

**Default (this config):** Anthropic's custom in-app updater
runs on its default cadence. The Homebrew cask's livecheck
polls `downloads.claude.ai/releases/darwin/universal/RELEASES.json`
for its own bookkeeping; the runtime updater inside the app
presumably hits a similar endpoint under `downloads.claude.ai`
(the exact runtime URL isn't part of the cask source — inference,
not verified fact). Updates replace `/Applications/Claude.app`
in place.

**Fallback if the auto-updater's `/Applications/` writes trigger
Mosyle admin-permission prompts:** Anthropic ships an in-app
toggle for disabling automatic updates (settings menu inside the
app; exact path may shift across versions). Disabling shifts
Claude to operator-cadence updates via
`brew update && brew upgrade --cask --greedy claude`.

There is no `system.defaults.CustomUserPreferences` key for
this. The toggle state is stored inside the app's per-user
config under `~/Library/Application Support/Claude/`, not in a
`defaults`-domain plist. Same shape as Cursor and Obsidian —
no declarative suppression path.

## Sharp edges

**Suppression fallback is operator-side, not declarative.** Same
caveat as [obsidian.md](./obsidian.md) and [cursor.md](./cursor.md):
unlike Sparkle/MAU/Keystone-shaped apps, there is no
`system.defaults` key to flip. Re-applying the suppression on a
fresh Mac would require re-toggling in-app on first launch.

**Bundle IDs** (for any future `defaults` work, none needed
today): `com.anthropic.claudefordesktop` for the main app,
plus `com.anthropic.claudefordesktop.helper` for the helper
process the cask references in its uninstall block. The
`.helper` companion holds Anthropic's background renderer
process — relevant if a future `defaults` toggle targets the
helper rather than the main app.

**Not Sparkle.** Do not wire `SUEnableAutomaticChecks` /
`SUAutomaticallyUpdate` keys under `com.anthropic.claudefordesktop`
— they are no-ops for Anthropic's custom updater. The cask's
livecheck happens to use a JSON strategy (not `:sparkle`),
which is the surface-level signal that Sparkle isn't involved.

**Migration candidate to nixpkgs.** Not viable today — there is
no `pkgs.claude-desktop` for Darwin. If Anthropic ever ships a
nixpkgs derivation or community packaging lands, the install-
path question reopens.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  clause 1: no Darwin nixpkgs equivalent.
- Homebrew `claude` cask source (custom JSON livecheck against
  Anthropic's release endpoint) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/c/claude.rb
- [`home/shared/agent-clis.nix`](../../home/shared/agent-clis.nix) —
  the `claude` agentic CLI; complementary to the desktop app.
