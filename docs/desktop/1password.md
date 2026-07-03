# 1Password

Operator password manager. Cross-platform; managed today on
`neptune` only in this configuration. NixOS desktop adoption
(metis) tracked separately and out of scope for #13.

## Selection

Darwin: Homebrew cask `1password` (1Password 8 desktop, Standalone
build — NOT the MAS variant), declared in `modules/darwin/homebrew.nix`
per [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

NixOS desktop adoption: `programs._1password-gui` (nixpkgs) — the desktop password manager for metis; strategy landed below in §"NixOS desktop adoption (metis)" (#112), implementation not yet wired. The `op` CLI and 1Password-as-SSH-agent were weighed there and set aside (deferred and rejected respectively).

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

This section re-litigated the #112 intent per its own `[!IMPORTANT]` mandate: adopt 1Password on metis as password manager, `op` CLI, and SSH agent. **Settled outcome (2026-06-11):** adopt the **GUI as the desktop password manager**; **defer the `op` CLI** (no current need — the only candidate use, plaintext-token cleanup, is tracked in #364 and looks better served by sops); and **reject 1Password as the SSH agent** — SSH stays on per-host ed25519 keys (Decision 2). #112 was re-scoped to the GUI slice on this basis. Verified against the metis pin and live host on 2026-06-11.

### Triggering need

metis (and any future NixOS host with a desktop environment) must be able to SSH *out* to the other fleet hosts (mercury, neptune). Today it cannot: metis has no outbound SSH identity (`~/.ssh/` holds no private key, the agent has no identities), and only `dbf@mac` is authorized fleet-wide (`lib/operator.nix`). This is the ADR-010 "SSH between the desktop and other hosts" migration trigger, finally fired. Resolving it is in scope here.

### Decision summary

| Capability | Decision | Why |
|---|---|---|
| Interactive password manager (GUI) | **Adopt** `programs._1password-gui` | Operator already runs 1Password on macOS; one vault, one UX. The uncontested win. |
| `op` CLI | **Defer** | No current workflow needs it (sops owns secrets-at-rest; git is HTTPS+token). Revisit on a concrete interactive-retrieval need; see #364. |
| SSH agent / `SSH_AUTH_SOCK` ownership | **Reject (settled)** | The "keys out of the repo" appeal was illusory, it can't be uniform fleet-wide (headless hosts), and the actual need is met by per-host keys. See Decision 2. |
| metis outbound SSH | **Per-host ed25519 key**, authorized in `lib/operator.nix` | Directly satisfies the triggering need; what ADR-010 / `ssh.nix` already prescribe. |
| gcr-ssh-agent eviction | **Not needed** | Follows from declining 1Password's agent — the incumbent keeps the socket. |
| git commit signing via 1Password | **Out of scope** (defer) | Net-new; repo signs nothing today (git auth is HTTPS+token per ADR-009; commit signing was never adopted). A separate decision, not a requirement of this work. |
| sudo via `pam_ssh_agent_auth` | **Out of scope** (defer) | Net-new privilege-path change; weigh separately. |
| sops "Option C" (service-account token) | **Out of scope** (defer) | Parked behind #279's recovery-key thread and ADR-018; separate thread. |

### Decision 1 — password manager (GUI): adopt; `op` CLI: defer

The interactive-password-manager role has no real contender. The operator already pays for and runs 1Password on macOS; the FOSS alternatives (KeePassXC, Bitwarden/Vaultwarden, `rbw`) would mean a *second* vault beside the one the operator already lives in, which `gnome-keyring.md` already rejected on "no redundant second vault" grounds. Cross-host single-vault is the whole point of #112's user story.

- GUI (**adopt**): `programs._1password-gui` (nixpkgs `_1password-gui`, **8.12.22** in the metis pin, unfree). The module creates the `onepassword` group, installs the setgid `1Password-BrowserSupport` wrapper for browser native-messaging, and exposes `polkitPolicyOwners` for polkit-backed unlock.
- CLI (**deferred** — see Decision 4): `programs._1password` (nixpkgs `_1password-cli`, **2.34.0** in the pin, unfree) would install the setgid `op` wrapper in the `onepassword-cli` group — that wrapper, not a bare `op` in `systemPackages`, is what the desktop-app ↔ CLI biometric/system-auth handshake checks for. Not wired now: no current workflow needs it.
- Operator must be added to the `onepassword` group (`users.users.dbf.extraGroups`) — the module does **not** do this, and browser integration silently breaks without it.

### Decision 2 — SSH agent ownership: rejected (settled)

**Settled: 1Password does not own `SSH_AUTH_SOCK` on any host.** SSH runs on per-host ed25519 keys; 1Password is the password manager only. This *was* the issue's headline ("password manager AND SSH agent"); it was re-litigated and rejected. The honest reasons, kept here as the record:

1. **The headline appeal was illusory.** The draw of "1Password owns SSH, so keys leave the public repo" doesn't hold — what's in the repo is *public* keys (audited: no private key material is committed), which are designed to be published. Each destination host must declare the authorized *public* keys at build time regardless of where the *private* key lives, so 1Password removes nothing from the repo.
2. **It can't be uniform fleet-wide.** 1Password's SSH agent needs the desktop app, so the headless hosts (mercury, nixos-vm) can never use it. "One vault key for all SSH" was never achievable; some hosts keep per-host keys regardless — so the whole fleet may as well.
3. **The triggering need is met without it.** The thing that started this — metis reaching mercury / neptune — is solved by a per-host ed25519 key + one authorized line (Decision 3). 1Password buys nothing for the actual requirement.
4. **Poor Linux ergonomics where it would run.** On metis the approval is GUI-bound: an SSH'd-in-while-locked or unattended signing request stalls because the prompt renders on the physical display with no TTY fallback; the agent also stops when the app locks, and the 6-key OpenSSH limit needs `agent.toml` scoping.
5. **Keeping per-host keys is zero-disruption.** The incumbent `gcr-ssh-agent` already owns `SSH_AUTH_SOCK` on metis, so nothing has to be evicted.

Blast radius (one unlocked-vault key authenticating everywhere vs. per-host isolation) is sometimes cited too, but it cuts both ways — a vault key gated by per-use approval is hard to exfiltrate — so it is not doing the deciding here; the points above are.

> Should this ever be revisited (e.g. you decide Touch-ID-to-SSH on the GUI hosts is worth it), the override is: enable 1Password's agent, mask `gcr-ssh-agent.socket` at the user-systemd layer, and accept the 6-key/`agent.toml` management and the Linux locked-session edges. Recorded for the future, not an open question today.

**Per-platform note (Darwin).** The Mac reaches the same verdict — and for an additional Mac-specific reason (sops pins an on-disk key there regardless, neutralizing the key-never-on-disk benefit) — settled in §"Darwin adoption (neptune)" below.

### Decision 3 — metis outbound SSH (the triggering need)

With 1Password's agent rejected (Decision 2), metis's outbound SSH uses a per-host key — the mechanism ADR-010 already prescribes:

1. Generate a fresh passphrase-protected ed25519 on metis (`ssh-keygen -t ed25519`), per ADR-010.
2. Add its **public** key to `lib/operator.nix authorizedKeys` (the single source of truth that renders authorized_keys on every host). After `nh os switch` fleet-wide, mercury and neptune accept metis.
3. The same pattern repeats for any future NixOS desktop host: one key per box, one new authorized line.

`gcr-ssh-agent` (incumbent) loads the key on first use and should cache the passphrase via gnome-keyring (smoke-test on first use); no new SSH agent tooling is required. Plain `ssh-agent` is the fallback if gcr-ssh-agent proves unsatisfactory.

### Decision 4 — `op` CLI: deferred

`op` is deferred on both platforms — no current workflow needs it (sops owns secrets-at-rest; git is HTTPS+token). The one candidate use, pulling the plaintext GitLab token out of `~/.config/glab-cli/`, is tracked in #364 and looks better served by sops (declarative, headless-capable) than by `op`. If a concrete interactive-retrieval need does arise, the install path would be `programs._1password` on NixOS (the setgid wrapper) and nixpkgs `_1password-cli` (or the Homebrew `1password-cli` cask) on Darwin — a future decision, not part of this adoption.

### Browser extension (Firefox) — declarative install

The GUI's headline job on metis is browser autofill, which needs the 1Password Firefox extension. It is installed declaratively via Firefox's managed-policy mechanism — home-manager's `programs.firefox.policies` feeds the wrapped package's `extraPolicies`, which renders `policies.json`, and Firefox installs the extension from its AMO id on next launch (`home/nixos/firefox.nix`).

```nix
programs.firefox.policies.ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
  install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
  installation_mode = "normal_installed";   # installs it; operator stays in control
};
```

- **Mechanism: managed policy, not NUR.** The alternative — `programs.firefox.profiles.<name>.extensions.packages` with `nur.repos.rycee.firefox-addons.onepassword-password-manager` — gives a nix-pinned, hash-checked install, but only by adding NUR (a large, community-maintained registry) as a flake input for a single addon. That cuts against this repo's tight / minimal-inputs posture. The policy route needs zero new inputs and is the standard managed-Firefox path; the cost is that it tracks AMO "latest" rather than a nix-pinned revision — acceptable, and arguably preferable, for a security-sensitive password-manager extension.
- **`normal_installed`, not `force_installed`.** `force_installed` locks the extension on and bars the operator from removing it — appropriate for a locked-down fleet endpoint, not for a personal box. `normal_installed` installs it declaratively while leaving the operator in control (explicit > implicit, without the lockdown).
- **The GUID is the addon's AMO id**, not the slug — `{d634138d-c276-4fc8-924b-40a0ea21d284}` keys the policy, while the slug `1password-x-password-manager` appears only in the `install_url`. Easy to conflate; confirm the id against the AMO API if it ever needs changing.
- **Install ≠ connection.** The policy only *installs* the extension. Autofill additionally needs the extension to reach the desktop app over native messaging, which rides the setgid `1Password-BrowserSupport` wrapper and `onepassword` group membership (Decision 1). On first launch the app shows a "connect with 1Password in the browser" prompt — approve it once.

### Scope boundaries (deliberately excluded)

git commit signing, passwordless-sudo via `pam_ssh_agent_auth`, and the sops service-account-token thread are each net-new capability the repo does not have today and #112 only lists as *possible* reach. Per the project's scope discipline they are explicitly **out of scope** for this adoption and tracked as follow-on threads if the operator wants them — not folded in by default.

### Configuration sketch

```nix
# metis desktop bundle (illustrative — wire-time details verified then)
programs._1password-gui = {
  enable = true;
  polkitPolicyOwners = [ "dbf" ];   # mate-polkit is the live agent (#103)
};
users.users.dbf.extraGroups = [ "onepassword" ];  # module does NOT add it
```

```nix
# modules/shared/nix-daemon.nix — unfree whitelist (currently
# claude-code / cursor / cursor-cli). Add the GUI, never blanket allowUnfree:
"1password"   # lib.getName of _1password-gui — its pname is "1password", not "_1password-gui"
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
- **gcr-ssh-agent stays — by decision, not accident.** Under the settled decision it keeps `SSH_AUTH_SOCK`; the eviction analysis in `gnome-keyring.md` / the #112 thread only applies if Decision 2 is ever overridden toward 1Password owning the socket.
- **Unfree package-name drift.** `lib.getName` output for the GUI's bundled browser-support extension may differ from `_1password-gui`; confirm the exact names at wire-time so the whitelist doesn't miss one.

### References

- #112 — deploy 1Password GUI to metis (this doc is its selection record); #364 — GitLab plaintext-token cleanup (the deferred-`op` candidate use).
- ADR-010 — outbound SSH deferred; prescribes per-host ed25519 (Decision 2/3).
- [gnome-keyring.md](./gnome-keyring.md) — gcr-ssh-agent socket ownership; the eviction punt to #112.
- [polkit.md](./polkit.md) — mate-polkit, the live unlock dependency (#103).
- `home/shared/ssh.nix`, `lib/operator.nix` — outbound config + the authorized-key source of truth.

## Darwin adoption (neptune) — SSH-agent verdict + `op` (deferred) (#112)

The 1Password GUI is already managed on neptune (Homebrew cask, above). This section records the Mac's verdict on the two net-new questions #112 raised — whether 1Password should own `SSH_AUTH_SOCK` here, and the `op` CLI. Both are settled: SSH stays on the existing per-host `dbf@mac` key (same as metis, plus a Mac-specific reason), and `op` is deferred. Strategy only; no code wired.

### Decision summary

| Capability | Decision | Why |
|---|---|---|
| SSH agent / `SSH_AUTH_SOCK` ownership | **Reject (settled), same as metis** | Plus a Mac-specific reason: the "key never on disk" benefit is moot — sops pins an on-disk key regardless (see below). |
| SSH outbound | **Keep the existing per-host `dbf@mac` on-disk key** | Already authorized fleet-wide and already works; no change. |
| `op` CLI | **Defer** | No current need (same as metis); #364 may cover the only candidate use via sops. Install path noted below for if/when. |

### SSH agent on the Mac — why it lands the same way as metis

On macOS the metis reasoning weakens: Touch ID + 1Password's agent is excellent, there's no `gcr-ssh-agent` to evict, and no Wayland lock-screen popup failure mode. Taken alone, that's a real pull toward letting 1Password own SSH on the Mac.

What tips it back to decouple is a Mac-specific fact: **`~/.ssh/id_ed25519` is load-bearing for sops on this host.** It is the `dbf@mac` key, and the Mac's sops age identity is derived from it (`ssh-to-age -private-key`; see `modules/darwin/sops.nix` and `.sops.yaml`). That on-disk key therefore **must** exist regardless of any SSH choice. So 1Password's headline SSH benefit — the private key never touches disk — buys little here: the disk already holds a mandatory key. Adopting 1Password's agent would mean either importing that key into the vault (same key, two homes) or generating a *second* SSH identity to manage, carrying the vault-key blast radius either way.

So the honest balance on the Mac:

- **For 1Password-owns-SSH:** Touch-ID-to-SSH ergonomics — genuinely nice.
- **Against:** fleet model uniformity (metis rejected it); the key-never-on-disk benefit is moot because sops pins an on-disk key anyway; and keeping the per-host key is zero-work (the `dbf@mac` key already authenticates everywhere). (Blast radius is a wash, as on metis.)

**Verdict: rejected on the Mac too.** 1Password is the password manager; SSH stays on the existing per-host `dbf@mac` key. The only thing forgone is Touch-ID-to-SSH, which is ergonomics, not security. The fleet posture is uniform — per-host on-disk ed25519 keys for SSH everywhere, 1Password never owning `SSH_AUTH_SOCK`.

> Should this ever be revisited: if Touch-ID-to-SSH on the Mac becomes worth a split model, the override is to enable 1Password's SSH agent on macOS (it exposes its own agent socket via `IdentityAgent`), keep `~/.ssh/id_ed25519` for sops only, and accept that metis and neptune then run different SSH-agent models by design. Defensible, but deliberately non-uniform — recorded for the future, not open today.

### `op` CLI install path (for if/when it's adopted)

`op` is deferred (see the decision summary). If it is later adopted, nixpkgs `_1password-cli` is the recommended install on the Mac — one attribute, cross-platform parity, and on macOS the desktop-app ↔ CLI biometric handshake is driven by the app, so the CLI's install path is *not* the finicky vendor-integration surface the GUI's browser native-messaging is (which is why the GUI stays a cask per ADR-031 clause 2). The Homebrew `1password-cli` cask is the fallback if the nixpkgs CLI's app-integration ever misbehaves.

### Sharp edges

- **Do not break `~/.ssh/id_ed25519`.** It is the sops decryption identity on neptune; losing or rotating it without re-deriving the age key breaks `sops -d` fleet-wide. The settled decision deliberately leaves this key exactly where it is.
- **`op` (if later adopted) is unfree.** `_1password-cli` is unfree; it would ride one `allowUnfreePredicate` entry in `modules/shared/nix-daemon.nix` (shared across both platforms), not a separate Darwin entry. Never blanket `allowUnfree`.

### References

- §"NixOS desktop adoption (metis)" above — the fleet posture and Decision 2's per-platform note this section settles.
- #112 — deploy 1Password GUI to metis (the re-scoped issue); #364 — GitLab plaintext-token cleanup (the deferred-`op` candidate use).
- `modules/darwin/sops.nix`, `.sops.yaml` — the `~/.ssh/id_ed25519`-derived age identity that pins the on-disk key.
