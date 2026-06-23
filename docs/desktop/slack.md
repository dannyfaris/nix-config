# Slack

Operator's daily-driver chat client for work. Managed today on
`neptune` only; no Linux desktop adoption planned in this
configuration (work is macOS-side).

## Selection

Darwin: Mac App Store via `homebrew.masApps`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 3** (MAS as a third app source). Numeric app ID
`803453959`, verified against
`https://apps.apple.com/app/slack/id803453959` (Slack for
Desktop, Slack Technologies, Inc.). The ID is the load-bearing
identifier; the `"Slack"` key in `masApps` is cosmetic (the
App Store's own display name is "Slack for Desktop" — kept short
in the attrset on operator preference).

First managed MAS app on the fleet — also triggers ADR-031
§Implementation step 4 (PRD §11.3 sweep + bootstrap-runbook
update for the one-time interactive App Store sign-in).

## Rationale

**Clause-3 carve-out, named advantage: update path.** Slack's
direct-download `.dmg` ships Squirrel.Mac, which writes updates
into `/Applications/Slack.app` on its own cadence. That is
precisely the cask + auto-updater write path that bears ADR-031's
Mosyle uncertainty (§Update mechanism stance). The MAS build
bypasses Squirrel entirely — updates flow through Apple's
mechanism, which under Mosyle has not historically surfaced the
per-app admin-permission prompts that motivated PRD §2.2.

Slack is a long-lived app the operator does not expect to retire,
so the `homebrew.masApps` cleanup asymmetry (no automatic
uninstall when an entry is dropped) is an acceptable cost.

No vendor disrecommendation of the MAS variant (contrast
Tailscale KB-1065). Slack ships and supports both channels.

**Sandboxing acceptable.** The MAS build is sandboxed; chat, DMs,
huddles, screen-share, and notifications all work within macOS
TCC. No integration we run depends on out-of-sandbox behaviour.

**No CLI gap.** Slack ships no companion CLI on either channel,
so the "MAS builds drop the CLI" hazard called out in ADR-031
§Boundary rule does not apply.

## Alternatives considered

**Homebrew cask `slack`** — clause-1 default after MAS is
rejected; rejected here because Squirrel.Mac's `/Applications/`
write path is exactly the surface clause 3 is designed to avoid
under Mosyle.

**nixpkgs** — Slack on `aarch64-darwin` / `x86_64-darwin` is not
usefully packaged in nixpkgs (the Linux package exists; the
Darwin path is not viable as a daily driver). Out.

**Browser PWA / web client** — degraded notification + huddle
experience. Not a daily-driver substitute.

## Configuration

**MAS declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.masApps = {
  "Slack" = 803453959;
};
```

No `CustomUserPreferences` keys — MAS apps update through Apple's
mechanism; Sparkle / Squirrel / vendor-updater suppression
patterns do not apply.

## Update behaviour

**Apple, automatic.** Updates flow through the App Store on
Apple's cadence; no `system.defaults` keys to set, no manual
brew recipe equivalent.

**No suppression-mode fallback.** Per ADR-031 §Rationale
("Why per-tool docs still describe a suppression-mode fallback"),
clause-3 apps neither set Sparkle-style keys nor maintain a
fallback path — Apple's update mechanism is what it is. If
updates become problematic, the escape hatch is to retire the
MAS install (recipe below) and re-evaluate under clause 1.

## Uninstall recipe

`homebrew.masApps` entries are **not** removed by
`onActivation.cleanup` (Homebrew Bundle limitation; see ADR-031
§Configuration stance). Dropping the entry from
`modules/darwin/homebrew.nix` is necessary but not sufficient —
the operator must also run:

```bash
mas uninstall 803453959
```

## Verification

After first activation:

```bash
mas list | grep 803453959    # expect: 803453959  Slack  <version>  (Slack Inc.)
```

Functional check: open Slack, sign in to the work workspace,
confirm chat + a 1:1 call + screen-share all work. (Sandboxed-app
TCC prompts on first use are expected and one-time.)

## Sharp edges

**One-time interactive App Store sign-in required.** `mas install`
can only fetch apps already associated with the signed-in Apple
ID. Before the first `nh darwin switch` that adds a `masApps`
entry, the operator must open the App Store app and sign in
manually — `mas signin` was removed from mas-cli in late 2025
(PR #1167) after Apple's account-flow changes broke the headless
path. Captured in the bootstrap runbook.

**Cleanup asymmetry is a real cost.** Unlike `homebrew.casks`,
dropping a `masApps` entry does not uninstall the app. The
uninstall recipe above must be run by hand. Acceptable for Slack
(long-lived); a heavier consideration for short-lived apps.

**Observation window — first managed MAS app.** Per ADR-031
§Consequences (⚠ clause-3 Mosyle-bypass is a strong prior, not a
fleet-verified finding), commit to a 2–3 week observation
window after first activation: zero unexpected admin-permission
prompts, zero unexpected App Store prompts during Slack updates.
If the window passes cleanly, the clause-3 prior is upgraded to
a fleet-verified finding and noted back in ADR-031's history; if
it doesn't, the per-tool doc records the surprise and we
re-evaluate.

**MAS app ID is the identifier; display name is not.** The
`"Slack"` key in the attrset is cosmetic — `homebrew.masApps`
looks up apps by numeric ID. If Slack ever rebrands the display
name, the numeric ID is stable.

**Bundle ID** (for any future `defaults` work, though none is
needed today): `com.tinyspeck.slackmacgap`.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule; clause 3 (MAS as third app source) added in the
  2026-06-02 amendment.
- nix-darwin `homebrew.masApps` option documentation.
- `mas-cli` — https://github.com/mas-cli/mas
