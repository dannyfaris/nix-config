# nix-config

## Purpose

Evergreen NixOS configuration. Three hosts: `nixos-vm` (UTM/aarch64
refinement target), `mercury` (AWS EC2/x86_64 work-only headless), and
`metis` (HP ProDesk/x86_64 personal dev box). Metis is transitioning from
headless to the first desktop host (Niri + DMS); see
[ADR-028](./docs/decisions/ADR-028-stylix-foundation-and-desktop-env.md).

## Reference documentation

`docs/` is the canonical record of the *why* behind every decision in this
repo: operating philosophy, naming taxonomy, and a series of light-format
ADRs (one per major decision). Start with [docs/README.md](./docs/README.md).
This CLAUDE.md is the AI/contributor entry point; `docs/` is the deeper
companion.

## Structure

```
flake.nix                          # flake-parts entry point
parts/                             # flake-parts modules (nixosConfigurations, etc.)
lib/mk-host.nix                    # host constructor — thin wrapper over lib.nixosSystem
hosts/<hostname>/                  # host instance: hardware, hostname, stateVersion,
                                   # _module.args, imports of foundation + bundles
modules/core/nixos/foundation.nix  # bundle every NixOS host imports by convention
modules/core/nixos/bundles/        # NixOS-specific capability bundles (system-level)
modules/core/nixos/                # NixOS-specific standalone modules
modules/core/shared/               # cross-platform standalone system modules
home/core/shared/bundles/          # capability bundles (home-level, cross-platform)
home/core/shared/                  # cross-platform standalone home-manager modules
home/core/nixos/                   # NixOS-specific home-manager modules (e.g. macchina)
```

Composition follows the foundation + bundles model (ADR-027): every host
imports `foundation.nix` (identity + admin + posture), opts into capability
bundles for what the host does, and imports standalone modules for
capabilities that don't yet have a bundle home. A new host is a new
directory under `hosts/` that composes these directly — no role layer.
Per-host values (e.g. flake path, hostname for nixd) flow from each host's
`_module.args.hostContext` into home-manager modules via the wiring in
`modules/core/nixos/home-manager.nix`; see ADR-019.

## Philosophy

Tight-from-the-start. Prefer explicit > implicit, declarative > imperative,
whitelist > blanket.

## Deliberate stances — do not relax without asking

| Stance | Rationale |
|--------|-----------|
| `users.mutableUsers = false` | This file is the sole source of truth for user state. `passwd` changes do not persist. |
| SSH: key-only, no passwords, no root | Hardened from boot one. Break-glass is host-specific: UTM console for nixos-vm; AWS EC2 Instance Connect for mercury; physical console (or greetd, once landed) for metis. |
| `allowUnfreePredicate` whitelist | Build fails loudly if a new unfree package slips in. Never replace with blanket `allowUnfree = true`. |
| `programs.command-not-found.enable = false` | Flakes don't generate the programs.sqlite index; leaving it on silently fails. |
| `nix.settings.warn-dirty = false` | Active dev repos are dirty most of the time; the warning is noise. |

## Break-glass

If SSH wedges or keys go wrong, recovery is host-specific:

- **nixos-vm**: UTM console window accepts the user password directly.
- **mercury**: AWS EC2 Instance Connect from the AWS console.
- **metis**: physical console (monitor + keyboard); once ADR-028 lands,
  the greetd login is the same entry point.

In all cases: log in, fix the config, and `sudo nixos-rebuild switch`
(or `nh os switch` when available).

## Build & deploy

```bash
# Rebuild and switch — canonical command, runs anywhere thanks to NH_FLAKE
# (set in home/core/shared/nix-tooling.nix from hostContext.flakePath).
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
- Module file naming follows the "most-communicative term" rule. See
  [docs/taxonomy.md](./docs/taxonomy.md).
- Desktop environment lands on metis (x86_64) per
  [ADR-028](./docs/decisions/ADR-028-stylix-foundation-and-desktop-env.md):
  Niri + Dank Material Shell + Ghostty + greetd, with Stylix as the
  single theme source-of-truth across TUI and shell. The older
  waybar/fuzzel/mako stack at git tag `tier3-desktop-deferred` is
  superseded and should not be resurrected. Desktop modules are not
  installed on nixos-vm — UTM's Apple Virtualization Framework lacks
  `EGL_EXT_device_drm` and cannot render Wayland compositors.

## Open work

See [TODO.md](./TODO.md) for the prioritised roadmap and task tracking.

## License

MIT — see [LICENSE](./LICENSE). Personal NixOS configuration shared
publicly for transparency and reuse; not maintained as a generalisable
template (PRD §2.2).
