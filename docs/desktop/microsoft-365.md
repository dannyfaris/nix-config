# Microsoft 365 — Word, Excel, PowerPoint, Outlook

Operator's work-supplied productivity suite on `neptune`. Picked
because it is the suite the operator's workplace runs on — work
documents, work email, work calendar all live there.
Selection-by-incumbency; no comparison weigh-up needed.

Scope is Word, Excel, PowerPoint, Outlook. **Teams, OneDrive,
OneNote, and any other Office app are intentionally out of
scope.** Teams in particular is documented under §Sharp edges
below — its MAS install failed on the 2026-06-03 mac-mini
bring-up, and the operator chose to use the Chrome web client at
teams.microsoft.com rather than chase a fix. Adding any of the
out-of-scope apps is a one-line `masApps` entry plus a doc
amendment recording the numeric ID and any per-app sandboxing
note.

## Selection

Darwin: Mac App Store via `homebrew.masApps`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 3** (MAS as a third app source). Numeric IDs:

| App | MAS ID |
|---|---|
| Microsoft Word | `462054704` |
| Microsoft Excel | `462058435` |
| Microsoft PowerPoint | `462062816` |
| Microsoft Outlook | `985367838` |

The numeric ID is the load-bearing identifier; the display-name
keys in `masApps` are cosmetic.

## Rationale

Same clause-3 shape as [slack.md](./slack.md), repeated for the
suite:

**Named advantage: bypass Microsoft's installer/updater stack
end-to-end.** The direct-download channel installs Office via
Microsoft's `.pkg` (writes to `/Applications/Microsoft <App>.app`
at install time) plus **Microsoft AutoUpdate** (MAU,
`com.microsoft.autoupdate2`), a launchd-managed agent that
writes update payloads to the same paths on its own cadence.
Both writes hit ADR-031's Mosyle-uncertainty surface.

The Homebrew casks (`microsoft-word`, etc., and the
`microsoft-office` bundle) **do** explicitly deselect MAU via
their pkg `choices` block (`"com.microsoft.autoupdate" => 0`)
and call `quit: "com.microsoft.autoupdate2"` on uninstall — so
the cask path is better than naive `.pkg` installation. But:

- the cask still runs Microsoft's `.pkg` installer, which is
  what writes the bundles into `/Applications/` (Homebrew is the
  invoker, not the writer); the install-time `/Applications/`
  write surface persists;
- the `choices`-deselection is community-maintained in the
  Homebrew cask repo, not vendor-enforced — a future Microsoft
  pkg restructure can silently break it;
- Office apps have been observed to re-install MAU on first
  launch when they detect it missing (MAU also handles licensing
  checks, not just updates), partially defeating the deselection.

The MAS variant **structurally** cannot install MAU
(sandboxing prohibits the launchd-agent install path), and
updates flow through Apple's mechanism — which under Mosyle has
not surfaced the per-app admin-permission prompts that motivated
PRD §2.2. MAS replaces the Microsoft installer/updater stack
entirely with Apple's, rather than mitigating it.

**Vendor stance:** Microsoft does not disrecommend MAS for Office
(contrast Tailscale KB-1065). Both channels are actively
maintained and feature-equivalent for personal/work-account use.

**Subscription activation is per-app on first launch, not
ID-coupled.** MAS Office detects no entitlement from the
signed-in Apple ID; subscription activation runs through the
operator's work Microsoft 365 account, signed in inside each app
on first launch (same flow as direct-download). MAS is not tied
to a personal Apple ID for licensing purposes.

**Sandboxing acceptable.** All four apps run sandboxed under MAS;
mail, calendar, file open/save, print all work within macOS TCC.
No integration we run depends on out-of-sandbox behaviour.

**No CLI gap.** Office apps ship no companion CLIs on either
channel.

**Cleanup asymmetry acceptable.** Office apps are long-lived;
the per-app `mas uninstall <id>` cost on retirement is acceptable.

## Alternatives considered

**Homebrew cask `microsoft-office`** — bundles the suite via
Microsoft's `.pkg` installer. Better than naive direct-download
because the cask's pkg `choices` block deselects MAU; rejected
because it still triggers the Microsoft `.pkg` install-time
`/Applications/` writes, and the MAU-deselection is community-
maintained and pkg-restructure-fragile (see §Rationale).

**Per-app Homebrew casks** (`microsoft-word`, `microsoft-excel`,
etc.) — same rejection. Each cask invokes the same Microsoft
`.pkg` installer with the same MAU-deselection; same install-time
`/Applications/` write surface and same fragility.

**nixpkgs** — Microsoft does not open-source Office; not
packaged. Out trivially.

**Mixing channels** (MAS for some apps, cask for others) — worst
case. Even with the casks' MAU-deselection, Office apps may
re-install MAU on first launch when one of them detects it
missing; that pulls MAU into the system to manage whatever
direct-installed apps are present. All-MAS keeps the Microsoft
installer/updater stack off the system structurally.

## Configuration

**MAS declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.masApps = {
  "Microsoft Word" = 462054704;
  "Microsoft Excel" = 462058435;
  "Microsoft PowerPoint" = 462062816;
  "Microsoft Outlook" = 985367838;
};
```

(Teams excluded — see §Sharp edges. Teams runs in Chrome at
teams.microsoft.com as the operator's working substitute.)

No `CustomUserPreferences` keys — MAS apps update through Apple's
mechanism; Sparkle / MAU / vendor-updater suppression patterns
do not apply.

## Update behaviour

**Apple, automatic.** Updates flow through the App Store on
Apple's cadence; no `system.defaults` keys to set, no MAU running
on the system, no `brew upgrade --cask --greedy` recipe needed.

**No suppression-mode fallback.** Per ADR-031 §Rationale ("Why
per-tool docs still describe a suppression-mode fallback"),
clause-3 apps neither set Sparkle/MAU-style keys nor maintain a
fallback path — Apple's update mechanism is what it is. If
updates become problematic for a specific app, the escape hatch
is to retire that MAS entry (recipe below) and re-evaluate.

## Uninstall recipes

`homebrew.masApps` entries are not removed by
`onActivation.cleanup` (Homebrew Bundle limitation; see ADR-031
§Configuration stance). Dropping any entry from
`modules/darwin/homebrew.nix` is necessary but not sufficient —
the operator must also run the corresponding `mas uninstall`:

```bash
mas uninstall 462054704   # Word
mas uninstall 462058435   # Excel
mas uninstall 462062816   # PowerPoint
mas uninstall 985367838   # Outlook
```

## Verification

After first activation:

```bash
mas list | grep -E '462054704|462058435|462062816|985367838'
```

Expect: four lines, one per app, each showing the numeric ID +
display name + installed version + Microsoft Corporation.

Functional check: open each app, sign in with the work
Microsoft 365 account, confirm — Word/Excel/PowerPoint create +
save a document to the local filesystem; Outlook fetches mail +
calendar. First-use TCC prompts (Files & Folders, camera,
microphone) are expected and one-time.

Teams runs in Chrome at teams.microsoft.com (see §Sharp edges).

## Sharp edges

**Observation window — running under Slack's clock, with
per-app caveats.** Per ADR-031 §Consequences ⚠, the clause-3
Mosyle-bypass prior was upgraded from theoretical to
under-observation when [slack.md](./slack.md) landed as the
first managed MAS app on 2026-06-02. ADR-031 frames the window
in single-app terms ("first managed MAS app's per-tool doc
commits to an observation window"), not as fleet-shared. The
operator's working interpretation here is that the *mechanism*
(MAS update path under Mosyle) is what's under observation,
shared across apps that landed in the same window — so
Microsoft 365 rides alongside Slack rather than starting a
fresh window. **Caveat:** if any Office app surfaces a
Mosyle-driven admin-permission prompt that Slack didn't, that
is distinct per-app data — the affected app's window restarts
and gets its own observation note here. If the joint window
passes clean (zero unexpected prompts across all five MAS apps
through ~2026-06-23), the prior is fleet-verified and ADR-031
§History records the fleet-mechanism reading.

**Mixed-channel hazard.** Adding any direct-installed Office
app to the system risks pulling Microsoft's installer/updater
stack back in:

- Running Microsoft's `.pkg` installer manually installs MAU
  unconditionally — that's the default Microsoft direct-download
  path.
- The Homebrew casks (`microsoft-office`, `microsoft-word`, etc.)
  deselect MAU via the pkg `choices` block, but still trigger
  the pkg's `/Applications/` writes, and Office apps may
  re-install MAU on first launch when they detect it missing
  (MAU also handles licensing checks, not just updates).

Either way, MAU then begins managing whatever direct-installed
apps coexist on the system. Keep the suite all-MAS to preserve
the clause-3 advantage structurally.

**Subscription sign-in is per-app, one-time per app.** The first
launch of each Office app prompts for Microsoft 365 sign-in.
Subsequent launches reuse the cached credentials. If the
operator signs out of one app (e.g., to swap accounts), the
other apps retain their sessions independently — no SSO across
the suite on Mac.

**Teams excluded from the suite — runs in Chrome.** The
2026-06-03 mac-mini activation surfaced an `mas install` failure
on Teams (id `1113153706` — what was thought to be the current
"new Teams" listing). The failure broke the entire `brew bundle`
run, blocking Word and Slack (which were ordered after Teams
alphabetically in the Brewfile) from installing on that
activation. Investigation suggested the listing isn't reliably
installable via mas-cli — possibly because Microsoft moved the
Teams listing for work/school accounts to a different ID,
removed it from MAS in the operator's region, or the listing
requires an interactive purchase-history association that
mas-cli can't drive. Rather than chase the right listing, the
operator chose to **drop Teams from `homebrew.masApps` and use
the web client at teams.microsoft.com in Chrome**. Functional
parity is good — Teams's web client supports chat, calls,
screen-share, meeting attendance, all the load-bearing work
flows. If a future operator wants the desktop Teams back, the
fix is: (1) verify the current MAS listing manually
(`mas search teams` to find the live ID for your Apple ID's
region; cross-check the listing at apps.apple.com points at a
native Mac app, not iPad-on-Mac); (2) ensure the Apple ID has
"Got" Teams via App Store at least once (mas-cli only installs
apps already in the purchase history); (3) add the numeric ID
back to `masApps` and re-run `nh darwin switch`.

**Outlook is the "New Outlook for Mac".** Microsoft completed the
rollout in 2024; the MAS listing now ships the new build by
default. If you remember the legacy Mac Outlook UI, this is a
different app — feature parity is largely complete, but some
advanced add-ins targeting the legacy COM-style integration
surface may not be available. None used in this operator's
workflow.

**MAS app ID is the identifier; display name is not.** The
`"Microsoft Word"` etc. keys in the attrset are cosmetic. If
Microsoft ever rebrands display names, the numeric IDs are
stable.

**Bundle IDs** (for any future `defaults` work, none needed
today). These follow Microsoft's standard scheme; **verify the
exact casing with `defaults domains | tr , '\n' | grep -i
microsoft` on an activated host before using any of these in
`system.defaults.CustomUserPreferences`** — Microsoft's domain
casing has historically varied (`Powerpoint` vs `PowerPoint`),
and an unverified key silently no-ops:
- Word: `com.microsoft.Word` (typical)
- Excel: `com.microsoft.Excel` (typical)
- PowerPoint: `com.microsoft.Powerpoint` (lowercase `point` — the
  capitalisation gotcha is real; confirmed in the wild)
- Outlook: `com.microsoft.Outlook` (typical)
- MAU (NOT installed on this config — listed for completeness so
  a future operator can grep for it if mixed-channel state
  surfaces): `com.microsoft.autoupdate2`

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule; clause 3 (MAS as third app source) added in the
  2026-06-02 amendment.
- [slack.md](./slack.md) — first managed MAS app on the fleet;
  observation window applies to this doc.
- nix-darwin `homebrew.masApps` option documentation.
- `mas-cli` — https://github.com/mas-cli/mas
