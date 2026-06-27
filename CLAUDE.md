# nix-config

## Purpose

Evergreen NixOS + nix-darwin configuration. Four live hosts: `nixos-vm`
(UTM/aarch64 refinement target), `mercury` (AWS EC2/x86_64 work-only
headless), `metis` (HP ProDesk/x86_64 shared work + personal dev box), and `neptune`
(Apple Silicon, first nix-darwin host, onboarded 2026-06-02). Metis is
the first desktop host, running niri per
[ADR-029](./docs/decisions/ADR-029-niri-only-desktop.md) (which amends
[ADR-028](./docs/decisions/ADR-028-stylix-foundation-and-desktop-env.md)).
The Stylix-foundation + bundle-composition basis from ADR-028 stands.

## Reference documentation

`docs/` is the canonical record of the *why* behind every decision in this
repo: operating philosophy, naming taxonomy, and a series of light-format
ADRs (one per major decision). Start with [docs/README.md](./docs/README.md).
This CLAUDE.md is the AI/contributor entry point; `docs/` is the deeper
companion.

## Agent memory lives in git, not local state

Work on this repo happens across all four hosts. Claude Code's file-based
memory (`~/.claude/projects/.../memory/`) is **per-host and never synced** —
a fact learned on `metis` is invisible on `neptune`. So anything durable —
decisions, conventions, gotchas, host quirks — must be committed to the repo
where every host sees it: this CLAUDE.md for working agreements and
deliberate stances, `docs/` (ADRs, selection docs) for the *why*, and inline
module comments for the *why* of a setting. Treat local agent memory as a
scratchpad for the current session; if it matters tomorrow or on another
host, write it down in git.

## Structure

```
flake.nix                          # flake-parts entry point
parts/                             # flake-parts modules — parts/nixos.nix builds the NixOS
                                   # configs, parts/darwin.nix the nix-darwin ones
lib/mk-host.nix                    # NixOS host constructor — thin wrapper over lib.nixosSystem
lib/mk-darwin-host.nix             # Darwin host constructor — the nix-darwin parallel
hosts/<hostname>/                  # host instance: hardware, hostname, stateVersion,
                                   # _module.args, imports of foundation + bundles
modules/nixos/foundation.nix   # bundle every NixOS host imports by convention
modules/nixos/bundles/         # NixOS-specific capability bundles (system-level)
modules/nixos/                 # NixOS-specific standalone modules
modules/darwin/foundation.nix  # bundle every Darwin host imports by convention
modules/darwin/                # Darwin-specific standalone modules (no bundles/ yet)
modules/shared/                # cross-platform standalone system modules
home/shared/bundles/           # capability bundles (home-level, cross-platform)
home/shared/                   # cross-platform standalone home-manager modules
home/nixos/bundles/            # NixOS-specific home-manager bundles
home/nixos/                    # NixOS-specific home-manager modules (e.g. macchina-shell-init)
home/darwin/                   # Darwin-specific home-manager modules (e.g. karabiner, hammerspoon)
```

Composition follows the foundation + bundles model (ADR-027): every host
imports `foundation.nix` (identity + admin + posture), opts into capability
bundles for what the host does, and imports standalone modules for
capabilities that don't yet have a bundle home. A new host is a new
directory under `hosts/` that composes these directly — no role layer.
Per-host values (e.g. flake path, hostname for nixd) flow from each host's
`_module.args.hostContext` into home-manager modules via the wiring in
`modules/nixos/home-manager.nix`; see ADR-019.

## Philosophy

Tight-from-the-start. Prefer explicit > implicit, declarative > imperative,
whitelist > blanket.

## Scope discipline — implement only what was asked

Implement exactly the change requested — nothing more. Do not add unrequested config, options, files, default values, sections, keybindings, or doc touches, even when they look like sensible defaults or a natural extension. Unrequested scope directly violates this project's explicit > implicit, whitelist > blanket philosophy: every addition must be a deliberate, endorsed choice, never an agent's guess at what might be wanted. If you believe extra scope is warranted, *suggest* it in prose and wait for express endorsement before touching anything. When in doubt, do less and ask.

## Deliberate stances — do not relax without asking

| Stance | Rationale |
|--------|-----------|
| `users.mutableUsers = false` | This file is the sole source of truth for user state. `passwd` changes do not persist. |
| SSH: key-only, no passwords, no root, account-whitelisted | Hardened from boot one on every host. NixOS sshd pins `AllowGroups [ "wheel" ]`; nix-darwin (neptune) pins `AllowUsers dbf` by name instead — macOS `admin`/`staff` aren't the NixOS `wheel`, and a single-operator box doesn't need the group seam (#233). Either way any non-whitelisted account is locked out by default (whitelist > blanket), plus `MaxAuthTries 3` / `LoginGraceTime 30s` / no TCP+X11 forwarding fleet-wide. Break-glass is host-specific: UTM console for nixos-vm; AWS EC2 Instance Connect for mercury; physical console (or greetd, once landed) for metis; Apple keyboard at the local login for neptune. |
| `allowUnfreePredicate` whitelist | Build fails loudly if a new unfree package slips in. Never replace with blanket `allowUnfree = true`. |
| `programs.command-not-found.enable = false` | Flakes don't generate the programs.sqlite index; leaving it on silently fails. |
| `nix.settings.warn-dirty = false` | Active dev repos are dirty most of the time; the warning is noise. |

These stances are asserted as eval-only CI checks (`lib/stances.nix`, wired in `parts/checks.nix`), so weakening one fails `nix flake check` rather than building green — see [ADR-033](./docs/decisions/ADR-033-eval-checks-stances-and-lib-units.md).

## Break-glass

If SSH wedges or keys go wrong, recovery is host-specific:

- **nixos-vm**: UTM console window accepts the user password directly.
- **mercury**: AWS EC2 Instance Connect from the AWS console.
- **metis**: physical console (monitor + keyboard); once ADR-028 lands,
  the greetd login is the same entry point.
- **neptune**: Apple keyboard + display at the local login.

In all cases: log in, fix the config, and re-activate — `nh os switch`
on NixOS, `nh darwin switch` on neptune (or the underlying
`sudo nixos-rebuild switch` / `darwin-rebuild switch` if `nh` isn't on
PATH).

## Build & deploy

```bash
# Rebuild and switch — canonical command, runs anywhere thanks to NH_FLAKE
# (set in home/shared/nix-tooling.nix from hostContext.flakePath).
# nh wraps nixos-rebuild with integrated nom tree-view progress and a
# generation diff at the end.
nh os switch

# Cheap build verification without activation:
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link

# Check flake validity:
nix flake check

# Break-glass (if nh is broken / unavailable):
sudo nixos-rebuild switch --flake .#<hostname>
```

## Conventions

- **home-manager** is integrated as a NixOS module (single `nixos-rebuild`
  command for system + home).
- **flake-parts** for flake organisation.
- One inline comment per non-obvious setting explaining "why", not "what".
- **Rationale is single-sourced.** An inline comment gives the *why* of one setting in ≤ ~3 lines; anything longer (a decision with alternatives, a multi-item matrix) lives in one canonical home — an ADR or `docs/<area>/` — with a one-line pointer from the code, never restated. Incident provenance (PR-number root causes, dated observations, timings) is history, not rationale — it lives in the PR or an ADR §History, not inline; `git blame` reaches it. See [ADR-032](./docs/decisions/ADR-032-proportionate-enforcement-and-rationale.md) and [docs/workflow.md](./docs/workflow.md) §"Rationale lives in one place".
- **Enforcement is proportionate.** Guardrails are sized to the severity they guard — the lightest mechanism that holds the guarantee (convention → `grep`-lint → bespoke parser), escalating only on repeated evidence; mechanical gates are reserved for correctness-severity issues. See [ADR-032](./docs/decisions/ADR-032-proportionate-enforcement-and-rationale.md).
- Module file naming follows the "most-communicative term" rule. See
  [docs/taxonomy.md](./docs/taxonomy.md).
- **Project workflow conventions** (intent-first issue framing,
  doc-before-code for selections, peer-review staged diffs before
  commit, sense-check `main` before implementing, etc.) live in
  [docs/workflow.md](./docs/workflow.md). Fresh AI sessions and human
  contributors should read this before opening issues or cutting
  code.
- **Non-trivial design moves through the design loop.** A cross-cutting or hard-to-reverse change is designed before it is coded — a design note in [docs/design/](./docs/design/) (intent → forces → options → de-risk), peer-reviewed, with the living-reference update landing in the same change. Invoke the `/design` skill for the procedure; [docs/design/design-loop.md](./docs/design/design-loop.md) is the *why*. The `design-note-structure` lint gates note shape (presence, not quality) in CI; tool/package choices use the `selecting-tooling` skill instead.
- **Claims about runtime behaviour need runtime verification.** `nix flake check`, lints, and peer review confirm the *declared* (eval-time) state, not the *enforced* one — a change can pass all three and still be inert in production ("set ≠ enforced", tracked in [#303](https://github.com/dannyfaris/nix-config/issues/303)). For a change asserting a runtime, security, or network-posture property, confirm the behaviour on a host before calling it done; when it is unclear which layer actually enforces the property, probe it empirically first. Worked example: [#336](https://github.com/dannyfaris/nix-config/issues/336) removed a firewall rule that was never the gate (tailscale's `ts-input` pre-empts the NixOS firewall) — eval and a two-reviewer adversarial pass both missed it, a runtime probe caught it. This is the design loop's de-risk rung applied.
- **PRs land via squash auto-merge.** After `gh pr create`, run
  `gh pr merge <num> --auto --squash` to enable auto-merge; the PR
  squash-merges itself once required checks pass. See
  [docs/workflow.md](./docs/workflow.md) §"PRs land via squash
  auto-merge" for rationale.
- **Markdown is soft-wrapped** — author one line per paragraph (no hard newlines mid-paragraph); the editor handles visual wrapping. Applies to docs, ADRs, READMEs, and issue/PR bodies. New and amended markdown is soft-wrapped even within an otherwise hard-wrapped file; legacy docs reflow opportunistically when next substantively edited (no bulk reflow). See [docs/workflow.md](./docs/workflow.md) §"Markdown is soft-wrapped" for rationale.
- Desktop environment lands on metis (x86_64) per ADR-028
  (Stylix-foundation + bundle composition), amended by
  [ADR-029](./docs/decisions/ADR-029-niri-only-desktop.md) (niri-only
  direction; per-tool selections). Stack: niri + foot + greetd, with
  Stylix as the theme source-of-truth for the TUI surface, foot,
  fuzzel, fnott, waybar, firefox, and GTK/Qt toolkit theming.
  Pointer + icon cohesion (`stylix.cursor`, `stylix.icons`, niri
  focus-ring) is tracked separately under #110 — promised by ADR-028
  but not yet wired. Per-tool selections (application launcher,
  notification daemon, status bar, browser, IDE) land deliberately
  as `docs/desktop/<tool>.md` selection rationale per issue
  (#72–#77). The previously-recorded "do not resurrect waybar /
  fuzzel / mako" guidance is inverted by ADR-029 — waybar and fuzzel
  are now the chosen status bar and launcher; fnott (not mako) is
  the chosen notification daemon. Living documents under
  [docs/desktop/](./docs/desktop/) cover keybinds, fonts, and each
  per-tool selection. Desktop modules are not installed on nixos-vm
  — UTM's Apple Virtualization Framework lacks `EGL_EXT_device_drm`
  and cannot render Wayland compositors.

## Open work

Tracked in [GitHub issues](https://github.com/dannyfaris/nix-config/issues), framed intent-first (see [docs/workflow.md](./docs/workflow.md)). Roadmap-level items carry the `roadmap` label.

## License

MIT — see [LICENSE](./LICENSE). Personal NixOS configuration shared
publicly for transparency and reuse; not maintained as a generalisable
template (PRD §2.2).
