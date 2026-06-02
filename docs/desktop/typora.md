# Typora

Paid markdown editor (one document = one window, WYSIWYG render
in place rather than split-pane). Picked because it's the
operator's existing daily-driver editor for long-form markdown
prose work; the workflow muscle memory is the load-bearing
reason.

## Selection

Darwin: Homebrew cask `typora`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

Update stance: **Sparkle silent**, same shape as Tailscale and
Ghostty. `SUEnableAutomaticChecks` + `SUAutomaticallyUpdate`
keys wired in `modules/darwin/homebrew.nix` under bundle ID
`abnerworks.Typora`.

## Rationale

**MAS unavailable.** Typora's distribution page lists direct-
download `.dmg` only; no apps.apple.com listing exists. Rejected
at ADR-031 Step 0; clause 3 cannot apply.

**Clause-2 carve-out, framed operationally.** `pkgs.typora` is
available on `aarch64-darwin` (`meta.platforms` covers both
Darwin archs, `meta.broken = false`, `src.url` is the official
`Typora.dmg` from `downloads.typora.io`). The binaries
converge.

The cask is chosen because the nixpkgs Darwin derivation has a
named, load-bearing degradation:

- **Named integration:** Typora's auto-updater is **Sparkle**
  (Homebrew's `typora` cask uses Sparkle's
  `https://typora.io/releases/macos.xml` feed for its livecheck
  strategy — confirmed against the upstream cask source).
  Sparkle expects `/Applications/Typora.app` to be writable so
  the in-place update flow can replace the bundle. This is
  load-bearing: silent point-release updates are how Typora
  ships features and fixes between flake bumps.
- **Named degradation:** `pkgs.typora` on Darwin installs the
  `.app` under the Nix store —
  `installPhase = "mkdir -p $out/Applications && cp -a
  Typora.app $out/Applications"`, so the bundle lives at
  `/nix/store/...-typora-X.Y.Z/Applications/Typora.app`. Nix
  store paths are immutable; Sparkle cannot write to them.
  Unlike `pkgs.google-chrome`, the Typora derivation does NOT
  pre-disable the updater — Sparkle will attempt updates at
  runtime and either fail silently or surface error popups. The
  app only effectively updates via `nix flake update`, which is
  operator-cadence on a workflow tool whose feature improvements
  the operator wants.
- **Named verification path:** if a contributor wants to flip
  to `pkgs.typora`, verify: (1) Typora's Sparkle path can be
  cleanly disabled (no error popups) when the bundle is
  immutable, (2) operator-cadence flake bumps land Typora
  updates often enough to be acceptable. If both pass, clause
  2's degradation premise dissolves and ADR-031 Migration
  trigger 1 applies.

**Update stance — Sparkle silent.** Same shape as Tailscale and
Ghostty: let Sparkle do its job, set the SU* keys belt-and-
braces so the silent posture is explicit. Typora ships frequent
point releases; operator-cadence updates would mean lagging
features.

## Alternatives considered

**MAS** — not on MAS. Rejected at ADR-031 Step 0.

**`pkgs.typora` on Darwin** — viable mechanism; carved out on
the operational grounds above (Sparkle silently broken by
immutable nix-store path; no pre-disable safety like Chrome
has). Worth revisiting as a follow-up if a contributor wants to
verify the equivalence test in §Rationale.

**Other markdown editors** (Obsidian, MacDown, plain Helix in
markdown mode) — out of scope; the operator's existing workflow
is the selection rationale.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "typora" ];

system.defaults.CustomUserPreferences = {
  "abnerworks.Typora" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
  };
};
```

The bundle ID `abnerworks.Typora` is confirmed against the
upstream cask's `zap` block; verify on the live host with
`defaults domains | tr , '\n' | grep -i typora` before treating
the keys as having taken effect.

## Update behaviour

**Default (this config):** Sparkle runs on its vendor cadence
and silently updates `/Applications/Typora.app`. No operator
action required.

Verify the keys took effect after first activation:

```bash
defaults read abnerworks.Typora SUEnableAutomaticChecks   # → 1
defaults read abnerworks.Typora SUAutomaticallyUpdate     # → 1
```

**Fallback if Sparkle's `/Applications/` writes trigger Mosyle
admin-permission prompts:**

```nix
system.defaults.CustomUserPreferences."abnerworks.Typora" = {
  SUEnableAutomaticChecks = false;
  SUAutomaticallyUpdate = false;
};
```

Then update Typora manually via
`brew update && brew upgrade --cask --greedy typora`. Same
shape as the Tailscale and Ghostty fallbacks.

## Sharp edges

**Paid app — license activation is an operator step.** Typora
is $14.99 one-time for up to 3 devices, with a 15-day trial.
The license key is entered in-app on first launch (Preferences
→ License). Not a packaging concern — the cask installs the
trial-mode binary regardless of license state.

**No `auto-updates` config knob in the cask.** Typora's
`auto_updates true` field in the upstream cask is a Homebrew
metadata flag telling brew not to manage version bumps; the
runtime Sparkle behaviour is controlled entirely by the SU* keys
above.

**Bundle ID is `abnerworks.Typora`.** Verified against the
upstream cask's `zap` block (cache, preferences, and application
state cleanup paths all key off this ID). The `abnerworks`
prefix is Typora's original developer organisation name —
unusual but stable.

**Migration candidate to nixpkgs.** Per §Rationale's
verification path: if a contributor lands a clean Sparkle-
disable path for `pkgs.typora` on Darwin (no error popups), the
clause-2 carve-out's premise weakens and ADR-031 Migration
trigger 1 may fire. Operator-cadence flake bumps would still
need to be acceptable as a feature-delivery channel.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing Typora on the Mac via cask under
  clause 2; this doc owns the carve-out justification.
- Homebrew `typora` cask source (Sparkle livecheck strategy
  pointing at typora.io/releases/macos.xml) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/t/typora.rb
