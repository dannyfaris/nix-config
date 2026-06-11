# 1Password

Operator password manager. Cross-platform; managed today on
`mac-mini` only in this configuration. NixOS desktop adoption
(metis) tracked separately and out of scope for #13.

## Selection

Darwin: Homebrew cask `1password` (1Password 8 desktop, Standalone
build — NOT the MAS variant), declared in `modules/darwin/homebrew.nix`
per [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

NixOS desktop adoption: `programs._1password-gui` + `programs._1password` (nixpkgs) — strategy landed below in §"NixOS desktop adoption (metis)" (#112); implementation not yet wired.

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

## NixOS desktop adoption (metis) — strategy & options (#112)

This section re-litigates the #112 intent per its own `[!IMPORTANT]` mandate: adopt 1Password on metis as password manager, `op` CLI, and SSH agent. The conclusion below **keeps the first two and declines the third** — it decouples the SSH-agent role from 1Password — for the reasons in Decision 2. Verified against the metis pin and live host on 2026-06-11.

### Triggering need

metis (and any future NixOS host with a desktop environment) must be able to SSH *out* to the other fleet hosts (mercury, mac-mini). Today it cannot: metis has no outbound SSH identity (`~/.ssh/` holds no private key, the agent has no identities), and only `dbf@mac` is authorized fleet-wide (`lib/operator.nix`). This is the ADR-010 "SSH between the desktop and other hosts" migration trigger, finally fired. Resolving it is in scope here.

### Decision summary

| Capability | Decision | Why |
|---|---|---|
| Interactive password manager (GUI) | **Adopt** `programs._1password-gui` | Operator already runs 1Password on macOS; one vault, one UX. The uncontested win. |
| `op` CLI | **Adopt** | Programmatic retrieval (`op read`/`op run`/`op inject`); the headless-capable half. |
| SSH agent / `SSH_AUTH_SOCK` ownership | **Decline — decouple** | Per-host ed25519 keys fit this repo's blast-radius posture better than one centralized vault key. See Decision 2. |
| metis outbound SSH | **Per-host ed25519 key**, authorized in `lib/operator.nix` | Directly satisfies the triggering need; what ADR-010 / `ssh.nix` already prescribe. |
| gcr-ssh-agent eviction | **Not needed** | Follows from declining 1Password's agent — the incumbent keeps the socket. |
| git commit signing via 1Password | **Out of scope** (defer) | Net-new; repo signs nothing today (git auth is HTTPS+token per ADR-009; commit signing was never adopted). A separate decision, not a requirement of this work. |
| sudo via `pam_ssh_agent_auth` | **Out of scope** (defer) | Net-new privilege-path change; weigh separately. |
| sops "Option C" (service-account token) | **Out of scope** (defer) | Parked behind #279's recovery-key thread and ADR-018; separate thread. |

### Decision 1 — password manager + `op` CLI: adopt

The interactive-password-manager role has no real contender. The operator already pays for and runs 1Password on macOS; the FOSS alternatives (KeePassXC, Bitwarden/Vaultwarden, `rbw`) would mean a *second* vault beside the one the operator already lives in, which `gnome-keyring.md` already rejected on "no redundant second vault" grounds. Cross-host single-vault is the whole point of #112's user story.

- GUI: `programs._1password-gui` (nixpkgs `_1password-gui`, **8.12.22** in the metis pin, unfree). The module creates the `onepassword` group, installs the setgid `1Password-BrowserSupport` wrapper for browser native-messaging, and exposes `polkitPolicyOwners` for polkit-backed unlock.
- CLI: `programs._1password` (nixpkgs `_1password-cli`, **2.34.0** in the pin, unfree). The module installs the setgid `op` wrapper in the `onepassword-cli` group — this wrapper, not a bare `op` in `systemPackages`, is what the desktop-app ↔ CLI biometric/system-auth handshake checks for.
- Operator must be added to the `onepassword` group (`users.users.dbf.extraGroups`) — the module does **not** do this, and browser/CLI integration silently breaks without it.

### Decision 2 — SSH agent ownership: decouple (THE fork)

**The contested decision, and the one that reverses #112's headline.** This is a fleet posture, not a metis-only choice: the default stance across all hosts is that 1Password is the password manager + `op` CLI, and SSH runs on per-host ed25519 keys — 1Password does not own `SSH_AUTH_SOCK`. 1Password *can* own it (`IdentityAgent ~/.1password/agent.sock`), serving a vault-held key whose private half never touches disk and whose every use is gated by an explicit approval. That's attractive. But for *this* config it loses to per-host ed25519 keys on three counts:

1. **Blast radius.** 1Password serves one centralized identity available on every host where the vault is unlocked — compromise the unlocked vault and the same key authenticates everywhere. Per-host ed25519 keys confine each host to its own identity; revoking a host is pulling one line from `lib/operator.nix`. The repo's stated posture is whitelist > blanket, tight blast radius — that points at per-host.
2. **It's what we already prescribe.** `home/shared/ssh.nix` and ADR-010 already say, in as many words: "generate fresh ed25519 keys on this box, use a passphrase + ssh-agent." Per-host identity is the established model; 1Password-as-agent would be the deviation.
3. **No agent to evict, fewer sharp edges.** Declining 1Password's agent means the incumbent `gcr-ssh-agent` (which already owns `SSH_AUTH_SOCK` on metis, pulled in transitively by gnome-keyring) simply keeps the socket — no masking, no priority race. It also dodges 1Password's SSH-agent sharp edges (agent stops when the app locks; the 6-key OpenSSH attempt limit needing `agent.toml` scoping; approval popups rendering on the physical display when you're SSH'd in while the desktop is locked).

**Recommendation: 1Password does not own `SSH_AUTH_SOCK`.** Adopt it for the password-manager + `op` roles, leave its SSH-agent feature disabled, and let SSH run on per-host ed25519 keys via the incumbent gcr-ssh-agent. This is a deliberate reversal of the issue's "password manager AND SSH agent" framing, sanctioned by the issue's own re-litigation mandate.

> Operator decision required. If single-vault convenience and key-never-on-disk outweigh per-host blast radius for you, the alternative is: enable 1Password's agent, mask `gcr-ssh-agent.socket` at the user-systemd layer, and accept the 6-key/agent.toml management. The rest of this doc assumes the decouple recommendation; flagging here so the choice is yours, not the doc's.

**Per-platform note (Darwin) — a genuine second fork, deferred.** The three things that make decoupling clean on metis — no Linux biometric, a `gcr-ssh-agent` to evict, Wayland lock-screen approval popups — largely *do not apply* on macOS, where Touch ID + 1Password's agent is the platform's strong suit. So whether the Mac follows this decouple stance or lets 1Password own `SSH_AUTH_SOCK` there is a real second decision, not a foregone copy of the metis one. It is deferred to the Phase-1 `op`-on-Mac slice (Decision 4), where Touch-ID ergonomics get weighed against the two rationales that remain fleet-wide: blast radius and model uniformity. The Mac runs the per-host `dbf@mac` key today, with no 1Password SSH integration, so deferring this changes nothing operationally.

### Decision 3 — metis outbound SSH (the triggering need)

Independent of Decision 2's verdict, the mechanism is the same:

1. Generate a fresh passphrase-protected ed25519 on metis (`ssh-keygen -t ed25519`), per ADR-010.
2. Add its **public** key to `lib/operator.nix authorizedKeys` (the single source of truth that renders authorized_keys on every host). After `nh os switch` fleet-wide, mercury and mac-mini accept metis.
3. The same pattern repeats for any future NixOS desktop host: one key per box, one new authorized line.

`gcr-ssh-agent` (incumbent) loads the key on first use and should cache the passphrase via gnome-keyring (smoke-test on first use); no new SSH agent tooling is required. Plain `ssh-agent` is the fallback if gcr-ssh-agent proves unsatisfactory.

### Decision 4 — `op` CLI install per platform

- **NixOS (metis):** `programs._1password` as in Decision 1 (setgid wrapper for desktop integration).
- **Darwin (mac-mini):** the operator currently has the GUI cask but no `op`. Wiring `op` on the Mac is a portable, off-metis slice (the natural Phase 1) and is **deferred to its own commit** — install path there (Homebrew `1password-cli` cask vs. nixpkgs) is a separate ADR-031-flavored sub-decision, not load-bearing for the metis adoption. The Darwin SSH-agent fork (Decision 2's per-platform note) rides along with this slice.

### Scope boundaries (deliberately excluded)

git commit signing, passwordless-sudo via `pam_ssh_agent_auth`, and the sops service-account-token thread are each net-new capability the repo does not have today and #112 only lists as *possible* reach. Per the project's scope discipline they are explicitly **out of scope** for this adoption and tracked as follow-on threads if the operator wants them — not folded in by default.

### Configuration sketch

```nix
# metis desktop bundle (illustrative — wire-time details verified then)
programs._1password.enable = true;
programs._1password-gui = {
  enable = true;
  polkitPolicyOwners = [ "dbf" ];   # mate-polkit is the live agent (#103)
};
users.users.dbf.extraGroups = [ "onepassword" ];  # module does NOT add it
```

```nix
# modules/shared/nix-daemon.nix — unfree whitelist (currently
# claude-code / cursor / cursor-cli). Add, never blanket allowUnfree:
"_1password-gui"
"_1password-cli"
# (verify getName output for the GUI browser-support extension at wire-time)
```

```nix
# lib/operator.nix — append metis's public key (Decision 3)
authorizedKeys = [
  "ssh-ed25519 AAAA…dbf@mac"
  "ssh-ed25519 AAAA…dbf@metis"   # generated on metis, passphrase-protected
];
```

### Sharp edges

- **Linux unlock is password-based here, not biometric.** metis has no enrolled fingerprint reader; unlock rides mate-polkit → PAM → master password. Do not promise Touch-ID-style biometrics on this host. The Dec-2025 "system authentication failed under Wayland" failure mode is pre-empted by mate-polkit being live (verified active on metis), but smoke-test it on first activation — polkit.md still flags mate-polkit's niri activation as smoke-test-pending.
- **Group membership is a silent failure.** Forgetting `extraGroups = [ "onepassword" ]` breaks browser/CLI integration with no loud error.
- **gcr-ssh-agent stays — by decision, not accident.** Under the decouple recommendation it keeps `SSH_AUTH_SOCK`; the eviction analysis in `gnome-keyring.md` / the #112 thread only applies if Decision 2 is overridden toward 1Password owning the socket.
- **Unfree package-name drift.** `lib.getName` output for the GUI's bundled browser-support extension may differ from `_1password-gui`; confirm the exact names at wire-time so the whitelist doesn't miss one.

### References

- #112 — adopt 1Password (this doc is its Phase-0 selection deliverable).
- ADR-010 — outbound SSH deferred; prescribes per-host ed25519 (Decision 2/3).
- [gnome-keyring.md](./gnome-keyring.md) — gcr-ssh-agent socket ownership; the eviction punt to #112.
- [polkit.md](./polkit.md) — mate-polkit, the live unlock dependency (#103).
- `home/shared/ssh.nix`, `lib/operator.nix` — outbound config + the authorized-key source of truth.
