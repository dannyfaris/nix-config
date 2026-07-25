# Ephemeral root ("erase your darlings") on NixOS — prior art for #553

Status: **research note, not a decision.** Captured from a deep-research run (5 angles, 18 unique sources fetched, 25 claims adversarially verified at 3 votes per pass, 24 confirmed / 1 killed) on 2026-07-25; run ID `wf_b7929076-355`. Provenance caveats: the run's synthesize stage failed twice on structured-output truncation, so this synthesis was performed in-session directly from the run's journaled verdicts — every vote count below is from the run's verifiers, and claims that were extracted but *not* adjudicated in the top-25 verification pass are explicitly marked **UNVERIFIED**. A workflow resume re-adjudicated a subset of claims in a second independent 3-vote pass, so counts above 3-0 (5-0, 6-0) are two merged passes on the same claim, with null votes dropped. Sources are listed in §10. Asks: for the fleet's move to ephemeral `/` from bootstrap on disko-provisioned btrfs hosts (persistent `/home`, old-root snapshot retention, prior-art-seeded persist whitelist), what does the field already know? Feeds #553 (ephemeral root), #633 (audit probe), #631 (Alcyone bootstrap). Survey-bounded — see §8.

## 1. Verdict

**Nothing in the tentative direction is novel, and one deliberate part of it is rarer than expected.** All three mechanisms (tmpfs-root, btrfs blank-snapshot rollback, the impermanence module for whitelisting) are mature, attested, and combinable; the btrfs-rollback + impermanence-for-whitelisting combination on disko is a well-trodden path with worked examples. The canonical system persist whitelist is thoroughly documented and converges across independent sources — it can be seeded, not discovered. Persistent `/home` is the *baseline* of the originating pattern, not a compromise. Two findings cut the other way: (a) **old-root retention-then-purge is minority practice** — most prior art destroys the previous root at boot; one 2025 guide implements exactly the proposed timestamped-archive-with-30-day-purge, but documents no recovery workflow (**UNVERIFIED** — see §3); and (b) **desktop-session state (greetd, Wayland compositors, portals) is absent from every fetched whitelist** — the fleet's niri surface will generate genuinely novel whitelist knowledge. There is no prior art for the module-owns-its-state declaration convention, and no built-in audit tooling — practitioners hand-roll `nix eval`-driven diffs, which is direct prior art for #633's probe mechanism.

## 2. Mechanism landscape (research question 1)

Three mechanisms, all attested in long-form worked examples:

- **ZFS blank-snapshot rollback in initrd** — the originating "erase your darlings" pattern (Graham Christensen, 2020). Root is rolled back to an empty snapshot via `boot.initrd.postDeviceCommands`; persist paths bind-mount/symlink from a durable dataset. Vote 6-0, primary source. ZFS-specific; the *shape* transfers to btrfs.
- **tmpfs-as-root** — `/` is a RAM-backed tmpfs (Elis Hirwing, 2020; also the NixOS wiki's primary documented mechanism, 3-0). Works because NixOS only strictly needs `/boot` and `/nix` to boot — everything else is symlinks into the store (3-0, wiki). Costs RAM; loses everything on power cut.
- **Hand-rolled btrfs blank-snapshot rollback** — capture a read-only `root-blank` snapshot at install; every boot, delete the live root subvolume and re-snapshot from blank (mt-caret 2020, 3-0; Guekka 2023, 3-0; NotAShelf 2025 as a systemd-stage-1 initrd service rather than `postDeviceCommands`, 3-0).

Practitioners choose btrfs rollback over tmpfs for two stated reasons: no RAM cost (Guekka, 3-0) and the previous root being *recoverable* after an unclean shutdown, which tmpfs physically cannot offer (NotAShelf, 3-0). Both map directly onto the fleet's btrfs/disko substrate.

The **nix-community impermanence module** is orthogonal to the wipe mechanism: it implements the *whitelist* side declaratively — `environment.persistence` entries become bind mounts (directories, and files that already exist in persistent storage) and symlinks (files that don't) (5-0 and 3-0, primary). It supports both tmpfs and btrfs setups (5-0). Guekka's stack — hand-rolled btrfs rollback for the wipe, impermanence only for declarative whitelisting (3-0) — is the closest published analogue of the direction #553 is heading. Maintenance status: active (latest commit 2026-01-27), ~1.8k stars, single maintainer, ~106 open issues — **UNVERIFIED** repo-metadata detail.

**Failure stories** (the field's scar tissue, all initrd-timing-related):

- Guekka's rollback script originally ran from `boot.initrd.postDeviceCommands` and was moved to `postResumeCommands` after data-loss concerns — a documented iterate-after-scare story (3-0).
- The same race formalised: an initrd rollback that touches the root subvolume *before the kernel has checked swap for a hibernation image* corrupted a laptop's filesystem repeatedly; mitigation is a clean-shutdown guard file the initrd checks before rolling back, or moving to systemd stage-1 (tbx.at, 2023 — **UNVERIFIED** but detailed and mechanism-plausible). Fleet exposure is low (desktops don't hibernate; the laptop is Darwin and out of mechanical scope) but the guard-file pattern is cheap insurance and the systemd-stage-1 route (NotAShelf's, verified 3-0) sidesteps the class.
- impermanence requires persistent volumes be marked `neededForBoot` or the setup breaks — now asserted by the module itself as of 2026-01-27 (3-0, primary).
- Bind-mount overhead is real enough to have motivated a filesystem-native (snapshot + rsync-back, no bind mounts) impermanence proposal — experimental, no maintainer commitment (impermanence #255, forum-quality); the three-year tmpfs practitioner likewise suspects bindfs I/O degradation (**UNVERIFIED**). Relevant to large mutable trees like `/var/lib/docker` — consider persisting those as real disko subvolume mounts rather than impermanence bind mounts.

## 3. Snapshot retention (research question 2)

The proposed archive-not-delete stance is **rarer than assumed**. The canonical implementations destroy the previous root at every boot: mt-caret deletes and recreates it, NotAShelf keeps a single blank snapshot with no archival tier, and the ZFS original rolls back with no retention (all **UNVERIFIED** as explicit claims, but visible in the verified mechanism descriptions). Exactly one fetched source implements the proposed pattern: tsawyer87's 2025 btrfs guide renames the old root into `/btrfs_tmp/old_roots/<timestamp>` at boot and purges archives older than 30 days via `find -mtime +30`, with a recursive-subvolume-delete helper for the purge (**UNVERIFIED** — extracted but not in the adjudicated top-25). Notably, that guide documents **no recovery workflow** from a retained root — the archive exists but reading state back out of it is left as an exercise. Implication for #553: the retention half is prior-arted, the *recovery runbook* half is not — it needs designing, not copying. For retention-cost accounting, `dim-geo/btrfs-snapshot-diff` estimates the space a snapshot deletion would free without quota groups (**UNVERIFIED**).

## 4. The canonical persist whitelist (research question 3)

The strongest convergence in the run. Independent sources (module example, wiki, three blogs, two Discourse threads) agree on a baseline, so #553's whitelist can be *seeded* rather than discovered:

| Path | Why | Attestation |
|---|---|---|
| `/etc/machine-id` | systemd journal is keyed by it — lose it and `journalctl` can't read prior boots | 3-0 ×3 independent |
| `/etc/ssh/ssh_host_*_key` | host identity; every client screams on regeneration | 3-0 ×4; module example covers only ed25519+RSA — other algorithms need adding (3-0) |
| `/etc/NetworkManager/system-connections` | WiFi/VPN credentials | 3-0 ×4 |
| `/var/lib/NetworkManager` (`secret_key`, leases) | stable RFC7217 IPv6 addresses; DHCP leases | 3-0 (tuxes.uk) |
| `/var/lib/bluetooth` | pairings | 3-0 ×3 |
| `/var/lib/nixos` | uid/gid maps | 3-0 ×3 |
| `/var/lib/systemd/coredump`, `/var/lib/systemd/timers` | crash forensics; `Persistent=true` timers need last-run stamps | 3-0 ×2 |
| `/var/log` | journal + everything else | 3-0 ×2 |
| `/var/db/sudo` | sudo lecture/timestamp state | 3-0 (NotAShelf) |
| `/var/lib/tailscale` | node key — else re-auth every boot | Guekka, **UNVERIFIED** (mechanism obvious) |
| `/var/lib/docker`, `/var/lib/lxd` | images + volumes | 3-0 (mt-caret); see §2 re bind-mount overhead |
| ACME certs, WireGuard keys | rate-limited / identity material | 6-0 (grahamc) |
| `/etc/adjtime`, ALSA state, CUPS, LVM archives, PKI bundle, per-user dconf | long tail, host-dependent | 3-0 (mt-caret) + forum |

Secrets directories are persisted with explicit restrictive modes — `.ssh`/`.gnupg` as mode 0700 is the documented convention (3-0 via module example + Discourse).

**The gap:** no fetched source enumerates desktop-session state — nothing on greetd, Wayland compositor state, xdg-desktop-portal, or pipewire. A 2026 Discourse thread explicitly soliciting "learned the hard way" persist lessons yielded no desktop surprises either (forum). Two readings: the desktop tail is genuinely small (most of it is under `$HOME`, out of scope for ephemeral-`/`), or nobody has written it down. Either way, Alcyone runs ahead of the literature here — the strongest argument the run produced for retaining #633's observation idea in some form even after enforcement lands; its disposition stays with #553/#633.

## 5. `/home` in the wild (research question 4)

- **Persistent `/home` is the baseline, not a fallback.** The originating erase-your-darlings design keeps `/home` on a separate persistent dataset — ephemeral `/home` was never part of the pattern (6-0, the run's strongest vote). NotAShelf explicitly declines to cover ephemeral `/home`, labelling it "Silly" (3-0).
- **The counterexample is real but singular:** the tuxes.uk author has run mostly-ephemeral `/home` for three years across five machines (desktop, laptop, NAS, router, VPS — per the OSNews rehost, **UNVERIFIED**), with a curated `~/persist` island (GPG keys, Yubikey SSH, password-store, Signal, restic cache) and a deliberately stateless Firefox profile (3-0). Reports no major breakage in three years but expects latent failure modes (**UNVERIFIED**).
- **No documented auth-loss stories surfaced** — no keyring, passkey, or browser-profile disaster writeups anywhere in the fetched set; even Hirwing's tmpfs-as-home post documents mechanism, not failure experience (**UNVERIFIED** negative results). Absence of evidence, not evidence of absence: the auth-cliff risk identified in the #553 discussion remains unlitigated by prior art, which means adopting ephemeral `/home` would be running ahead of the field's documented experience, not following it.
- **Middle-ground disciplines exist** (both forum-quality): a read-only `/home` root with XDG redirection, so apps *can't* sprawl untracked state; and an inverse whitelist — symlink intentional files into `~/.persist` so anything not pointing there is known to be app-created state. Both deliver declaration-discipline without deletion.
- **A recurring classification gotcha:** Firefox, Electron apps (Discord, Signal), and npm mix cache with config under `~/.config` and ignore `XDG_CACHE_HOME`, defeating clean persist/discard classification; one ZFS practitioner had to redirect caches after snapshot storage filled (forum). Relevant to any future `/home` scheme *and* to snapshot-retention sizing.

## 6. Declaration discipline and audit (research question 5)

- **"What actually needs persisting?" is a recognised open problem with no built-in tool** — impermanence users hand-roll audit scripts (3-0, impermanence #240).
- The documented approach reads persistence declarations straight out of the evaluated config — `nix eval` over `environment.persistence` directories/files, per-user and home-manager entries, plus disko subvolumes — and prunes those paths from a live `find` traversal, surfacing undeclared state (3-0, #240). **This is #633's probe mechanism, already designed by the field**; a `diff-root` utility serves the same role for another practitioner (forum).
- The three-year practitioner frames the allowlist itself as the forcing function that pushes undeclared state into declarative config, with no automation on top (**UNVERIFIED**).
- **No prior art surfaced for module-owns-its-state** — a NixOS module declaring its own persist paths alongside its config. impermanence centralises declarations at the host level. The convention #553 proposes appears to be distinctive; the nearest cousin is the inverse-whitelist `~/.persist` idea (§5). Open, in the RFC-001 sense: worth designing, nothing to copy.

## 7. Refuted claim (for transparency)

One claim was killed 0-3: that the tuxes.uk author's own mechanism is tmpfs-root + impermanence. Verifiers found the article describes tmpfs as "the simplest implementation" generically and never states the author's mechanism first-person; the OSNews rehost asserts tmpfs directly but was not independently adjudicated. Of the author's other claims, only the adjudicated one survived on its own votes (the `~/persist` island + stateless Firefox, 3-0, §5); the three-year/five-machine/no-breakage details remain **UNVERIFIED** — only the mechanism attribution was affirmatively killed.

## 8. Caveats

Survey-bounded: 18 unique sources, skewed to blogs and the impermanence ecosystem; German/Japanese-language NixOS content and non-NixOS ephemerality (Fedora Silverblue, ChromeOS internals) were not swept. Vote counts are the run's 3-vote adversarial passes (two merged passes for re-adjudicated claims — see Status header) — **UNVERIFIED** items were extracted from fetched sources but fell outside the top-25 adjudication and should be re-checked before load-bearing use (the tsawyer87 retention pattern especially, since §3 leans on it). Dates matter: the tmpfs posts are 2020; the btrfs-with-retention guide is 2025; the impermanence assertion landed 2026-01. The desktop-state gap (§4) is a *negative* finding and inherently weaker than a positive one.

## 9. Open questions

- What does a recovery runbook from a retained old root actually look like (mount where, extract how, promote how)? No source documents one (§3).
- Does the bind-mount overhead complaint (#255, bindfs anecdote) reproduce on this fleet's workloads, and does it justify subvolume-mount persistence for `/var/lib/docker`? Empirical, per the repo's set-≠-enforced rule.
- What *is* the desktop-session persist tail on a niri + greetd + portals host? Nobody has published it; Alcyone will be the primary source (§4).
- Is there prior art for per-module persist declaration in any large public Nix config (as opposed to the module ecosystem)? Not swept at the individual-config level (§6).

## 10. Sources

Primary:

- [Graham Christensen — Erase your darlings](https://grahamc.com/blog/erase-your-darlings/) (2020-04-13) — the originating ZFS pattern.
- [nix-community/impermanence](https://github.com/nix-community/impermanence) — the module; README persist-whitelist example; `neededForBoot` assertion.
- [impermanence #240 — auditing undeclared state](https://github.com/nix-community/impermanence/issues/240) (2024-12) — the `nix eval`-driven audit approach.
- [impermanence #255 — filesystem-native (btrfs) implementation proposal](https://github.com/nix-community/impermanence/issues/255) (2025-01) — bind-mount overhead motivation; experimental.

Secondary:

- [NixOS wiki — Impermanence](https://wiki.nixos.org/wiki/Impermanence) (fetched revision 2025-09-14).
- [dim-geo/btrfs-snapshot-diff](https://github.com/dim-geo/btrfs-snapshot-diff) — snapshot retention-cost accounting.

Blogs (worked examples and experience reports):

- [Elis Hirwing — tmpfs as root](https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/) (2020-05) and [tmpfs as home](https://elis.nu/blog/2020/06/nixos-tmpfs-as-home/) (2020-06).
- [mt-caret — Encrypted btrfs with opt-in state](https://mt-caret.github.io/blog/posts/2020-06-29-optin-state.html) (2020-06) — initrd btrfs blank-snapshot rollback.
- [Guekka — NixOS server part 1](https://guekka.github.io/nixos-server-1/) (2023-02) and [part 2](https://guekka.github.io/nixos-server-2/) (2023-05) — btrfs rollback + impermanence-for-whitelisting; tailscale persistence; `postDeviceCommands` → `postResumeCommands` iteration.
- [tbx.at — Ephemeral rootfs corruption](https://tbx.at/posts/ephemeral-rootfs-corruption/) (2023-06) — hibernation-race corruption + guard-file mitigation.
- [NotAShelf — Impermanence on NixOS](https://notashelf.dev/posts/impermanence) (2025-02) — systemd-stage-1 btrfs rollback; against ephemeral `/home`.
- [b.tuxes.uk — Three years of ephemeral NixOS](https://b.tuxes.uk/three-years-of-ephemeral-nixos.html) (2025-02) and the [OSNews rehost](https://www.osnews.com/story/141701/three-years-of-ephemeral-nixos-my-experience-resetting-root-on-every-boot/) (2025-02) — the mostly-ephemeral-`/home` experience report.
- [tsawyer87 — btrfs impermanence](https://tsawyer87.github.io/posts/btrfs_impermanence/) (2025-06) — the timestamped old-root archive with 30-day purge.

Forums:

- [Discourse — Nixologists of impermanence, what do you persist?](https://discourse.nixos.org/t/nixologists-of-impermanence-what-do-you-persist/78524) (2026-06).
- [Discourse — How do you organize your /persist?](https://discourse.nixos.org/t/how-do-you-organize-your-persist/28256) (2023-05) — inverse-whitelist `~/.persist`, read-only home root, Electron cache gotchas.
