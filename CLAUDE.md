# nix-config

## Purpose

Evergreen NixOS configuration. Currently running on a UTM VM (aarch64-linux,
Apple Virtualization) as a refinement environment before migrating to a
standalone x86_64 desktop.

## Structure

```
flake.nix              # flake-parts entry point
parts/                 # flake-parts modules (nixosConfigurations, etc.)
hosts/nixos-vm/        # host-specific: hardware, hostname, stateVersion
modules/system/        # shared NixOS modules (nix settings, SSH, users, etc.)
modules/home/          # home-manager modules (user packages, dotfiles)
```

Modules stay architecture-agnostic. A new host (e.g. the future x86_64
desktop) is a new directory under `hosts/`, not a rewrite.

## Philosophy

Tight-from-the-start. Prefer explicit > implicit, declarative > imperative,
whitelist > blanket.

## Deliberate stances — do not relax without asking

| Stance | Rationale |
|--------|-----------|
| `users.mutableUsers = false` | This file is the sole source of truth for user state. `passwd` changes do not persist. |
| SSH: key-only, no passwords, no root | Hardened from boot one. Break-glass is the UTM console. |
| `allowUnfreePredicate` whitelist | Build fails loudly if a new unfree package slips in. Never replace with blanket `allowUnfree = true`. |
| `programs.command-not-found.enable = false` | Flakes don't generate the programs.sqlite index; leaving it on silently fails. |
| `nix.settings.warn-dirty = false` | Active dev repos are dirty most of the time; the warning is noise. |

## Break-glass

If SSH wedges or keys go wrong, the UTM console window accepts the user
password directly. Log in there and `sudo nixos-rebuild switch` after fixing
the config. Always keep the UTM window reachable.

## Build & deploy

```bash
# Rebuild and switch (from repo root on the VM):
sudo nixos-rebuild switch --flake .#nixos-vm

# Check flake validity:
nix flake check

# Show flake outputs:
nix flake show
```

## Conventions

- **home-manager** is integrated as a NixOS module (single `nixos-rebuild`
  command for system + home).
- **flake-parts** for flake organisation.
- One inline comment per non-obvious setting explaining "why", not "what".
- Secrets stay plaintext during bootstrap. sops-nix migration is the next-tier TODO.
- Do not scaffold Niri/Stylix yet. Leave hooks where they'll plug in.

## Open work

See [TODO.md](./TODO.md) for the prioritised roadmap and task tracking.
