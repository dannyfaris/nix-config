# Wispr Flow

Voice-to-text dictation app — converts speech into formatted
text across any focused macOS application via a global hotkey.
Picked because it's the operator's daily-driver dictation tool;
dictating into chat / docs / agentic CLIs is materially faster
than typing for long-form input.

## Selection

Darwin: Homebrew cask `wispr-flow`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 1** (no nixpkgs equivalent on Darwin).

Update stance: **silent via Wispr Flow's Electron-style in-app
updater**. No `CustomUserPreferences` keys — the updater is not
Sparkle. Suppression fallback is an in-app toggle, not a
`defaults` key — same shape as Fellow, Cursor, Obsidian, and
Claude desktop.

## Rationale

**Clause-1 carve-out, no comparison to weigh.** Wispr Flow
distributes only as a direct `.dmg` from
`dl.wisprflow.com/wispr-flow/darwin/<arch>/dmgs/`. No Mac App
Store listing exists. The package is not in nixpkgs on
`aarch64-darwin`. Clauses 2 and 3 have nothing to evaluate.

## Alternatives considered

**MAS** — no listing. Rejected at ADR-031 Step 0.

**nixpkgs** — no Darwin package (verified via `nix eval`).
Rejected at Step 1.

**macOS native dictation** (`Fn` key, "Voice Control") — works
but materially less polished output than Wispr Flow's AI-edited
transcripts. The operator has weighed this and chosen Wispr
Flow; not a substitute.

**Whisper directly** (OpenAI's open-source speech-to-text model,
`pkgs.openai-whisper`) — different shape entirely; no app-wide
hotkey integration, no in-flow formatting / cleanup. CLI tool
for offline transcription, not a daily-driver dictation surface.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "wispr-flow" ];
```

No `CustomUserPreferences` keys in the default configuration —
the updater is not Sparkle; the SU\* keys do not apply.

## Update behaviour

**Default (this config):** Wispr Flow's Electron-style in-app
updater runs on its default cadence. The cask's livecheck uses a
JSON strategy against
`dl.wisprflow.com/wispr-flow/darwin/<arch>/RELEASES.json` for
Homebrew's bookkeeping; the runtime updater inside the app
handles self-updates by replacing `/Applications/Wispr Flow.app`
in place.

**Fallback if the auto-updater's `/Applications/` writes trigger
Mosyle admin-permission prompts:** disable the in-app auto-
update toggle. **Adopting the fallback shifts Wispr Flow to
operator-cadence updates** via
`brew update && brew upgrade --cask --greedy wispr-flow`. There
is no `system.defaults.CustomUserPreferences` key for this — the
toggle lives in Wispr Flow's per-user config under
`~/Library/Application Support/`, not in a `defaults`-domain
plist.

## Sharp edges

**Suppression fallback is operator-side, not declarative.** Same
caveat as Fellow, Obsidian, Cursor, and Claude desktop.

**TCC prompts on first use.** Wispr Flow needs Accessibility
permission (for the global hotkey to capture keypresses across
apps) and Microphone permission (for audio capture). First-launch
will surface both as macOS TCC prompts: System Settings →
Privacy & Security → Accessibility, and → Microphone. One-time;
the cask doesn't auto-grant these, and there's no nix-darwin-
declarative path to grant them (TCC's database is intentionally
operator-confirmed).

**Bundle ID is `com.electron.wispr-flow`** (the `com.electron.*`
prefix is a generic Electron-app default — Wispr Flow's
developers didn't rebrand their bundle ID, same shape as Fellow's
`com.electron.fellow`). Verified against the upstream cask's
`zap` block.

**ARM64 + x64 both supported.** The cask publishes per-arch
`.dmg` URLs; neptune's Apple Silicon takes the ARM64 build. No
manual arch flag needed.

**Requires macOS Monterey (12) or later.** The cask declares `depends_on macos: :monterey`; neptune is well past this floor, so it's a non-issue today — recorded for the day a host on an older macOS would join the fleet.

**Migration candidate to nixpkgs.** Not viable today — there is
no `pkgs.wispr-flow` for Darwin. If future packaging lands,
expect the Electron-in-store clause-2 shape to apply (in-app
updater fighting the immutable store path).

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  clause 1: no Darwin nixpkgs equivalent.
- Homebrew `wispr-flow` cask source (JSON livecheck against
  Wispr's release endpoint) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/w/wispr-flow.rb
