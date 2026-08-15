# nix-config

## Purpose

Evergreen NixOS + nix-darwin configuration. Hosts:

<!-- BEGIN CENSUS: hosts — bound to hosts/ by scripts/lint-host-census.sh (#583) -->

- `alcyone` — Gigabyte B550 GAMING X V2 / x86_64 bare metal, flagship desktop; first discrete GPU (RTX 4060) + first encrypted-at-rest host.
- `alnair` — Surface Laptop 4 / x86_64 bare metal, the fleet's first Linux laptop.
- `electra` — Lenovo ThinkCentre M920q Tiny / x86_64 bare metal, genuinely headless always-on service-tier node, role deliberately open.
- `celaeno` — Apple Silicon Mac mini, first nix-darwin host, onboarded 2026-06-02.

<!-- END CENSUS: hosts -->

Metis was the first desktop host; the Linux desktop now runs on the fleet's NixOS desktop hosts, on niri per [ADR-029](./docs/decisions/ADR-029-niri-only-desktop.md) (which amends [ADR-028](./docs/decisions/ADR-028-stylix-foundation-and-desktop-env.md)). ADR-028's bundle-composition basis stands; its Stylix-as-theming-source-of-truth clause has since been amended — see the desktop bullet under §Conventions for the current stack.

## Reference documentation

`docs/` is the canonical record of the *why* behind every decision in this repo: operating philosophy, naming taxonomy, and a series of light-format ADRs (one per major decision). Start with [docs/README.md](./docs/README.md). This CLAUDE.md is the AI/contributor entry point; `docs/` is the deeper companion.

## Agent memory lives in git, not local state

Work on this repo happens across every live host. Claude Code's file-based memory (`~/.claude/projects/.../memory/`) is **per-host and never synced** — a fact learned on `alcyone` is invisible on `celaeno`. So anything durable — decisions, conventions, gotchas, host quirks — must be committed to the repo where every host sees it: this CLAUDE.md for working agreements and deliberate stances, `docs/` (ADRs, selection docs) for the *why*, and inline module comments for the *why* of a setting. Treat local agent memory as a scratchpad for the current session; if it matters tomorrow or on another host, write it down in git.

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
home/darwin/bundles/           # Darwin-specific home-manager bundles
home/darwin/                   # Darwin-specific home-manager modules (e.g. karabiner, skhd)
```

Composition follows the foundation + bundles model (ADR-027): every host imports `foundation.nix` (identity + admin + posture), opts into capability bundles for what the host does, and imports standalone modules for capabilities that don't yet have a bundle home. A new host is a new directory under `hosts/` that composes these directly — no role layer. Per-host values (e.g. flake path, hostname for nixd) flow from each host's `_module.args.hostContext` into home-manager modules via the wiring in `modules/nixos/home-manager.nix` (body in `lib/mk-home-manager.nix`); see ADR-019.

## Philosophy

Tight-from-the-start. Prefer explicit > implicit, declarative > imperative, whitelist > blanket. Underneath all of them, **everything here is on purpose** — the test a change has to pass is not "does this work" but "was this decided".

The full set of principles, and the *why* behind each, lives in [docs/philosophy.md](./docs/philosophy.md).

## Scope discipline — implement only what was asked

Implement exactly the change requested — nothing more. Do not add unrequested config, options, files, default values, sections, keybindings, or doc touches, even when they look like sensible defaults or a natural extension. Unrequested scope directly violates this project's explicit > implicit, whitelist > blanket philosophy: every addition must be a deliberate, endorsed choice, never an agent's guess at what might be wanted. If you believe extra scope is warranted, *suggest* it in prose and wait for express endorsement before touching anything. When in doubt, do less and ask. See [docs/workflow.md](./docs/workflow.md) §"Implement only what was asked" for the procedure and [docs/philosophy.md](./docs/philosophy.md) §"Whitelist over blanket" for the principle.

## Deliberate stances — do not relax without asking

| Stance                                                    | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `users.mutableUsers = false`                              | This file is the sole source of truth for user state. `passwd` changes do not persist.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| SSH: key-only, no passwords, no root, account-whitelisted | Hardened from boot one on every host. NixOS sshd pins `AllowGroups [ "wheel" ]`; nix-darwin (celaeno) pins `AllowUsers dbf` by name instead — macOS `admin`/`staff` aren't the NixOS `wheel`, and a single-operator box doesn't need the group seam (#233). Either way any non-whitelisted account is locked out by default (whitelist > blanket), plus `MaxAuthTries 3` / `LoginGraceTime 30s` / no TCP+X11 forwarding fleet-wide. Fleet SSH trust (which host may reach which) is a declared edge whitelist per [ADR-042](./docs/decisions/ADR-042-fleet-ssh-declared-edges.md). Break-glass is host-specific — see §Break-glass. |
| `allowUnfreePredicate` whitelist                          | Build fails loudly if a new unfree package slips in. Never replace with blanket `allowUnfree = true`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `programs.command-not-found.enable = false`               | Flakes don't generate the programs.sqlite index; leaving it on silently fails.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `nix.settings.warn-dirty = false`                         | Active dev repos are dirty most of the time; the warning is noise.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

These stances are asserted as eval-only CI checks (`lib/stances.nix`, wired in `parts/checks.nix`), so weakening one fails `nix flake check` rather than building green — see [ADR-033](./docs/decisions/ADR-033-eval-checks-stances-and-lib-units.md).

## Break-glass

If SSH wedges or keys go wrong, recovery is host-specific:

<!-- BEGIN CENSUS: break-glass — bound to hosts/ by scripts/lint-host-census.sh (#583) -->

- **alcyone**: physical console (monitor + keyboard) or the greetd login.
- **alnair**: physical console (built-in keyboard + display) or the greetd login.
- **electra**: physical console (monitor + keyboard) — headless, so there is no greetd login.
- **celaeno**: Apple keyboard + display at the local login.

<!-- END CENSUS: break-glass -->

In all cases: log in, fix the config, and re-activate — `nh os switch` on NixOS, `nh darwin switch` on the Darwin host (or the underlying `sudo nixos-rebuild switch` / `darwin-rebuild switch` if `nh` isn't on PATH).

## Build & deploy

```bash
# Rebuild and switch — canonical command, runs anywhere thanks to NH_FLAKE
# (set in home/shared/nix-tooling.nix from hostContext.flakePath).
# nh wraps nixos-rebuild with integrated nom tree-view progress and a
# generation diff at the end.
nh os switch

# Cheap build verification without activation:
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link

# Same, on a Darwin host:
nix build .#darwinConfigurations.<hostname>.system --no-link

# Check flake validity:
nix flake check

# Break-glass (if nh is broken / unavailable):
sudo nixos-rebuild switch --flake .#<hostname>
```

Gotcha: `sudo nix store delete <paths>` always fails "still alive" — sudo puts the paths into the child's environment via `SUDO_COMMAND`, and the GC's `/proc` liveness scan reads them as live roots. Run store deletions from a root shell (`sudo -i`) instead, keeping the paths off the sudo command line.

In a nix-less agent/cloud session, run `scripts/fetch-lint-toolchain.sh` once, then lint staged work with the fetched set before pushing — CI runs the same linters at the same pins. See [docs/design/cloud-session-lint-toolchain.md](./docs/design/cloud-session-lint-toolchain.md).

## Conventions

- **home-manager** is integrated as a NixOS module (and as a nix-darwin module on the Darwin host) — one rebuild command per host for system + home.
- **flake-parts** for flake organisation.
- One inline comment per non-obvious setting explaining "why", not "what".
- **Rationale is single-sourced.** An inline comment gives the *why* of one setting in ≤ ~3 lines; anything longer (a decision with alternatives, a multi-item matrix) lives in one canonical home — an ADR or `docs/<area>/` — with a one-line pointer from the code, never restated. Incident provenance (PR-number root causes, dated observations, timings) is history, not rationale — it lives in the PR or an ADR §History, not inline; `git blame` reaches it. See [ADR-032](./docs/decisions/ADR-032-proportionate-enforcement-and-rationale.md) and [docs/workflow.md](./docs/workflow.md) §"Rationale lives in one place".
- **Enforcement is proportionate.** Guardrails are sized to the severity they guard — the lightest mechanism that holds the guarantee (convention → `grep`-lint → bespoke parser), escalating only on repeated evidence; mechanical gates are reserved for correctness-severity issues. See [ADR-032](./docs/decisions/ADR-032-proportionate-enforcement-and-rationale.md).
- Module file naming follows the "most-communicative term" rule. See [docs/taxonomy.md](./docs/taxonomy.md).
- **Platform twin-pairs share a lib constructor only when values-only.** A `modules/{nixos,darwin}` pair whose bodies differ solely in platform-constant values is built from one `lib/mk-*.nix` constructor taking explicit per-platform args stated at the two call sites, with no central platform record; pairs differing in logic, option surface, or upstream module semantics (firewall, sshd, nix-daemon) stay two files. See #541 and [docs/philosophy.md](./docs/philosophy.md) §"No premature abstraction; YAGNI".
- **Project workflow conventions** (intent-first issue framing, doc-before-code for selections, peer-review staged diffs before commit, sense-check `main` before implementing, etc.) live in [docs/workflow.md](./docs/workflow.md). Fresh AI sessions and human contributors should read this before opening issues or cutting code.
- **Peer review binds to what executes, not what's committed.** Any script, command sequence, or activation/migration step that will run on a host — whether by the operator or by the agent itself — chat one-liners, scratchpad scripts, PR-body steps, commands the agent runs in its own shell — gets the same adversarial subagent review as a staged diff *before* it executes; root or auth/boot-path surface makes this non-waivable regardless of size, and such changes also require a VM reboot rehearsal before hardware. See [docs/workflow.md](./docs/workflow.md) §"Peer review binds to what executes, not what's committed".
- **Non-trivial design moves through the design loop.** A cross-cutting or hard-to-reverse change is designed before it is coded, run as an operator dialogue agreement-gated at every stage boundary through the start of build — a design note in [docs/design/](./docs/design/) (intent → forces → options → de-risk), peer-reviewed, with the living-reference update landing in the same change. Invoke the `/design` skill for the procedure; [docs/design/design-loop.md](./docs/design/design-loop.md) is the *why*. The `design-note-structure` lint gates note shape (presence, not quality) in CI; tool/package choices use the `selecting-tooling` skill instead.
- **Claims about runtime behaviour need runtime verification.** A change asserting a runtime, security, or network-posture property is not done until that behaviour has been observed on a host — eval, lints and peer review all read the declaration, never the enforcement — and where it is unclear which layer enforces a property, probe it empirically first. See [docs/philosophy.md](./docs/philosophy.md) §"Set is not enforced" for the rule and the set ≠ enforced gap it names ([#303](https://github.com/dannyfaris/nix-config/issues/303)).
- **PRs land via squash auto-merge.** After `gh pr create`, run `gh pr merge <num> --auto --squash` to enable auto-merge; the PR squash-merges itself once required checks pass. See [docs/workflow.md](./docs/workflow.md) §"PRs land via squash auto-merge" for rationale.
- **Markdown is soft-wrapped** — one line per paragraph (no hard newlines mid-paragraph). Tracked `.md` files are formatted to this shape by dprint via treefmt (`nix fmt`), the mechanism chosen in [ADR-046](./docs/decisions/ADR-046-markdown-formatter.md) and wired in #435 PR B. Issue/PR *bodies* stay hand-authored soft-wrapped (the formatter cannot reach `gh` descriptions). See [docs/workflow.md](./docs/workflow.md) §"Markdown is soft-wrapped" for rationale.
- Desktop environment runs on alcyone and alnair per ADR-028 (bundle composition), amended by [ADR-029](./docs/decisions/ADR-029-niri-only-desktop.md) (niri-only), [ADR-036](./docs/decisions/ADR-036-noctalia-shell-linux-desktop.md) (Noctalia as the cohesive shell) and — via ADR-036 — [ADR-048](./docs/decisions/ADR-048-noctalia-theming-delegation.md) (theming delegated to Noctalia's own native engine on Linux, reversing [ADR-044](./docs/decisions/ADR-044-linux-runtime-theme-menu.md) there and amending [ADR-041](./docs/decisions/ADR-041-terminal-authority-tui-theming.md)'s Linux scope; Darwin's ADR-044 conductor and ADR-041 arrangement are untouched). Stack: niri + foot + greetd + Noctalia — Noctalia owns bar, launcher, notifications, lock, OSD, wallpaper, idle **and colour** (builtin/community/wallpaper theme picks in its own UI), subsuming waybar / fuzzel / fnott / swaylock + swayidle, all decommissioned in #385. Nix declares only the mechanism residue Noctalia doesn't handle natively — a whitelisted builtin-template set (`foot`/`gtk3`/`gtk4`/`niri`), pre-declared foot/niri mount-points, and a `colors_changed` repaint hook for already-open terminals; untemplated TUIs stay on the terminal-ANSI bus (ADR-041) and fonts resolve through the fontconfig conductor (#390); Stylix stays enabled as the boot-default palette engine, plus a named residue confirmed by the G6 Stylix-exit audit (#825): the GTK toolkit target (settings.ini, adw-gtk3, font), fonts plumbing (E1/#390), and icon/cursor theme selection (`stylix.icons`/`stylix.cursor`) — none of them a colour role Noctalia's delegation covers. The Firefox target is dropped outright (zero decision weight per the operator ruling; no replacement wiring) — Firefox renders its own stock defaults. Living documents under [docs/desktop/](./docs/desktop/) cover keybinds, fonts, and each per-tool selection, decommissioned tools included.

## Open work

Tracked in [GitHub issues](https://github.com/dannyfaris/nix-config/issues), framed intent-first (see [docs/workflow.md](./docs/workflow.md)). Roadmap-level items carry the `roadmap` label.

## License

MIT — see [LICENSE](./LICENSE). Personal NixOS configuration shared publicly for transparency and reuse; not maintained as a generalisable template (PRD §2.2).
