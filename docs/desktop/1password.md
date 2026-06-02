# 1Password

Operator password manager. Cross-platform; managed today on
`mac-mini` only in this configuration. NixOS desktop adoption
(metis) tracked separately and out of scope for #13.

## Selection

Darwin: Homebrew cask `1password` (1Password 8 desktop, Standalone
build — NOT the MAS variant), declared in `modules/darwin/homebrew.nix`
per [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

NixOS desktop adoption: `programs._1password-gui` (nixpkgs) — not
wired in this PR.

## Rationale

**Clause-2 carve-out, framed operationally.** `pkgs._1password-gui`
is available on `aarch64-darwin` and `x86_64-darwin`, and its
`src.url` (`https://downloads.1password.com/mac/1Password-X-arch.zip`)
is the same standalone .zip the Homebrew cask installs. The
binaries converge.

The cask is chosen because it is the install mechanism 1Password's
own deployment documentation, MDM templates, and Mosyle profile
references target. A nix-managed install via `_1password-gui` on
Darwin is plausibly equivalent — same binary, same `src.url` — but
verifying equivalence across browser native-messaging
host registration, system-extension / login-item flows, and the
expectations 1Password's QA tests against is operator time we are
deliberately not spending. The risk surface — silently degraded
browser autofill for the operator's primary password-manager
workflow — is not worth the saving of declaring a different attribute.

Per ADR-031's clause-2 specificity bar:

- **Named integration:** vendor-supported install path (1Password
  MDM templates, deployment docs, and support scripts target the
  cask's `.pkg` install layout).
- **Named degradation:** `pkgs._1password-gui` on Darwin places
  `1Password.app` under the Nix store — its `installPhase` is
  `cp -r *.app $out/Applications/`, so the `.app` lives at
  `/nix/store/...-1password-gui-X.Y.Z/Applications/1Password.app`.
  1Password's browser-extension native-messaging-host JSON files
  reference the app launcher by **absolute path**; its MDM/Mosyle
  deployment templates assume `/Applications/1Password.app`. A
  nix-store-rooted install requires either symlinking into
  `/Applications/` (re-introducing imperative state at the boundary
  nix-darwin is trying to remove) or accepting that browser
  autofill, Safari helper, and any MDM-pushed preferences silently
  target the wrong path. Cask installs to `/Applications/` natively.
- **Named verification path:** open Safari, Firefox, Chrome with
  the 1Password browser extension installed via the extension
  marketplaces; attempt autofill in a known-working test site for
  each. If autofill works in all three after a `pkgs._1password-gui`
  Darwin install, clause 2's degradation premise dissolves and
  ADR-031 Migration trigger 1 applies.

**Standalone variant, not MAS.** Same reasoning as
[tailscale.md](./tailscale.md): the MAS variant is sandboxed; the
Standalone build is what 1Password's deployment documentation
targets for preference management.

## Alternatives considered

**`pkgs._1password-gui` on Darwin** — viable mechanism; carved out
on the operational grounds above. Worth revisiting as a follow-up
experiment outside this ADR if a contributor wants to verify the
equivalence test in §Rationale.

**MAS 1Password variant** — sandboxed; updater preferences are not
honoured (the MAS variant updates via the App Store regardless).
Rejected.

**Self-hosted Bitwarden / pass / age** — different model; out of
scope to switch.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "1password" ];
```

No `CustomUserPreferences` keys for 1Password in the default
configuration — 1Password's vendor updater is allowed to surface
its occasional prompt; see §Update behaviour.

## Update behaviour

**Default (this config):** 1Password's built-in updater runs on
its own schedule. When an update is available, 1Password surfaces a
prompt asking the operator to install (and, depending on the
Mosyle policy in force at `/Applications/` write time, may chain
into an admin-auth prompt — see ADR-031 §Update mechanism stance).
Frequency is bounded — typically a few times per year. Accepted on
"least action overall" grounds: a few clicks per year beats a
routine manual cask-update cadence.

**Fallback if 1Password prompts become intolerable** (or Mosyle
escalates the prompt to a full permission storm):

```nix
# modules/darwin/homebrew.nix
system.defaults.CustomUserPreferences."com.1password.1password" = {
  "updates.autoUpdate" = false;
};
```

Then update 1Password manually as needed via
`brew update && brew upgrade --cask --greedy 1password`. The
`brew update` prefix and `--greedy` flag have the same rationale
as Ghostty/Tailscale. **Adopting the fallback shifts 1Password to
operator-cadence updates** — the operator must remember to run the
brew command periodically; this is a real cost not present in the
default.

Verify the fallback took effect:

```bash
defaults read com.1password.1password updates.autoUpdate   # → 0
```

## Sharp edges

**If the fallback is wired: medium-confidence suppression
mechanism.** 1Password 8 ships its own (non-Sparkle) updater. The
`updates.autoUpdate` key is recorded here from a moment-in-time
observation of 1Password community discussions with staff
acknowledgement; it is not on 1Password's public MDM-deployment
documentation. (Earlier draft cited a specific community-forum
thread; dropped because forum threads are editable and the
operator cannot pin to a specific revision.) Treat any
post-suppression update prompt as a signal that this key has
shifted in a 1Password update; re-verify against 1Password's
current MDM template documentation before patching.

**Key encoding may need to be nested.** The 1Password sources read
as ambiguous between a flat dotted key (`updates.autoUpdate`) and
a nested attrset (`updates = { autoUpdate = …; }`). If the flat
form above fails to suppress prompts, try:

```nix
system.defaults.CustomUserPreferences."com.1password.1password" = {
  updates = { autoUpdate = false; };
};
```

**Bundle ID is `com.1password.1password`** (not the legacy
`com.agilebits.*` namespace, which still appears in some zap-trash
paths). Easy to mistype because the vendor name doubles in the
identifier.

**Not Sparkle.** Do not add `SUEnableAutomaticChecks` /
`SUAutomaticallyUpdate` here — they are no-ops for 1Password 8's
custom updater.

**Migration candidate to nixpkgs.** Per §Rationale's verification
path: if Safari/Firefox/Chrome autofill all work after a normal
extension install with `pkgs._1password-gui` on Darwin, the
clause-2 carve-out's premise dissolves and ADR-031 Migration
trigger 1 fires. Until that verification exists, cask stays.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) — boundary
  rule placing 1Password on the Mac via cask under clause 2; this
  doc owns the carve-out justification.
- Homebrew `1password` cask source (custom JSON livecheck,
  `auto_updates true`) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/1/1password.rb
