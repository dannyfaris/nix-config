# Noctalia v5 idle/suspend/lock on metis — adversarial design review

Status: **research note, not a decision.** Captured 2026-07-25 from an adversarial design-review pass (AI subagent; source-read against `noctalia-dev/noctalia` @ tag `v5.0.0-beta.4` = commit `4c2dcd0995f9c570c0ced95561bf5e4685e2ad1b`, plus read-only live probes on metis) during the #644 design loop. It attacks the proposed idle→suspend + lock-before-sleep design ahead of implementation. The decisions land in [`../design/noctalia-v5-migration.md`](../design/noctalia-v5-migration.md) §Design (guard script, `systemd-lock-handler`, caffeine contract, WoL deferral); this note freezes the full failure-mode analysis and mitigation ranking. F1 is the upstream caffeine bug this work reports.

---

## 1. Failure modes found

**F1 — Caffeine does not gate v5's own idle actions on metis (HIGH severity, near-certain).** Source-verified: `IdleInhibitor::syncInhibitor` (src/idle/idle_inhibitor.cpp) acquires only a logind `"idle"`-class block inhibitor when logind is present, then **destroys its Wayland idle-inhibit surfaces**. `IdleManager` (src/idle/idle_manager.cpp) never consults `IdleInhibitor` — its only suppression input is `m_screenSaverInhibitLocks` (org.freedesktop.ScreenSaver D-Bus inhibits from apps). A logind idle inhibitor does not affect niri's ext-idle-notify, so on metis (logind present) `caffeine-enable` will **not** stop Noctalia's own lock/screen_off/suspend behaviors. Mitigation B-1 (remote sessions toggling caffeine) is therefore disqualified, and this is an upstream bug worth reporting. Must be empirically confirmed post-migration (probe P4).

**F2 — No sleep delay-inhibitor in v5; external suspend races the lock (MEDIUM severity, certain).** The only `Inhibit()` call in the tree is the idle-class caffeine one (logind_service.cpp:148, args `"idle"…"block"`). v5's PrepareForSleep callback (application_services.cpp:847–868) only hides the fade overlay and does resume housekeeping — it never locks. So a bare `Before=sleep.target` unit firing `loginctl lock-session` returns as soon as logind emits the signal; the D-Bus hop to Noctalia and the Wayland hop to niri are unsynchronized with the freeze. Softening factors, verified: the lockscreen is **ext-session-lock-v1** (`lock_screen.cpp:124`, `wl_display_flush` before returning), so once niri processes the request it blanks outputs before any client paint; and queued D-Bus/Wayland messages deliver at thaw, so the session is provably locked within milliseconds of resume even in the worst case — while the monitor is still syncing. Residual exposure is small but the guarantee should still be made synchronous (design §2). Note: Noctalia's **own** `lock_and_suspend` is race-free — `lockThenSuspendDetached` queues suspend via `runAfterSessionLocked`, which fires only on the compositor's `locked` event (`handleLocked` → `tryFlushPendingAfterLocked`, with a 3 s fallback), then runs `systemctl suspend` (first command variant).

**F3 — LockedHint is unusable as a probe (LOW, certain).** v5 never calls `SetLockedHint` (repo-wide grep: zero hits); `syncSessionLocked` calls `Session.Lock` (re-emits the signal, harmless self-loop). `loginctl show-session -p LockedHint` will read `no` while genuinely locked. Any validation script keying on LockedHint is wrong. Use journal ordering + screenshot instead.

**F4 — Remote-activity blindness converts metis into a physically-present-to-wake box unless WoL is proven (HIGH severity, likely).** Live probes: `/proc/acpi/wakeup` shows `GLAN … *enabled` and `/sys/class/net/eno1/device/power/wakeup` = `enabled` (e1000e, Intel I219) — PME is armed — but the actual `Wake-on:` mode needs root ethtool (unavailable this session) and the BIOS S3-wake setting is unknowable from software. The repo declares **nothing** (`grep wol|wakeOnLan|ethtool` over *.nix: no hits), so WoL mode is whatever the driver default is, unpinned. Worse: magic packets are L2 — they cannot arrive over tailscale0; WoL only helps if an always-on LAN peer can emit them. If no such peer exists, a suspended metis is unreachable, full stop, and the SSH-guard becomes load-bearing, not defense-in-depth. Also noted: SSH-terminated-but-agent-still-running (tmux/lingering user manager — metis has a `manager`-class session, linger is on) defeats a pure who/SSH-socket check; the guard must also consider agent processes.

**F5 — Blocked-suspend semantics of an inhibitor guard (MEDIUM).** A `systemd-inhibit --what=sleep --mode=block` guard *would* gate Noctalia's suspend (it shells `systemctl suspend` → logind refuses under a block inhibitor for unprivileged non-interactive callers; polkit `suspend-ignore-inhibit` defaults to admin auth) — but it needs a daemon tracking SSH lifecycles, produces a failed-command warn/notification in Noctalia each cycle, and still misses detached agents. logind `IdleAction` is confirmed `ignore` on metis and irrelevant — Noctalia drives.

**F6 — Adjacent hazard: `HandlePowerKey=poweroff`** on metis (busctl-verified), currently masked by niri's `handle-power-key` block inhibitor in-session, and the repo's niri.nix binds no `XF86PowerOff`. So today the power key does nothing in-session (and would hard-poweroff outside it). The "power key suspends" path in the design premise doesn't currently exist; flag for the same PR or a follow-up.

**F7 — Locker-dead window.** If Noctalia has crashed, `loginctl lock-session`/`noctalia msg session lock` locks nothing and resume shows an unlocked desktop. No before-sleep hook fixes an absent locker; accept and note it (the greetd console remains the auth boundary only at boot).

## 2. Recommended design

**config.toml (Nix-templated; timeouts placeholders):**

```toml
[idle]
pre_action_fade_seconds = 0        # nobody at the desk when these fire; overlay is noise (it's hidden on PrepareForSleep anyway)

[idle.behavior.lock]
enabled = true
timeout = 600
action = "lock"

[idle.behavior.screen-off]
enabled = true
timeout = 660
action = "screen_off"

[idle.behavior.suspend]
enabled = true                     # per-host flag from hostContext → false at #387 re-role, true on Alcyone: one-line toggle
timeout = 1800
action = "command"
command = "/path/to/noctalia-guarded-suspend"
```

**Guard script (mitigation ranked first — B-4):** skip suspend if remote activity, else delegate to Noctalia's own race-free path:

```bash
ss -H -tn state established '( sport = :22 )' | grep -q . && exit 0   # live SSH
pgrep -u dbf -f 'claude|tmux' >/dev/null && exit 0                    # detached agent sessions (tune the pattern)
exec noctalia msg session lock-and-suspend                            # compositor-locked-event-gated suspend
```

Rationale for first place: no daemon, declarative (store path in config), covers detached agents (F4), and inherits F2-immunity via `lock-and-suspend`. Known limitation: v5 idle behaviors don't re-fire after a skip until input resets the timer — on a remote-use box "stays awake" is the correct failure direction. Caffeine (B-1) is disqualified by F1; inhibitor-daemon (B-2) is a worse B-4; bare generous timeout (B-3) is not a mitigation.

**Before-sleep hook (external paths):** use `services.systemd-lock-handler.enable = true` — present in the pinned nixpkgs (`nixos/modules/services/system/systemd-lock-handler.nix`; there's a NixOS test). It holds a proper logind sleep **delay** inhibitor and bridges to user-level `lock.target`/`sleep.target`. Then:

```nix
systemd.user.services.noctalia-lock-on-sleep = {
  Unit = { Description = "Engage Noctalia lock before suspend"; Before = [ "sleep.target" ]; };
  Service = { Type = "oneshot"; ExecStart = "sh -c 'noctalia msg session lock; sleep 0.3'"; };
  Install.WantedBy = [ "sleep.target" ];   # the user sleep.target the handler provides
};
```

Sleep is held (bounded by `InhibitDelayMaxUSec=5s`, probed) until the unit exits; the 0.3 s settle covers the niri round-trip since no lock-state query exists in v5's IPC (verified absent). Do **not** hand-roll a system-level `Before=sleep.target` unit — it has no user-session context and reintroduces F2.

**WoL:** declare `networking.interfaces.eno1.wakeOnLan.enable = true` (option exists) in the same change; verify per P1; document the BIOS dependency and the LAN-peer requirement.

## 3. Validation probes on metis (must-run)

- **P1 (WoL):** `sudo ethtool eno1 | grep -i wake` → expect `Supports Wake-on: …g…` and, post-change, `Wake-on: g`. If unsupported/undeclarable → suspend stance is unsafe until resolved; guard script becomes mandatory-critical.
- **P2 (Lock signal path):** `loginctl lock-session <id>` → lockscreen appears; confirms Lock-signal handling. Do **not** use LockedHint (F3).
- **P3 (guard):** with an SSH session open: run the guard script manually → exits 0, no suspend. Close SSH + no agents → dry-run variant prints the suspend branch.
- **P4 (caffeine bug confirm):** temporarily set lock timeout 30 s, `noctalia msg caffeine-enable` (commands verified: `caffeine-enable|disable|toggle`), hands off 40 s → if it locks, F1 confirmed; file upstream.
- **P5 (operator-assisted, the one real suspend):** `systemctl suspend` from an SSH session with monitor on. On resume: session shows lockscreen; `niri msg action screenshot-screen` captures the lock surface, not the desktop; then `journalctl -b --user -u noctalia-lock-on-sleep` + `journalctl -b -k | grep 'PM: suspend entry'` — unit completion timestamp strictly before suspend entry proves lock-before-sleep. Follow with the WoL wake from a LAN peer; if no LAN peer exists, record that WoL is theoretical and F4 stands.

## 4. Stance wording

Not "suspend-on-idle on metis" but: *"suspend-on-idle **guarded by a remote-activity check** (SSH + detached-agent aware), with lock-before-any-sleep via systemd-lock-handler, **contingent on runtime-verified Wake-on-LAN** (ethtool `g` + BIOS + a LAN peer able to emit magic packets); suspend behavior is a per-host flag, disabled at the #387 re-role."* Until P1/P5 pass, the stance silently trades "always-reachable dev box" for "walk-to-the-desk box" — say so in the ADR, and note F1 (caffeine) and F6 (`HandlePowerKey=poweroff`) as tracked side-findings.

*(Post-review notes, recorded at freeze time: the operator subsequently deferred WoL enablement out of scope — a future always-on LAN peer is confirmed planned, so the design records "wake requires physical presence until the WoL follow-up lands" rather than the contingency wording above, with S1 retained as a capability-only probe. The operator also chose a caffeine contract — the guard reads caffeine's logind inhibitor fingerprint as its first check, gating suspend only — making the manual switch load-bearing alongside the remote-activity checks. The design's probe IDs S1–S5 supersede P1–P5 above. The audit also corrected F2's "3 s fallback" characterisation: the timer arms only after the compositor's `locked` event, so if `locked` never arrives there is no fallback — the pending suspend simply never fires. See the design note §Design and [the de-risk audit](./noctalia-v5-derisk-audit.md).)*
