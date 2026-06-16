# Google Chrome

Operator's daily-driver browser on `mac-mini`. Picked because it
is the browser the operator already uses day-to-day — Workspace,
Meet, work SSO, the bookmark set, the extension set all already
live there. Selection-by-incumbency; no comparison weigh-up needed.

## Selection

Darwin: Homebrew cask `google-chrome`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

Update stance: **silent-via-Keystone** (the Google equivalent of
the Sparkle pattern landed for Ghostty / Tailscale). The
suppression fallback is documented below for the day Mosyle
escalates `/Applications/` writes.

## Rationale

It's the browser the operator runs. Switching browsers is a
separate (larger) decision and not in this PR's scope.

**MAS unavailable** — Google does not distribute Chrome via the
Mac App Store. Rejected at ADR-031 Step 0; clause 3 cannot apply.

**Clause-2 carve-out, framed operationally.** `pkgs.google-chrome`
is available on `aarch64-darwin` and `x86_64-darwin`, and its
`src.url` is the official `dl.google.com` `.dmg` — the same
binary the Homebrew cask installs. The cask is chosen because
the nixpkgs Darwin derivation has a **named, load-bearing
degradation**:

- **Named integration:** Chrome's vendor-managed auto-updater is
  Keystone (`com.google.Keystone.Agent`), a launchd-managed agent
  that writes updates to `/Applications/Google Chrome.app` on a
  ~5h cadence. Keystone is the load-bearing mechanism keeping a
  security-sensitive binary current with weekly CVE patches.
- **Named degradation:** `pkgs.google-chrome` on Darwin installs
  `Google Chrome.app` under the Nix store — its `installPhase`
  is `cp -r *.app $out/Applications/`, so the `.app` lives at
  `/nix/store/...-google-chrome-X.Y.Z/Applications/Google Chrome.app`.
  Keystone cannot update an immutable store path. The
  derivation acknowledges this by wrapping the binary with
  `--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'`,
  which (per the derivation's own comment) *disables auto updates
  and the browser outdated popup*. Result: a Chrome that **never
  updates** until the operator runs `nix flake update` + `nh
  darwin switch`. That directly defeats Stance A's rationale
  (silent security patches on a security-load-bearing binary)
  and shifts the operator to bump-cadence updates — strictly
  worse than the cask + Keystone fallback.
- **Named verification path:** if a contributor wants to flip to
  `pkgs.google-chrome`, verify: (1) operator-cadence flake bumps
  land Chrome updates within an acceptable CVE window
  (operator's definition), (2) browser native-messaging hosts
  expecting `/Applications/Google Chrome.app` (1Password's
  browser integration, hardware-key integrations, etc.) still
  resolve correctly against a `/nix/store/` path. If both pass,
  clause 2's degradation premise dissolves and ADR-031 Migration
  trigger 1 applies.

**`pkgs.chromium` — different binary, not a substitute.** No
Google sign-in services, no Widevine; not viable for daily-driver
work. Out.

## Alternatives considered

**MAS** — not on MAS. Rejected at ADR-031 Step 0.

**`pkgs.google-chrome` on Darwin** — viable mechanism; carved out
on the operational grounds above (Keystone neutered by
`--simulate-outdated-no-au`). Worth revisiting as a follow-up if
a contributor wants to verify the equivalence test in §Rationale.

**`pkgs.chromium`** — different binary; lacks Google sign-in
services and Widevine. Not a substitute for the operator's work
workflow. Out.

**Firefox / Arc / Safari** — out of scope; switching
browsers is its own decision.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "google-chrome" ];
```

No `CustomUserPreferences` keys in the default configuration —
Keystone runs on its vendor default. (Sparkle SU\* keys do not
apply; Chrome's updater is Keystone, not Sparkle.)

## Update behaviour

**Default (this config):** Keystone (`com.google.Keystone.Agent`,
installed at `~/Library/Google/GoogleSoftwareUpdate/`) runs as a
launchd-managed agent on its default cadence (~5h check
interval) and silently updates `/Applications/Google Chrome.app`.
No operator action required.

Browsers are security-load-bearing — Chrome ships patches weekly
and CVEs land routinely — so Keystone is allowed to run on its
vendor default rather than being suppressed. Operator-cadence
updates on a browser are a real attack-surface cost; the
fallback below shifts to that cadence only if Mosyle forces it.

**Fallback if Keystone's `/Applications/` writes trigger Mosyle
admin-permission prompts:**

```nix
# modules/darwin/homebrew.nix
system.defaults.CustomUserPreferences."com.google.Keystone.Agent" = {
  checkInterval = 0;
};
```

Then update Chrome manually as needed via
`brew update && brew upgrade --cask --greedy google-chrome`.
**Adopting the fallback shifts Chrome to operator-cadence
updates on a security-load-bearing binary** — the operator must
remember to run the brew command frequently enough to keep up
with CVE cadence (Chrome ships patches weekly).

**Shared-Keystone caveat.** Keystone is a single per-user
launchd agent (`com.google.Keystone.Agent`) — not a per-app
agent. Other Google Mac apps installed on this host
(today: Gemini desktop per [gemini.md](./gemini.md); potentially
future Google Drive / Earth / etc.) are managed by the *same*
agent. Flipping `checkInterval = 0` here suppresses auto-updates
**for every Google Mac app on the system simultaneously**, not
just Chrome. The manual brew recipe would then take all the
affected casks at once — currently:

```bash
brew update && brew upgrade --cask --greedy google-chrome google-gemini
```

Add any future Google cask to the same invocation if the
suppression-mode fallback is in effect.

Verify the fallback took effect:

```bash
defaults read com.google.Keystone.Agent checkInterval   # → 0
```

## Sharp edges

**Suppression key is medium-confidence.** `checkInterval = 0` is
the documented community pattern for Keystone disablement; it is
not on Google's public Chrome Enterprise MDM documentation
(which uses MCX policies rather than `defaults`-domain keys for
managed update control). Treat any post-suppression update as a
signal the key has shifted and re-verify against current Chrome
Enterprise deployment docs.

**Keystone agent domain ≠ Chrome bundle ID.** Suppression targets
`com.google.Keystone.Agent` (the launchd agent), not
`com.google.Chrome` (the browser itself). Easy to mistype.

**`google-chrome-for-testing` is a different cask.** That's the
QA build for Selenium / Puppeteer / WebDriver workflows — not
what we want. The cask name is `google-chrome` exactly.

**Cask is auto-updater-driven.** `homebrew.onActivation.upgrade = false`
in this config means brew does not push cask upgrades at
activation; Chrome stays current via Keystone instead, which is
the intended division of labour (ADR-031 §Update mechanism
stance).

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) — boundary
  rule placing Chrome on the Mac via cask under clause 2 (this
  doc owns the carve-out justification); §Update mechanism stance
  on vendor-updater reliance.
- Homebrew `google-chrome` cask source —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/g/google-chrome.rb
