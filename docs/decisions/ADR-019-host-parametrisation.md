# ADR-019: Per-host parametrisation — `_module.args.hostContext` + `extraSpecialArgs`

**Date**: 2026-05-18
**Status**: Accepted

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

## Context

When the configuration was a single-host repo, two home-manager modules — `editor.nix` (for nixd's `flakePath`/`hostName` options-expr targets) and `nix-tooling.nix` (for the `NH_FLAKE` environment variable) — hardcoded the host's name and the repo's on-disk path as string literals. With a second host (Mercury, ADR-017) those values diverge across hosts even when the rest of the module is shared.

Three approaches were on the table. First: parametrise via `_module.args` set at the host level, consumed as function arguments by the modules that need the values. Second: split the affected modules per-host into `editor-<host>.nix` and similar — the same shape ADR-020 uses for work-vs-personal divergences. Third: read the values from `config.networking.hostName` and a hardcoded path, leaving the assumption that the repo always lives at the same path on every host.

The constraint that made the choice non-obvious: home-manager's NixOS-module integration evaluates `home-manager.users.<name>` modules in a separate module-system instance from the surrounding NixOS modules. `_module.args` set at the NixOS level does not automatically flow into home-manager submodules — `home-manager.extraSpecialArgs` is the explicit forwarding path, and getting this wrong is silent (modules just fail to evaluate with an unrelated-looking error).

## Decision

Each host file declares `_module.args.hostContext` as an attribute set containing the per-host values: `hostName`, `flakePath`, and `extraHomeModules`. The `modules/nixos/home-manager.nix` wiring file consumes `hostContext` as a **function argument** (`{ hostContext, ... }:`) — not via `config._module.args.hostContext`, which is a write-only sink at the option layer and not a reliable read path on the merged `config` tree. The wiring file then forwards `hostContext` into the home-manager submodule system via `home-manager.extraSpecialArgs = { inherit hostContext; }`. Individual home modules (`editor.nix`, `nix-tooling.nix`) take `hostContext` as a function argument the same way and read the fields they need.

`hostContext.extraHomeModules` is a list of additional home-manager modules each host can contribute, appended to the wiring file's standard imports list with `++ (hostContext.extraHomeModules or [ ])`. This is the channel used by ADR-020's import splits — the VM contributes `git-identity-dual.nix` + `gh.nix`, Mercury contributes `git-identity-work.nix`.

The mechanism is opt-in for individual modules. Modules that don't need per-host values continue to be plain attribute sets (`_: { … }`) and don't have to know about `hostContext`.

## Rationale

The split-per-host alternative would have created `editor-nixos-vm.nix` / `editor-mercury.nix` with almost-identical content — duplication for two diverging string literals. As host count grows the duplication compounds, and a change to the editor configuration would have to land in every per-host copy. Parametrisation keeps the editor configuration in one file and pushes only the diverging values to the host level, where they belong (the host file is the canonical answer to "what is this host's name and where is its config repo?").

The "read from `config.networking.hostName` + hardcoded path" alternative was rejected on the path assumption. `/home/dbf/nix-config` is true today for both hosts but encodes a user assumption (single user, conventional home dir layout) that a future host might break. A `hostContext` attribute set is also extensible — adding a new per-host value is a one-field change, not a refactor.

The `_module.args` vs `extraSpecialArgs` distinction matters because of how home-manager's NixOS module integrates with the surrounding NixOS module system. The home-manager `users.<name>` modules evaluate in their own module-system instance with their own `_module.args`. `extraSpecialArgs` is the option that bridges the two — set on the NixOS side, it injects into the home-manager-side module system as additional function arguments. Without it, the home modules would fail to find `hostContext` and the error would point at the consuming module (`editor.nix`), not at the missing forwarder. The trap is recoverable but easy to fall into, hence the explicit comment in `modules/nixos/home-manager.nix`.

The second trap, less obvious: a module that sets `_module.args.<name>` cannot itself read `config._module.args.<name>` back out — `_module.args` exists to inject arguments into the module-system evaluation, and the merged `config` tree does not expose it as a readable attribute in the way ordinary options do. The wiring file must take `hostContext` as a function argument like any other module. This is captured in the file's header comment.

## Consequences

- ✓ Per-host divergences in shared modules become one-line reads from `hostContext`, with the diverging values declared once at the host level.
- ✓ The mechanism is opt-in. Modules that don't need per-host values are unchanged.
- ✓ `hostContext.extraHomeModules` provides a clean per-host extension point for ADR-020's import splits, avoiding host-keyed `mkIf` in the shared modules.
- ✗ Adding a new per-host parameter requires touching every host file. For two hosts this is trivial; for ten it's a real cost. A schema/default mechanism could address this if the host count grows.
- ✗ The two traps (function-arg vs `config` read; NixOS-side `_module.args` vs HM-side `extraSpecialArgs`) cost a future operator a debugging session on first encounter. The mitigation is documentation: this ADR, the header comment in `modules/nixos/home-manager.nix`, and a pointer from `CLAUDE.md`.
- ⚠ Migration trigger: if `hostContext` grows beyond ~5 fields, or if conditional logic ("on hosts where X, set Y") creeps into individual modules reading from it, the right move is probably a typed module option layer (e.g. `options.hostContext = lib.mkOption …`) with mkIf branches per use-site. The current loose attrset is appropriate at the current scale.

## Implementation

- `hosts/<host>/default.nix` sets `_module.args.hostContext = { hostName = …; flakePath = …; extraHomeModules = [ … ]; };`
- `modules/nixos/home-manager.nix` takes `{ hostContext, ... }` and sets `home-manager.extraSpecialArgs = { inherit hostContext; }`.
- `home/shared/editor.nix` and `home/shared/nix-tooling.nix` take `{ … , hostContext, … }` and read `hostContext.flakePath` / `hostContext.hostName` directly.
- `hostContext.extraHomeModules` is appended to the home-manager imports list inside the wiring file: `imports = [ … ] ++ (hostContext.extraHomeModules or [ ]);`.

A reference to this ADR lives in the header comments of `modules/nixos/home-manager.nix`, `home/shared/editor.nix`, and `home/shared/nix-tooling.nix`, so the parametrisation pattern is discoverable from any of the modules that consume it.
