# Amphetamine

Keep-Mac-awake utility — overrides macOS's idle-sleep behaviour
for a chosen session length / until a chosen condition (lid
state, battery level, app running, etc.). Picked because it's
the standard tool for this job and the operator already uses it.

## Selection

Darwin: Mac App Store via `homebrew.masApps`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 3** — but by absence of alternative, not by clause-3
weigh-up.

App: "Amphetamine" by William Gustafson, ID `937984704`,
verified against `apps.apple.com/us/app/amphetamine/id937984704`
(native macOS build — Compatibility section names `macOS 10.13
or later`, not iPad-on-Mac). Free.

## Rationale

**MAS is the only channel.** Amphetamine is distributed
exclusively through the Mac App Store by developer choice. No
direct-download `.dmg`, no Homebrew cask, no nixpkgs package.
Clauses 1 and 2 do not have anything to evaluate. There is no
install-path comparison to make.

The standard clause-3 update-path advantage (bypassing Sparkle /
MAU / vendor-updater `/Applications/` writes under Mosyle
uncertainty) applies trivially — MAS is the only update
mechanism available either way.

## Alternatives considered

None. There is no other distribution channel.

## Configuration

**MAS declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.masApps = {
  "Amphetamine" = 937984704;
};
```

No `CustomUserPreferences` keys.

## Update behaviour

**Apple, automatic.** Updates flow through the App Store.

## Uninstall recipe

```bash
mas uninstall 937984704
```

(Necessary because `homebrew.onActivation.cleanup` does not
extend to `masApps` entries — see ADR-031 §Configuration stance.)

## Verification

```bash
mas list | grep 937984704
```

Functional check: launch Amphetamine, start a session, confirm
the menubar icon appears and the Mac stays awake.

## Sharp edges

**Runs under the shared MAS observation window** started by
[slack.md](./slack.md) on 2026-06-02. The *mechanism* under
observation is MAS-under-Mosyle (does Apple's update path
surface admin-permission prompts on this fleet?), shared across
apps in the window. No fresh per-app window here, same caveat
as `microsoft-365.md` §Observation window: if Amphetamine
surfaces a Mosyle-driven prompt that other MAS apps didn't,
that's distinct per-app data and the affected app's window
restarts.

**Bundle ID** (for any future `defaults` work, none needed
today): `com.if.Amphetamine`.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  clause 3.
- [slack.md](./slack.md) — first managed MAS app; observation
  window applies.
