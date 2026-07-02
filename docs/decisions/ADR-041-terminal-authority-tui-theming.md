# ADR-041: The terminal is the TUI colour authority

**Date**: 2026-07-02
**Status**: Accepted

> TUIs render from the **terminal's 16-colour ANSI palette** instead of build-time Stylix hex — per-tool ANSI/auto-detecting config (bat `base16`, helix `base16_terminal`, fzf `--color=16`, zellij `ansi`, starship/lazygit native ANSI names, yazi dual presets) replaces the Stylix target whitelist, which empties. TUIs now follow runtime polarity flips (the terminal repaints its slots; everything drawn from them follows) and render in the **local** palette over SSH. This ends [ADR-028](./ADR-028-stylix-foundation-and-desktop-env.md) item 1's "Stylix governs the TUI surface" clause fleet-wide (the ADR-028→029 pattern: a direction change gets a superseding ADR), and **deliberately retires the per-host palette-shift SSH signal for TUIs** (operator-endorsed). Stylix itself stays enabled everywhere — as the build-time colour table the statuslines read (#411) and the palette engine behind `lib/scheme-pair.nix` and the Ghostty target.

## Context

Runtime theme switching landed on neptune (#499 stage 1, [`docs/design/macos-live-theme-switching.md`](../design/macos-live-theme-switching.md)): the macOS appearance toggle repaints Ghostty's ANSI slots live via native dual-theme. That promoted a latent defect to a daily one — every Stylix TUI target bakes the *built* polarity's hex into each tool's config, so bat/helix/fzf/zellij/starship/lazygit/yazi stayed dark-tuned after a flip to light. The same class had just produced the stage-1 blocker: the Stylix *fish* target OSC-painted every window with the built palette at shell init, clobbering Ghostty's dual-theme entirely; it was removed universally, with the operator judging its SSH per-host-identity painting "more trouble than it's worth". The remaining targets shared the mismatch (though not the clobber) — and the operator raised the same SSH concern for all of them.

The alternative mechanism was already on the shelf: every affected tool has an ANSI-16 mode (verified against pinned sources/upstream per tool), and the terminal palette is already polarity-correct on every host — Ghostty dual-theme on neptune, Noctalia-templated foot on metis, the local client's terminal for the headless hosts.

## Decision

- **The terminal palette is the runtime colour bus.** TUIs reference ANSI slots (or auto-detect polarity), never baked hex: bat `theme = "base16"` (not `base16-256`, which hardcodes greys), helix `theme = "base16_terminal"`, fzf `--color=16`, zellij built-in `ansi` theme, starship native ANSI colour names, lazygit defaults, yazi dual dark/light presets (auto-selected by terminal background). Config is colocated with each tool's module.
- **The Stylix target whitelist (`home/shared/stylix-targets.nix`) empties but survives** — a future tool with no ANSI mode re-enters through an explicit enable, never `autoEnable` (the whitelist stance is unchanged).
- **Stylix stays enabled fleet-wide** as: the build-time colour table for the four eval-time statuslines (their ANSI conversion is #411), the palette engine for `lib/scheme-pair.nix` (Ghostty dual themes, JankyBorders pairs), and the Ghostty target itself (fonts + palette generation — the terminal *is* the bus, so its own theming remains Stylix-fed).
- **The tokens gain an ANSI projection.** `lib/theme-tokens.nix` colour roles carry `.ansi` — the role's nearest on-bus colour name — alongside `.slot`/`.hex`, single-sourcing the approximation (the bus has no base09/orange position; `attention.ansi = "bright-yellow"`). Terminal-following surfaces (prompt now, #411 statuslines next) style via roles, not colour literals.
- **The per-host palette-shift SSH signal is retired for TUIs.** Remote TUIs render in the local terminal's palette. The per-host scheme still colours each host's own terminal, its statuslines (until #411 decides otherwise), and the macchina banner; the prompt's host marker remains the SSH signal.

## Rationale

- **One mechanism instead of N.** The terminal already repaints its slots on a polarity flip (natively on neptune; via Noctalia/OSC on Linux). Everything drawn from the slots follows for free — no per-tool dual configs, no reload plumbing, no rebuild. The alternative (per-tool dual named themes + polarity detection per tool) re-solves the same problem seven times.
- **SSH coherence over SSH identity.** Baked remote hex renders against whatever the local polarity is — dark-on-light soup after a flip. Following the local palette is always legible; the identity signal it replaces was "higher-friction than it earned" (operator, 2026-07-02), and the fish precedent had already accepted the loss for the most visible surface.
- **Fidelity is the accepted price.** ANSI-16 rendering is coarser than truecolor — helix collapses some syntax classes and uses reversed-video selection; bat's `base16` is plainer than a bespoke gruvbox theme. Judged worth it for polarity-correctness everywhere; the pre-agreed fallback (recorded in `editor.nix`) is per-host dual named themes for any tool where 16 colours grate in daily use.
- **It shrinks the in-flight designs.** [colour-conductor.md](../design/colour-conductor.md) Route 1 planned to re-add the TUI Stylix targets on Linux; with TUIs on the terminal bus, that plan reduces to theming the terminal itself. #411's statusline conversion gains its mechanism (the token `.ansi` projection) and loses zellij's chrome from its scope.

## Consequences

- Positive: every TUI is polarity-correct on both flips of every host, and over SSH, with zero switching plumbing; `stylix-targets.nix` shrinks to a stance marker; #411 has a smaller surface and a ready-made projection to consume.
- Negative: 16-colour fidelity loss (helix most visibly); the TUI palette-shift SSH cue is gone; on metis the shared per-tool config is *new* theming (TUIs move from tool defaults to foot's Noctalia palette) — coherent with ADR-036's conductor model but a visible change; Linux hosts change appearance at their next switch, not before.
- The statuslines (zjstatus bar, gh-dash, Claude statusline, macchina) remain baked hex until #411 — visibly off after a light flip, a known intermediate state.

## References

- [`docs/design/macos-live-theme-switching.md`](../design/macos-live-theme-switching.md) — the runtime-switching design whose stage-1 verification surfaced the fish clobber and this mismatch class.
- [ADR-028](./ADR-028-stylix-foundation-and-desktop-env.md) item 1 (ended for the TUI surface), [ADR-036](./ADR-036-noctalia-shell-linux-desktop.md) (the Linux-desktop half of the same demotion; E2's statusline re-homing is reshaped by the token projection).
- #499 (runtime switching), #411 (statusline conversion — consumes the `.ansi` projection), #427 (colour-conductor epic — Route 1's target re-add reduces per §Rationale).

## History

- 2026-07-02 — Accepted; implemented in the same change (per-tool conversion + whitelist empty + token projection). Adversarial plan review preceded implementation (starship `orange` gap, ADR-need, and mercury-switch sequencing were its blocking findings, all resolved here).
