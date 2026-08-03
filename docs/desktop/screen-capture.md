# Screen capture (non-interactive)

Non-interactive capture of a desktop host's screen, for remote/agent-assisted visual verification over SSH (#529). Covers the *screenshot* path — one command produces one image of what the display is actually showing, with no hands on the machine. The *screencast* path (a portal picker, a PipeWire stream, video into a call) is a different capability and lives in [screen-sharing.md](./screen-sharing.md); remote *control* is a third, surveyed in [remote-desktop-access.md](../design/remote-desktop-access.md). This is the lightweight read-only rung of the same want.

## Selection

**`grim`** (`pkgs.grim`, 1.5.0 at the current nixpkgs pin) as the non-interactive capture tool on the desktop hosts, installed home-side by `home/nixos/screen-capture.nix` through the `desktop-env` bundle — alcyone first by composition, not by host special-case. It is driven over SSH against the live session and writes the image to **stdout**, so the bytes leave the host in the same command that makes them.

niri's built-in screenshot actions are **kept unchanged** as the human path at the console (the `Super+Shift` chords in [keybinds.md](./keybinds.md) §Screenshots). The two paths are complementary, not competing: human at the console → niri's actions; agent over SSH → `grim`.

One niri `window-rule` declares `block-out-from "screen-capture"` on the 1Password window, so adding a screencopy client does not turn the desktop's password manager into a readable surface.

## Rationale

**The consumer is an agent over SSH, and that dictates the shape.** The capture must be non-interactive (no picker, no overlay), targetable at a chosen output, and able to deliver an image off-host. `grim` writes to stdout when the output file is `-`, so the entire pipeline is one command from the remote side and there is no on-host artifact to pull afterwards, no temp file to clean up, and nothing that interacts with alcyone's ephemeral-root persist whitelist.

**The pinned niri implements the protocol `grim` needs.** Verified in source at the pinned rev (`niri-flake` → `niri-unstable`, `feb3e43f`, `version = "26.4.0"`): `src/protocols/mod.rs` declares `pub mod screencopy;`, `src/handlers/mod.rs` carries `impl ScreencopyHandler for State` over `ZwlrScreencopyManagerV1` plus `delegate_screencopy!(State);`, and the README at the same rev says "yes, we have most of the important ones like layer-shell, gamma-control, screencopy." No portal is involved — `wlr-screencopy` is a direct Wayland protocol, so none of the `xdg-desktop-portal` machinery from [screen-sharing.md](./screen-sharing.md) is on this route.

**The credential guard binds every hands-off capture route — including niri's own.** `block-out-from = "screen-capture"` blacks the window out of `wlr-screencopy` (so `grim` sees a blank block) *and* out of niri's automatic screenshot actions. Traced in source at the pinned rev: `Action::ScreenshotScreen` (and `ScreenshotWindow`) reach `Niri::screenshot` in `src/niri.rs`, which renders with `RenderTarget::ScreenCapture`; `should_block_out` in `src/render_helpers/mod.rs` returns true for `BlockOutFrom::ScreenCapture` on any target that is not `RenderTarget::Output`, and only the interactive screenshot UI renders as `Output`. niri's wiki says the same in prose (Configuration: Window Rules §block-out-from: the setting "will still let you use the interactive built-in screenshot UI, but it will block out the window from the fully automatic screenshot actions"). Beware the stale contrary sentence in `niri-flake`'s generated option docs ("does not affect the built in screenshot tool at all") — it does not match niri 26.4.0, and the source trace above is what was checked. **Consequence for this selection: the guard is *not* a discriminator between `grim` and niri's IPC.** Both honour it; the choice rests on the paragraphs either side of this one.

**Capture must not have side effects on the operator's session.** niri's `screenshot-screen` action puts the image in the clipboard unconditionally (its `write-to-disk` flag is documented as "write the screenshot to disk *in addition to* putting it in your clipboard"). An agent capturing repeatedly during a verification loop would clobber the clipboard every time. `grim` touches no clipboard, no notification, and no disk unless told to.

**It is the smallest thing that works.** One MIT-licensed C program, one binary, no daemon, no systemd unit, no new substituter or trust delegation, and nothing added to the boot or auth path.

## Alternatives considered

**niri's own screenshot IPC (`niri msg action screenshot-screen`).** Zero new packages, and at the pinned rev it is genuinely non-interactive and more capable than its reputation: `ScreenshotScreen` takes `--path` (must be absolute), `--write-to-disk`, and `--show-pointer`, and `ScreenshotWindow` additionally takes `--id`. Passed over for the *agent* path on three counts. (1) The clipboard write is unconditional — every capture in a verification loop clobbers the operator's clipboard, and there is no flag that turns it off. (2) It writes the image to a file (its configured screenshot path, or `--path` if given), so the artifact has to be fetched and then cleaned up in extra steps, where `grim -` puts the bytes on stdout inside the single SSH command. (3) It is niri-only, where `wlr-screencopy` is protocol-generic: the same invocation carries into the #555/#559 sibling contexts (microVM guests, headless CI VMs) wherever the guest speaks the protocol, and an IPC-shaped answer would have to be re-solved there.

Two things that look like counts against it and are *not*. The **credential guard** is neutral — niri's automatic screenshot actions honour `block-out-from` exactly as `grim` does (§Rationale), so it distinguishes nothing. **Socket discovery** is neutral too: niri imports `NIRI_SOCKET` into the systemd user manager and the D-Bus activation environment in the same `systemctl --user import-environment` call as `WAYLAND_DISPLAY` (`src/main.rs` at the pinned rev — niri itself does this, not `niri-session`, which only unsets the pair on exit), so `systemctl --user show-environment | sed -n "s/^NIRI_SOCKET=//p"` is the same one-liner used below and is refreshed on every compositor start. The socket is indeed named `niri.<wayland-display>.<pid>.sock`, but nothing has to be globbed or re-globbed.

With the guard and discovery both neutral the gap is narrower than it first appears, but the three counts above are real and none is a knob the caller can turn: `grim` is the pick for the agent path. niri's screenshot actions stay, unchanged, as the human path at the console.

**The `xdg-desktop-portal` ScreenCast stack** already present for screen sharing. Interactive by design (the portal shows a picker), stateful (a PipeWire stream to consume), and aimed at video. Wrong shape for "one image, no hands."

**`wayshot` and friends.** Same `wlr-screencopy` mechanism as `grim`, smaller user base, no distinguishing capability here. No reason to pick the less-travelled implementation of the identical idea.

**`slurp`.** Interactive region selection — the exact thing the agent path must not require. Not adopted; if a human ever wants region-select outside niri's own overlay, that is a separate, later call.

**The remote-desktop route (Sunshine / wayvnc).** A much larger capability with privileged plumbing (`cap_sys_admin`, uinput, forced EDID) — see [remote-desktop-access.md](../design/remote-desktop-access.md). Deliberately kept separate: this issue is the read-only rung, and it should not be blocked behind the interactive one.

## Configuration

**Package** — `home/nixos/screen-capture.nix` adds `pkgs.grim` to `home.packages`, imported by `home/nixos/bundles/desktop-env.nix`. Home-side because the consumer is the operator's own session: capture works precisely because the SSH login is the same uid that owns the compositor's socket.

**The remote invocation.** `WAYLAND_DISPLAY` is not set in an SSH shell and must be supplied; `XDG_RUNTIME_DIR` normally is, via `pam_systemd`.

```bash
# From a host with an SSH edge into alcyone (neptune, alnair — lib/operator.nix sshEdges).
ssh alcyone 'export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"; \
  WAYLAND_DISPLAY=$(systemctl --user show-environment | sed -n "s/^WAYLAND_DISPLAY=//p"); \
  if [ -z "$WAYLAND_DISPLAY" ]; then \
    for s in "$XDG_RUNTIME_DIR"/wayland-*; do \
      [ -S "$s" ] || continue; \
      WAYLAND_DISPLAY=${s##*/}; break; \
    done; \
  fi; \
  export WAYLAND_DISPLAY; grim -' > alcyone.png
```

**Do not hardcode `wayland-0`.** This fleet's session socket has been `wayland-1`, and guessing `wayland-0` is exactly the trap that made the Noctalia IPC call silently no-op from SSH (probe V5, [noctalia-v5-migration.md](../design/noctalia-v5-migration.md)). `systemctl --user show-environment` is the primary discovery; the `"$XDG_RUNTIME_DIR"/wayland-*` glob above is the fallback, mirroring the socket-glob idiom the `theme` CLI already uses. The `[ -S "$s" ]` test is what makes the fallback safe: it skips the `.lock` sibling, and it also skips the pattern itself when the glob matches nothing (POSIX shells leave an unmatched glob unexpanded, which would otherwise export the literal `wayland-*` and turn "no session" into a confusing connection error). Both are in the one-liner so a copied invocation is a correct one.

**Image budget.** A 4K output is a multi-megabyte PNG, which matters when an agent has to read the image back. `-s 0.5` (scale factor) and `-t jpeg -q 80` are the levers; `-o <output>` selects a single output on a multi-head host, and `-c` includes the cursor.

**Credential surfaces.** One `window-rule` in `home/nixos/niri.nix` declares `block-out-from = "screen-capture"` for 1Password. **Its `app-id` regex (`^1[Pp]assword$`) is provisional and unverified** — the real identity has still to be read out of `niri msg windows` on alcyone and the regex pinned to it (runtime step 1 below). A window rule whose `matches` never fires is silently inert: no eval error, no warning, nothing visible except the capture itself. Until step 1 lands, treat the guard as declared, not enforced (#303). The rule lives with the other window rules rather than in the capture module because niri applies the **last matching rule's** fields, so keeping every rule in one ordered list keeps precedence readable.

Considered and deliberately *not* declared: the mate-polkit authentication dialog (field is masked, the window is transient, and blocking it would hide exactly the state an agent is often asked to verify); Firefox (a browser cannot be blocked wholesale for the sake of its password fields without blinding the main verification target); the Noctalia lock surface (a layer-shell surface — niri does support `block-out-from` on layer rules — but its field is masked and the lock surface is itself a verification target in the lock-before-sleep probes). Revisit the moment a surface renders a secret in plaintext.

## Sharp edges

**`block-out-from` is not a secrecy guarantee — but it reaches further than the screencopy path.** A blocked window is blacked out of `grim` *and* of niri's fully automatic screenshot actions: `screenshot-screen` and `screenshot-window`, which on this host are `Super+Shift+3`, `Super+Shift+5`, their `Super+Ctrl+Shift` twins, `Ctrl+Print` and `Alt+Print` ([keybinds.md](./keybinds.md) §Screenshots). What still sees the window is the **interactive** screenshot UI — the `screenshot` action, `Super+Shift+4`, `Super+Ctrl+Shift+4` and bare `Print` — because it renders to `RenderTarget::Output` (§Rationale). Read the rule as "no capture that runs without a human at the console is a credential channel," never as "1Password can never be screenshotted."

**To deliberately capture a blocked window**, use that interactive UI at the console, or remove the window rule. There is no flag on `grim` or on niri's automatic actions that overrides the block, and nothing an SSH session can reach will capture it — which is the point.

**NVIDIA is the most likely way this fails on alcyone.** alcyone is the fleet's first discrete-GPU host (RTX 4060), and DMABUF black-screen behaviour on NVIDIA is a reported niri failure mode on the *portal/PipeWire ScreenCast* path ([niri #2223](https://github.com/YaLTeR/niri/issues/2223) — "ScreenCast shows window selection but only black screen", with portal format-negotiation logs). That is the other route, not this one (§Rationale: no portal is on the `wlr-screencopy` path), so it is not direct evidence about `grim`. It is cited because the NVIDIA DMABUF import it trips over is shared plumbing underneath both routes, which makes the same class of failure plausible here — the same risk [screen-sharing.md](./screen-sharing.md) records as low on Intel metis. A capture that returns a plausible-looking black or garbled frame is worse than one that errors, which is why the runtime check below reads a *known string* back out of the image rather than just checking that a PNG was produced.

**Protocol drift is a live risk at the next bump.** `grim` 1.5.0 added `ext-image-copy-capture-v1`, the protocol that supersedes the deprecated `wlr-screencopy-unstable-v1`. The pinned niri implements **only** the wlr one (no `ext-image-copy-capture` delegate exists in `src/handlers/mod.rs` at the pinned rev). 1.5.0 is documented upstream as keeping the wlr protocol alongside the new one, so `grim` is *expected* to fall back to the legacy path here — but that is inference from release notes, not something observed on this host; runtime steps 3–4 are what confirm it, and a failure there is the signal that the fallback is gone. A future `grim` that drops the wlr fallback, on a niri that has not yet added the new protocol, breaks capture. The escape hatch if that happens is niri's own screenshot IPC — which honours the block-out rule, so it captures everything *except* the credential window: for the agent path that is the conservative direction, and the artifact-fetch cost is the count (2) above rather than a correctness problem.

**`grim -T` (toplevel capture) is unavailable here** — it depends on `ext-image-copy-capture`, which this niri does not implement.

**Asleep outputs.** Noctalia's idle path turns displays off; screencopy of a blanked output is not guaranteed to produce a live frame. Confirm the output is awake before treating a black capture as evidence of a black screen.

**Same-user only.** This works because the SSH login is the operator, the same uid that owns `/run/user/<uid>` and the compositor. There is no root path and no cross-user path, and none should be added — a root-readable capture channel is a materially different security posture.

**No wrapper, deliberately.** The invocation stays a documented one-liner rather than a `capture` script in the flake — the lightest mechanism that holds the guarantee ([ADR-032](../decisions/ADR-032-proportionate-enforcement-and-rationale.md)). Escalate to a wrapper on repeated evidence; the `wayland-0` misdiscovery above is the specific failure to watch for.

## Runtime verification

Declaring `grim` in the flake proves nothing about capture working — the eval-time state and the enforced state are different things (#303). #529 stays open until this passes on alcyone.

1. **App-id first (pre-merge).** With 1Password open, `niri msg windows` — read the real app-id and pin the window-rule regex to it (native Wayland and XWayland report different identities).
2. **Eval + install.** `nix build .#nixosConfigurations.alcyone.config.system.build.toplevel --no-link`, then `nh os switch`; `command -v grim` resolves in the session.
3. **Capture off-host.** From neptune or alnair, run the documented one-liner; the local file is a non-empty PNG (`file`) at the output's native dimensions.
4. **The image is real.** Open a foot window containing a known unique string, capture, and read the image — the string is legible. This is the whole point of the capability, and it is what catches an NVIDIA black/garbled frame.
5. **Discovery is not hardcoded.** From the SSH session, `systemctl --user show-environment | grep WAYLAND_DISPLAY` returns the live value (expect `wayland-1`, not `wayland-0`).
6. **The guard binds.** With 1Password open and visible: the `grim` capture shows a blank block where its window is, and so does the image left on disk by `niri msg action screenshot-screen` (check the action's own flag spelling with `niri msg action screenshot-screen --help` before running it). Then `Super+Shift+4` (the interactive UI) over the same window — its contents *are* legible. That asymmetry, automatic-blocked / interactive-visible, is the model §Rationale asserts. If `grim` does not block it, the rule is not matching (back to step 1).
7. **No side effects.** `wl-copy sentinel`, capture, `wl-paste` still returns `sentinel`; `~/Pictures/Screenshots` gained no file; nothing was left in `/tmp`.
8. **Survives a session restart.** Log out and back in, re-run the *unmodified* one-liner — still works, proving discovery is not pinned to a compositor PID.
9. **Record the asleep-output behaviour.** After idle blanking, run the capture and note what actually happens (black frame / hang / error), then amend the sharp edge above to say what was observed rather than what was feared.

## References

- [#529](https://github.com/dannyfaris/nix-config/issues/529) — this capability (intent, scope, the re-cut from metis to the desktop class).
- [#411](https://github.com/dannyfaris/nix-config/issues/411) — the verification session that surfaced the gap (no screenshot tool on the host).
- [#303](https://github.com/dannyfaris/nix-config/issues/303) — set ≠ enforced; why the checklist above gates closure.
- [#555](https://github.com/dannyfaris/nix-config/issues/555) / [#559](https://github.com/dannyfaris/nix-config/issues/559) — sibling contexts (microVM guests, headless CI VMs) that want to look at a screen; `grim` is the compositor-agnostic answer wherever the guest speaks `wlr-screencopy`.
- [screen-sharing.md](./screen-sharing.md) — the screencast path (portal + PipeWire); explicitly not this.
- [remote-desktop-access.md](../design/remote-desktop-access.md) — the interactive remote-control design; this is its read-only rung.
- [keybinds.md](./keybinds.md) §Screenshots — the human capture path at the console, unchanged; which of those chords are automatic (blocked) and which interactive (not) is the §Sharp edges split.
- [niri.md](./niri.md) — compositor selection; window rules are part of niri-flake's settings surface.
- [community-config-survey.md](../research/community-config-survey.md) §3.10 — where the `block-out-from` idea came from.
- grim — https://gitlab.freedesktop.org/emersion/grim
- wlr-screencopy-unstable-v1 — https://wayland.app/protocols/wlr-screencopy-unstable-v1
- niri #2223 — DMABUF black screen on NVIDIA, on the portal/PipeWire ScreenCast path (adjacent evidence, not this route): https://github.com/YaLTeR/niri/issues/2223
