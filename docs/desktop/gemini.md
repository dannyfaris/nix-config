# Gemini desktop

Google's native macOS Gemini client. Picked because it's the
operator's third daily-driver AI assistant alongside Claude and
ChatGPT desktops; rounding out the major-vendor surface area.

## Selection

Darwin: Homebrew cask `google-gemini`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 1** (no nixpkgs equivalent on Darwin at write-time).

Update stance: **silent-via-Keystone**, the same Google
auto-updater agent that manages Chrome. **One Keystone agent
serves both Chrome and Gemini on this Mac** — see §Update
behaviour and the Chrome doc for the shared-agent caveat.

## Rationale

**Clause-1 carve-out.** Google distributes Gemini desktop only
as a direct `.dmg` from `dl.google.com/release2/j33ro/release/Gemini.dmg`
(the same distribution endpoint as Chrome). No Mac App Store
listing exists. The package is not in nixpkgs on
`aarch64-darwin` at write-time (the cask landed recently; the
nixpkgs derivation hasn't followed yet). Clauses 2 and 3 have
nothing to evaluate; cask is the only managed install path.

If a future `pkgs.google-gemini` lands on Darwin, the install-
path question reopens — and the carve-out shape will almost
certainly mirror [chrome.md](./chrome.md)'s clause-2 walk
(Keystone's `/Applications/` writes vs. immutable nix-store
paths, with the same `--simulate-outdated-no-au`-shaped
neutering risk if the derivation follows Chrome's pattern).
Marked here as a future migration-candidate flag.

## Alternatives considered

**MAS** — no listing for Google's Gemini. There IS a
"Gemini for Mac" on MAS by Cypress North, but that is a
Stellar / XLM cryptocurrency wallet, NOT Google's AI assistant.
**Do not install the Cypress North app.** Rejected at ADR-031
Step 0.

**nixpkgs** — no Darwin package at write-time. Rejected at
Step 1 (clause-1 default fires).

**Web client at gemini.google.com in Chrome** — works, and the
operator has Chrome. Functional fallback; not a daily-driver
substitute for the same dock-presence reasons as Claude and
ChatGPT desktops.

## Platform restrictions

The cask declares two hard requirements (verified against the
upstream cask source):

- **Apple Silicon only** (`arch arm: ...` with no Intel fallback).
- **macOS Sequoia (15) or later** (`depends_on macos: ">= :sequoia"`).

neptune meets both. A future Intel Mac or pre-Sequoia host
would need an alternative (Gemini in Chrome covers the gap).

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "google-gemini" ];
```

No `CustomUserPreferences` keys in the default configuration —
the updater is Keystone (not Sparkle), and Keystone's
suppression key `com.google.Keystone.Agent → checkInterval = 0`
is **already shared with Chrome's update story** (see
[chrome.md](./chrome.md) §Update behaviour). Wiring a
Gemini-specific Sparkle key here would be a no-op.

## Update behaviour

**Default (this config):** Keystone (`com.google.Keystone.Agent`)
runs as a launchd-managed agent — the same instance already
installed by Chrome — and silently updates
`/Applications/Gemini.app` alongside `/Applications/Google Chrome.app`
on its default cadence. No operator action required; no
Gemini-specific configuration needed.

The cask's zap block confirms the shared-Keystone shape: it
references `com.google.GoogleUpdater.wake.system`,
`com.google.keystone.*` (agent, daemon, xpcservice variants),
and `~/Library/Google/GoogleSoftwareUpdate/Actives/com.google.GeminiMacOS`.
Keystone tracks an `Actives/<bundle-id>` entry per Google app
it manages; uninstalling Gemini removes only its own Active
entry without touching Chrome's.

**Fallback** — see [chrome.md](./chrome.md) §Update behaviour.
The same `com.google.Keystone.Agent → checkInterval = 0`
suppression key affects **both Chrome and Gemini
simultaneously** (they share the launchd agent). There is no
per-app Keystone suppression knob.

## Sharp edges

**Keystone is shared with Chrome.** This is the load-bearing
operational note. The two apps' update behaviour is governed by
one launchd agent; flipping Keystone off for one flips it off
for both. The Chrome doc owns the suppression fallback recipe;
this doc cross-references rather than duplicates. If a future
operator wants per-app update control, that's a
"swap-Keystone-for-something-app-specific" question for which
Keystone has no clean answer.

**Cask is Apple Silicon + Sequoia only.** Listed under §Platform
restrictions above. If a future Mac host doesn't meet both, the
cask won't install and the operator needs the web client.

**MAS "Gemini" is NOT Google's app.** The Cypress North
cryptocurrency wallet on MAS shares the name. If the operator
ever sees a "Gemini" listing on the Mac App Store while
shopping for the AI app, do not install it — that's a different
product entirely. The cask's `app "Gemini.app"` line installs
Google's binary; MAS would install the wallet.

**Bundle ID `com.google.GeminiMacOS`** (with `Os` capitalised at
the end — the upstream cask uses this exact casing). Worth
double-checking via `mdls -name kMDItemCFBundleIdentifier
/Applications/Gemini.app` on the live host if any future
`defaults`-domain work targets this app; Google's bundle-ID
casing has varied across their other Mac apps.

**No nixpkgs path today.** If a future `pkgs.google-gemini`
lands on Darwin, expect it to follow Chrome's derivation shape
(nix-store-rooted `.app`, possibly with a `--simulate-outdated-no-au`-
shaped flag neutering Keystone), and the install-path question
flips to a clause-2 walk mirroring [chrome.md](./chrome.md).

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  clause 1: no Darwin nixpkgs equivalent at write-time.
- [chrome.md](./chrome.md) — Keystone-suppression fallback recipe;
  the same agent governs Gemini's updates.
- Homebrew `google-gemini` cask source —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/g/google-gemini.rb
