# ADR-031: nix-homebrew boundary for managed casks on Darwin

**Date**: 2026-06-02
**Status**: Accepted

## Context

PRD §2.2 commits to consolidating Mac auto-updates through `nix-homebrew` driven by `darwin-rebuild` on Mosyle/MDM grounds: per-app auto-update prompts trigger admin/permission escalations that interrupt operator flow. `mac-mini` activated 2026-06-02 (epic #11, child #15 / PR #169) with no homebrew layer yet; three casks the operator wants managed today (Ghostty, Tailscale, 1Password) sit either hand-installed or absent.

This ADR draws the boundary: when does something land in Homebrew vs nixpkgs vs the Mac App Store, what configuration stance the homebrew layer takes, and what *category* of mechanism handles in-app updates. Per-app mechanism details live in per-tool docs under `docs/desktop/` per the ADR-029 pattern. A §Investigation guidance section captures the evaluation methodology for adding a fourth cask.

## Decision

### Layer split

`nix-homebrew` (zhaofengli/nix-homebrew) installs Homebrew itself: prefix, ownership, taps-as-flake-inputs. It does not manage packages. `nix-darwin`'s own `homebrew` module manages the declarative cask list (`homebrew.casks = [ … ]`). The two compose: nix-homebrew bootstraps the prefix; nix-darwin manages the cask list.

### Boundary rule

**nixpkgs by default. Homebrew when either:**

1. **No nixpkgs equivalent on Darwin.** The package is missing on `aarch64-darwin` / `x86_64-darwin` in `meta.platforms`, or ships only as a native `.app` not in nixpkgs.
2. **nixpkgs has a Darwin build but the macOS-native install path materially degrades** under nix-managed app handling. Clause-2 carve-outs require, in the per-tool doc: the *named integration* the cask provides (e.g., vendor-supported install path, system-extension registration, MDM template compatibility), the *named degradation* under nix-managed install, and a *named verification path* for the carve-out's correctness.

Read clause 1 as the default and clause 2 as a bounded carve-out. A future cask that fails clause 1 must clear clause 2's specificity bar before landing. "Don't like the nix-managed location" alone does not qualify.

Cross-platform GUI apps may land via nixpkgs on NixOS desktops and via Homebrew cask on Darwin under either clause; that asymmetry is expected, not a smell.

### Scope exclusions

These are outside the boundary altogether (no per-tool doc required):

- **No third-party taps.** Only `homebrew/core` and `homebrew/cask`. Adding a third-party tap requires an explicit amendment to this ADR.
- **Formulae stay in nixpkgs.** This boundary applies to casks. If a future formula gap surfaces, file a separate decision.
- **MAS stays manual.** App Store apps are sandboxed, Apple-account-coupled, and out of scope per PRD §2.2.
- **MDM-managed agents stay manual.** Mosyle deploys its own agent; declaring the thing whose existence motivates the boundary is tail-eating-tail.

### Day-one casks

| Cask | Justification | Per-tool doc |
|---|---|---|
| `ghostty` | Clause 1 (Linux-only `meta.platforms`) | [docs/desktop/ghostty.md](../desktop/ghostty.md) |
| `tailscale-app` | Clause 1 (`pkgs.tailscale` on Darwin ships only the daemon/CLI; the `NetworkExtension` GUI is not in nixpkgs) | [docs/desktop/tailscale.md](../desktop/tailscale.md) |
| `1password` | Clause 2 (`pkgs._1password-gui` exists on Darwin; cask chosen as the vendor-supported install path that 1Password's MDM templates target) | [docs/desktop/1password.md](../desktop/1password.md) |

Adding a fourth cask requires a per-tool doc landing in the same PR per `docs/workflow.md`'s doc-before-code rule.

### Update mechanism stance

**Trust the vendor's silent-update path where one exists; document the suppression-mode fallback for cases where Mosyle or macOS-level prompts surface anyway.**

For Sparkle-based apps (Ghostty, Tailscale), enable Sparkle's silent-update mode via `system.defaults.CustomUserPreferences` on the app's bundle ID:

- `SUEnableAutomaticChecks = true` — Sparkle checks on its schedule (≈daily).
- `SUAutomaticallyUpdate = true` — for archive-style Sparkle enclosures (`.app` in `.dmg`, `.zip`, `.tar.*`, `.aar`), installs on next quit/launch without prompting and without admin auth (non-sandboxed `.app` bundle replacement requires no privileged step). For `.pkg`-enclosure Sparkle appcasts — or archive enclosures carrying the `sparkle:installationType="package"` attribute — Sparkle's own documentation states updates *"always require user authorization which also prevents silent automatic installs."* No silent path; expect a prompt every update. Per-tool docs identify the appcast enclosure format for each cask.

What Sparkle silent-install does NOT cover, that may still surface a prompt:

- **First-install `.pkg` payload.** Casks that ship a `.pkg` installer (e.g., Tailscale) run that installer at the first cask install — admin auth required, plus any system-extension grants the pkg triggers. One-time per Mac; subsequent steady-state updates use the Sparkle archive path if the appcast enclosure is archive-shaped.
- **macOS System Extension reinstall.** If an app ships a system extension (Tailscale's `NetworkExtension`; some VPN and endpoint-security apps), macOS may prompt to authorize each update of the extension itself, independent of Sparkle's app-bundle replacement. Not suppressible from this layer.
- **macOS first-encounter prompts (Gatekeeper / TCC).** First launch of an app or its bundled updater helper may surface a one-time Gatekeeper "downloaded from the internet" prompt or a TCC authorization for specific entitlements. These are per-app, one-time; not Sparkle-update-specific. Subsequent updates within the same grant are silent.
- **Mosyle/MDM policy on `/Applications/` writes.** Mosyle profiles can enforce admin authorization for any `/Applications/` modification. If this policy is in force, even Sparkle's otherwise-silent updates will surface a prompt every time. This is the load-bearing uncertainty PRD §2.2 references; empirical observation post-activation determines whether the silent path holds in practice.

For non-Sparkle apps (1Password's custom updater), the vendor's default-on auto-check is allowed to surface its occasional prompt. No suppression today; the per-tool doc records the fallback if prompt frequency becomes intolerable.

`system.defaults.CustomUserPreferences` writes per-bundle-ID plist keys at every `darwin-rebuild switch`. Values take effect at the next Sparkle check (typically next app launch or next scheduled background poll) — a running app reads its prefs once at launch, so toggling values requires the next app launch to take effect. No logout required.

Per-tool docs name the specific keys, the silent-update settings used by default, and the suppression-mode values to apply as the documented fallback.

### Configuration stance

- `nix-homebrew.mutableTaps = false` — taps fully declarative; injects `HOMEBREW_NO_AUTO_UPDATE=1` into activation-time brew invocations (not interactive shell ones). No surprise background `brew update` runs during `darwin-rebuild switch`.
- `homebrew.global.autoUpdate = false` — extends the no-auto-update posture from activation-time invocations to all brew invocations the operator runs at the shell, by setting `HOMEBREW_NO_AUTO_UPDATE=1` in `environment.variables`. Complements `mutableTaps`; the two are layered, not redundant.
- `homebrew.onActivation.cleanup = "uninstall"` — the cask list is the single source of truth. Anything not declared is removed at activation. (`"zap"` would also delete user data; rejected as too aggressive.)
- `homebrew.onActivation.autoUpdate = false` and `homebrew.onActivation.upgrade = false` — activation installs missing casks but does not attempt brew-side upgrades. Upgrades happen via the per-app vendor path (Sparkle silently where it works; 1Password on its own cadence).

### Update cadence

The simplified design has no scheduled `justfile` recipe. Sparkle keeps Ghostty and Tailscale current silently (within the constraints in §Update mechanism stance); 1Password updates on its own when the operator lets it.

If a manual force-update is ever needed (e.g., to apply a known-fixed CVE before Sparkle's next check):

```bash
brew update && brew upgrade --cask --greedy <name>
```

`--greedy` is required because all three casks declare `auto_updates true` (see §Investigation guidance step 2), which tells brew to skip them by default. The `brew update && ` prefix is required because `mutableTaps = false` + `homebrew.global.autoUpdate = false` mean the tap state brew reads is whatever was current at the last `darwin-rebuild switch`. If Sparkle's silent install has already raced ahead of the tap-pinned version, the brew invocation will see the installed version as current and no-op; `brew update` refreshes tap metadata first.

**Note on fallback cost.** If a per-tool fallback is wired (e.g., the operator suppresses 1Password's updater per its doc), THAT app then requires periodic manual `brew update && brew upgrade --cask --greedy <name>` invocations the operator must own. Suppression-mode adoption is a real ergonomic cost, not free — it shifts the app from vendor-cadence to operator-cadence. Per-tool docs own the exact fallback recipe — for apps with their own update-config knob (Ghostty), the suppression-mode toggle must be coordinated across both layers. Suppression keys alone are insufficient where an in-app knob overrides them.

### Module placement

Standalone module at `modules/darwin/homebrew.nix` (capability-named per the most-communicative-term rule in `docs/taxonomy.md`). Single-module — does not satisfy bundle-purity (≥ 2 imports) and is not filed as a bundle. Promote if a sibling capability ever joins.

### Investigation guidance for new casks

Before adding a fourth cask, walk through the following checklist. The output feeds the per-tool doc that lands with the cask under workflow.md's doc-before-code rule.

**Step 1 — Boundary rule.**

- Clause 1: is the package missing from `meta.platforms` on `aarch64-darwin` / `x86_64-darwin`, or only available as a non-nixpkgs `.app`? Verify via `nix eval nixpkgs#<pkg>.meta.platforms` and (if it claims Darwin support) inspect `nix eval nixpkgs#<pkg>.src` to identify the upstream tarball — `src.url` resolves for `fetchurl`-style packages; for `fetchFromGitHub`/`fetchzip`/`fetchgit`, read the package's `default.nix` directly.
- Clause 2: if nixpkgs has Darwin support, the per-tool doc must name a specific integration the cask provides, a specific degradation under the nix-managed path, and a verification path for the carve-out. "Don't like the nix-managed location" alone does not qualify.

**Step 2 — Cask install format.**

Read the cask source at `https://github.com/Homebrew/homebrew-cask/blob/master/Casks/<letter>/<name>.rb`. Determine:

- `app "<Name>.app"` — `.dmg`-with-`.app` delivery. Cleanest update path: Sparkle replaces the `.app` bundle in place.
- `pkg "<Name>.pkg"` — `.pkg` installer. May register system extensions, login items, or daemons. First install runs the pkg installer; Sparkle updates may still be archive-based (check step 4).
- `installer manual:` — manual install; out of scope for nix-homebrew's auto-install path.
- `auto_updates true|false` — `true` means brew skips this cask on `brew upgrade --cask` unless `--greedy` is passed; affects the fallback recipe.

Worked example — the Tailscale cask is named `tailscale-app`, NOT `tailscale`. The latter is the CLI-only formula. Cask name ≠ formula name ≠ binary name; always start from the cask filename.

**Step 3 — Updater type.**

- **Sparkle** — confirm via the cask's `livecheck` block (`strategy :sparkle`). Sparkle is well-documented: per-bundle-ID `defaults` keys (`SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, etc.) per https://sparkle-project.org/documentation/customization/. Bundle ID: take from the cask's `uninstall quit:` stanza (or the `zap trash:` plist path under `~/Library/Preferences/<bundle-id>.plist`). The *app* bundle ID — not the pkg installer ID, which may differ (Tailscale's pkg ID is `com.tailscale.ipn.macsys`; the app bundle ID is `io.tailscale.ipn.macsys`).
- **Other in-app updaters** (Microsoft AutoUpdate / MAU, Squirrel.Mac, Electron-builtin, app-specific custom) — follow their own preference schemas. Document the cask-specific suppression key in the per-tool doc with the same medium-confidence treatment as 1Password's `updates.autoUpdate`; cite vendor MDM/deployment docs as primary, community threads as secondary, and flag encoding uncertainty (flat-dotted vs nested) as a `defaults`-domain hazard.
- **Sandboxing.** Check whether the app is sandboxed (cask source, vendor docs, or the app's entitlements). Sparkle's behaviour differs: sandboxed apps require an installer XPC service for any update; non-sandboxed apps update via direct `.app` bundle replacement without privileged steps. All three day-one casks are non-sandboxed Standalone builds.

**Step 4 — Sparkle appcast enclosure (if Sparkle).**

Fetch the appcast URL from the cask's `livecheck` block (`url "https://..."`) and inspect the `<enclosure>` tag. The enclosure's `url` attribute (file extension) and `sparkle:installationType` attribute determine silent-install behaviour:

- `.dmg` / `.zip` / `.tar.*` / `.aar` archive enclosures — Sparkle's silent install works for non-sandboxed apps.
- `.pkg` enclosure, or any enclosure with `sparkle:installationType="package"` — per Sparkle's package-updates documentation, *"installs always require user authorization which also prevents silent automatic installs."* No silent path; expect a prompt every update.

Check both the file extension AND the `sparkle:installationType` attribute — a `.zip` carrying a `.pkg` payload (signalled by the attribute, or detected at unpack time when the archive's top-level entry is a `.pkg`) falls into the `.pkg` bucket, not the archive bucket.

**Step 5 — System-level update surfaces.**

Identify whether the app uses any of these macOS surfaces (visible in the cask's `uninstall:` / `zap:` blocks):

- `pkgutil:` IDs ending in `.network-extension`, `.endpoint-security`, etc. — system extensions whose update may surface an Apple prompt independent of Sparkle.
- `launchctl:` entries — privileged daemons or launch agents.
- `loginItems:` or `~/Library/LaunchAgents/` zap paths — login items.

Verify the cask installs a notarized + Developer-ID-signed binary (the cask system relies on macOS Gatekeeper for trust). Sandboxed MAS apps are explicitly out of scope per §Scope exclusions; non-MAS but unsigned/unnotarized casks should fail this evaluation.

Each of the surfaces above is a separate update prompt source that may fire independent of in-app Sparkle behaviour. Name any in the per-tool doc's §Sharp edges.

**Step 6 — Verification.**

Document in the per-tool doc:

- The `defaults read <bundle-id> <key>` commands to confirm the keys took effect post-`darwin-rebuild switch`. (Run as `system.primaryUser`, or prefix with `sudo --user=<primary-user> -- defaults read …` from a different account.)
- `launchctl print gui/$(id -u)/<bundle-id>` to confirm any login-item / launch-agent registration succeeded.
- `pkgutil --pkgs | grep <vendor>` to confirm any pkg-installer registration.
- A reasonable observation window for "did the design work" — e.g., "no prompts over 2-3 weeks of normal use; one or zero vendor prompts per quarter for non-Sparkle apps."
- The fallback mechanism with the same level of detail as the primary path. Future operators must be able to flip to fallback without re-research.

## Rationale

**Why "actively-enable-silent" rather than "trust vendor defaults."** Sparkle's out-of-the-box behaviour is *check + prompt to install*. Silent updates require explicit `SUAutomaticallyUpdate = true`. The mechanism (per-bundle plist writes via `system.defaults.CustomUserPreferences`) is the same as a suppression design — we're just flipping bits in the opposite direction.

**Why `system.defaults.CustomUserPreferences` rather than `system.activationScripts`.** It writes via `defaults write` per-bundle-ID at every `darwin-rebuild switch`, is idempotent by construction, and slots into the same activation phase as Apple's typed `system.defaults.<domain>` blocks. `system.activationScripts` would work but loses the typed-attrset surface.

**Why `mutableTaps = false`.** Aligns with the repo's "explicit > implicit, whitelist > blanket" deliberate stance (per CLAUDE.md). Side effect: forces `HOMEBREW_NO_AUTO_UPDATE=1` for activation-time brew invocations; combined with `homebrew.global.autoUpdate = false`, brew never refreshes tap metadata behind the operator's back at any layer.

**Why `cleanup = "uninstall"` rather than `"none"`.** Same whitelist philosophy as `users.mutableUsers = false`: the declaration is the source of truth. A cask installed out-of-band is removed at next activation, surfacing drift loudly rather than silently.

**Why per-tool docs still describe a suppression-mode fallback.** Mosyle's exact policy interaction with `/Applications/` writes is uncertain at design time. If silent updates trigger admin-permission escalations in practice (the PRD §2.2 complaint), the documented fallback is to flip the same keys to `false` and adopt a manual `brew update && brew upgrade --cask --greedy` recipe per app. Keeping the fallback live in per-tool docs means recovery is mechanical, not a re-research-and-redesign exercise.

**Why accept occasional 1Password prompts rather than suppress.** 1Password's custom updater has no documented silent-install mode (the `updates.autoUpdate` key is check/off binary). The choice is between occasional vendor prompts (default) and never-checks + operator-cadence manual updates. The operator's stated "least action required" preference reads as occasional prompts winning over routine manual action. Fallback to full suppression is in the per-tool doc if that read turns out wrong.

**Why the investigation-guidance checklist is in the ADR rather than a separate doc.** It operationalises the boundary rule. Splitting it from the rule risks future contributors evaluating against the rule's letter without the spirit. The cost is ADR length; the benefit is a single canonical reference for "what does adding a fourth cask look like." If it becomes large enough to harm ADR scannability, split then.

## Consequences

- ✓ For Sparkle apps shipping archive-style enclosures, updates land continuously at vendor cadence; no operator action required, no admin auth at the Sparkle layer — subject to the macOS-level prompt surfaces in §Update mechanism stance.
- ✓ No surprise updates from brew during activation (`onActivation.autoUpdate = false`, `mutableTaps = false`).
- ✓ The declared cask list is the single source of truth; drift surfaces at activation (`cleanup = "uninstall"`).
- ✓ Cross-platform GUI apps compose cleanly: NixOS desktops use nixpkgs / NixOS modules, Darwin uses cask. No fight to unify the install mechanism.
- ✓ Boundary rule is principled and reusable; clause 2 is bounded by named-degradation specificity rather than ad-hoc judgement. Investigation guidance gives a future contributor the playbook.
- ✗ 1Password will still prompt occasionally for updates. Accepted on "least action" grounds; documented fallback if prompt frequency becomes intolerable.
- ✗ Apple-side prompts (System Extension reinstall, Gatekeeper / TCC first-encounter) are not suppressible from this layer. If a managed app surfaces one, that's a vendor + Apple matter; per-tool doc records the surface but the fix isn't in our config.
- ✗ If Mosyle interferes with Sparkle's `/Applications/` writes (uncertain at design time), the operator gets prompted *anyway* until the per-tool doc's suppression fallback is wired. Recovery is mechanical.
- ✗ `cleanup = "uninstall"` means any cask the operator manually `brew install --cask`s outside this config disappears at next activation. Intentional (whitelist), but a real ergonomic cost for one-off experimentation. Mitigation: experiment via `nix shell` or scratch space.
- ⚠ Long stretches without `brew` invocation mean tap/cache state isn't exercised. Mitigated by `mutableTaps = false` pinning tap inputs to the flake — but if Homebrew releases a breaking-change update during a gap, the next `darwin-rebuild` activation surfaces it.
- ⚠ **Migration trigger 1 — nixpkgs gains a clean Darwin equivalent for a managed cask.** Re-evaluate the cask choice (clause 1 fails outright, or clause 2's named degradation no longer holds).
- ⚠ **Migration trigger 2 — fourth cask requested.** Walk §Investigation guidance. Evaluate against the two-clause rule. Do not relax the "no third-party taps" scope exclusion without amending this ADR.
- ⚠ **Migration trigger 3 — Mosyle prompt-storm in practice.** Per-tool docs own the fallback. If a managed app starts prompting routinely on Mosyle-attributable `/Applications/` writes (distinct from Apple-OS-level prompts), switch its keys to suppression-mode and adopt the manual update path documented in its per-tool doc.

## Implementation

This ADR drafts the boundary; the module + flake input + per-tool docs land in the same issue (#13).

(Slice 1 was the mac-mini host scaffold, PR #169.)

1. **This ADR + three per-tool docs** (`docs/desktop/ghostty.md`, `docs/desktop/tailscale.md`, `docs/desktop/1password.md`) + `docs/desktop/README.md` scope update — slice 2a.
2. **`nix-homebrew` flake input + `modules/darwin/homebrew.nix` + `home/darwin/ghostty.nix` + `hosts/mac-mini/default.nix` import** — slice 2b. Build check: `nix flake check` and `nix build .#darwinConfigurations.mac-mini.system`. First activation on the live mac-mini.
3. **Verification** — confirm `brew list --cask` matches the declared list; confirm Sparkle keys via `defaults read com.mitchellh.ghostty SUAutomaticallyUpdate` (should print `1`; the load-bearing setting for Ghostty is `auto-update = "download"` in its config, but the on-disk `1` confirms the belt-and-braces hedge is in place — see ghostty.md §Configuration) and the equivalent on `io.tailscale.ipn.macsys`. (Run as `system.primaryUser`, or prefix with `sudo --user=<primary-user> -- defaults read …` from a different account.) After 2-3 weeks of normal use, expect zero update prompts for Ghostty and `tailscale-app`; one or zero for 1Password (vendor cadence: ~quarterly). Any deviation tied to Mosyle policy on `/Applications/` writes (the load-bearing uncertainty) trips the per-tool doc's suppression-mode fallback. Apple-OS-level prompts (System Extension reauthorization, Gatekeeper / TCC first-encounter) are expected occasionally and do not trigger a fallback — they're documented as unsuppressible in §Update mechanism stance.

## References

- ADR-027 — foundation + bundles model; this module is a standalone under that model.
- ADR-028 / ADR-029 — desktop-env stack on NixOS desktops; per-tool selection pattern (`docs/desktop/<tool>.md`) followed here for the cask-managed apps.
- `docs/workflow.md` — doc-before-code rule cited under §Day-one casks and §Investigation guidance.
- `docs/taxonomy.md` — most-communicative-term rule cited under §Module placement.
- PRD §2.2 — Mosyle / auto-update carve-out (the original motivation; this ADR's stance pivots to "trust silent-install where the path is clean + document fallback" within that PRD constraint).
- #11 — epic.
- #13 — this work.
- #15 / PR #169 — mac-mini host scaffold; this ADR's module imports into it.
- #16 / PR #174 — Darwin bootstrap runbook (merged); runbook will reference this module's install + verification commands in a follow-up sweep.
- #167 / PR #177 — Ghostty terminfo / `pkgs.ghostty` upstream Darwin gap. Closed by moving the terminfo derivation to `modules/nixos/`; the upstream Linux-only `meta.platforms` remains, which is why Ghostty itself still requires the cask on Darwin.
- `nix-homebrew` source — https://github.com/zhaofengli/nix-homebrew
- nix-darwin source — https://github.com/nix-darwin/nix-darwin
- nix-darwin manual (`homebrew` section) — https://nix-darwin.github.io/nix-darwin/manual/index.html
- Homebrew Cask Cookbook (`auto_updates`, `--greedy`) — https://docs.brew.sh/Cask-Cookbook
- Sparkle customisation reference — https://sparkle-project.org/documentation/customization/
- Sparkle package-updates documentation (`.pkg`-enclosure constraints) — https://sparkle-project.org/documentation/package-updates/
