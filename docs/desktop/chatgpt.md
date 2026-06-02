# ChatGPT desktop

OpenAI's native macOS ChatGPT client. Picked because it's the
operator's secondary daily-driver AI assistant alongside Claude
desktop and the Cursor IDE's embedded models; the desktop app
covers UI-driven workflows that the web/CLI surfaces don't.

## Selection

Darwin: Homebrew cask `chatgpt`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

Update stance: **Sparkle silent**, same shape as Tailscale,
Ghostty, and Typora. `SUEnableAutomaticChecks` +
`SUAutomaticallyUpdate` keys wired in
`modules/darwin/homebrew.nix` under bundle ID `com.openai.chat`.

## Rationale

**MAS unavailable.** OpenAI distributes ChatGPT desktop only via
direct `.dmg` download from `persistent.oaistatic.com`; no Mac
App Store listing. Rejected at ADR-031 Step 0; clause 3 cannot
apply.

**Clause-2 carve-out, framed operationally.** `pkgs.chatgpt` is
available on `aarch64-darwin` (`meta.platforms` covers both
Darwin archs, src is the official `ChatGPT.app` bundle). The
binaries converge.

The cask is chosen because the nixpkgs Darwin derivation has a
named, load-bearing degradation:

- **Named integration:** ChatGPT's auto-updater is **Sparkle**
  (the Homebrew cask uses a Sparkle livecheck strategy against
  `persistent.oaistatic.com/sidekick/public/sparkle_public_appcast.xml`
  — confirmed against the upstream cask source). Sparkle expects
  `/Applications/ChatGPT.app` to be writable so the in-place
  update flow can replace the bundle. Silent point-release
  updates are how OpenAI ships model-side changes, conversation-
  UX iterations, and bug fixes between flake bumps.
- **Named degradation:** `pkgs.chatgpt` on Darwin installs the
  `.app` under the Nix store —
  `installPhase = "mkdir -p $out/Applications && cp -a
  ChatGPT.app $out/Applications && ln -s ... $out/bin/ChatGPT"`,
  so the bundle lives at
  `/nix/store/...-chatgpt-X.Y.Z/Applications/ChatGPT.app`. Nix
  store paths are immutable; Sparkle cannot write to them. The
  derivation does not pre-disable the updater (unlike
  `pkgs.google-chrome` with its `--simulate-outdated-no-au`
  wrapper), so Sparkle would attempt updates at runtime and
  either fail silently or surface error popups. Effective
  update cadence collapses to `nix flake update` + `nh darwin
  switch` — operator-cadence on a tool whose OpenAI-side
  features ship multiple times per week.
- **Named verification path:** if a contributor wants to flip
  to `pkgs.chatgpt`, verify: (1) ChatGPT's Sparkle updater can
  be cleanly disabled (no error popups, no `Sparkle.framework`
  retry attempts) when the bundle is immutable, (2) operator-
  cadence flake bumps land ChatGPT updates often enough to keep
  up with OpenAI's release cadence. If both pass, clause 2's
  degradation premise dissolves and ADR-031 Migration trigger 1
  applies.

The nixpkgs derivation also exposes a `ChatGPT` binary wrapper
in `$out/bin/`, which the cask does not. Useful if the operator
ever scripts ChatGPT-launching from the command line — not
load-bearing for the install-path decision.

**Update stance — Sparkle silent.** Same shape as Tailscale,
Ghostty, and Typora: let Sparkle do its job, set the SU\* keys
belt-and-braces so the silent posture is explicit. OpenAI ships
frequent point releases; operator-cadence updates would mean
lagging features.

## Alternatives considered

**MAS** — not on MAS. Rejected at ADR-031 Step 0.

**`pkgs.chatgpt` on Darwin** — viable mechanism; carved out on
the operational grounds above (Sparkle silently broken by
immutable nix-store path; no pre-disable safety like Chrome
has). Worth revisiting as a follow-up if a contributor wants to
verify the equivalence test in §Rationale.

**Web client at chatgpt.com in Chrome** — works, and the
operator has Chrome. Functional fallback; not a daily-driver
substitute for the same dock-presence / Cmd-Tab / OS-integration
reasons as the other AI desktop apps.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "chatgpt" ];

system.defaults.CustomUserPreferences = {
  "com.openai.chat" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
  };
};
```

Bundle ID `com.openai.chat` is confirmed against the upstream
cask's `zap` block; verify on the live host with
`defaults domains | tr , '\n' | grep -i openai` before treating
the keys as having taken effect.

## Update behaviour

**Default (this config):** Sparkle runs on its vendor cadence
and silently updates `/Applications/ChatGPT.app`. No operator
action required.

Verify the keys took effect after first activation:

```bash
defaults read com.openai.chat SUEnableAutomaticChecks   # → 1
defaults read com.openai.chat SUAutomaticallyUpdate     # → 1
```

**Fallback if Sparkle's `/Applications/` writes trigger Mosyle
admin-permission prompts:**

```nix
system.defaults.CustomUserPreferences."com.openai.chat" = {
  SUEnableAutomaticChecks = false;
  SUAutomaticallyUpdate = false;
};
```

Then update ChatGPT manually via
`brew update && brew upgrade --cask --greedy chatgpt`. Same
shape as the Tailscale, Ghostty, and Typora fallbacks.

## Sharp edges

**`auto_updates true` in the upstream cask is metadata, not
runtime behaviour.** The flag tells Homebrew "this cask self-
updates, don't manage version bumps." Runtime behaviour is
controlled by Sparkle and the SU\* keys above. Worth knowing
when scanning the cask source for clues about how updates flow.

**Bundle ID `com.openai.chat`** (singular "chat", not
"chatgpt"). Verified against the upstream cask's `zap` block.
Easy to mistype as `com.openai.chatgpt`.

**The cask's Sparkle livecheck quirk.** The upstream cask
comment notes that OpenAI's Sparkle feed sometimes ships older
items with newer `pubDate` timestamps, so Homebrew's livecheck
examines all feed items rather than newest-only. This is
Homebrew bookkeeping, not a runtime concern — flagged here only
because it surfaces in the cask source as an unusual livecheck
configuration.

**Migration candidate to nixpkgs.** Per §Rationale's
verification path: if a contributor lands a clean Sparkle-
disable path for `pkgs.chatgpt` on Darwin (no error popups, no
update-retry loops), the clause-2 carve-out's premise weakens
and ADR-031 Migration trigger 1 may fire. Operator-cadence
flake bumps would still need to be acceptable as a feature-
delivery channel.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing ChatGPT on the Mac via cask under
  clause 2; this doc owns the carve-out justification.
- Homebrew `chatgpt` cask source (Sparkle livecheck against
  `persistent.oaistatic.com`) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/c/chatgpt.rb
