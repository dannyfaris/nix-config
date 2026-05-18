# ADR-007: Nix tooling — nh, nom, nixd, nixfmt, statix, deadnix

**Date**: 2026-05-06
**Status**: Accepted

## Context

The user spends substantial time *using* nix on this box: editing
`flake.nix` files, rebuilding the system, debugging closure issues, formatting
nix code. The default `nix` CLI is functional but spartan. The same logic
that selected fish/zellij/helix over their plainer counterparts (out-of-box
UX, modern aesthetics) extends to the nix experience itself: a small set of
modern overlays significantly improves daily usage.

## Decision

Six tools are installed at the home-manager level as a coherent "nix tooling
layer":

- **nh** — modern wrapper for `nixos-rebuild` and home-manager. `nh os switch`,
  `nh home switch`. Better default output, integrated diff of generations.
- **nix-output-monitor** (`nom`) — replaces wall-of-text nix build output
  with a live tree view of derivations.
- **nixd** — Nix language server (LSP) for editor integration.
- **nixfmt** — RFC-166 nix code formatter (the post-RFC formatter; the old
  `nixfmt-rfc-style` attribute is now a deprecated alias for `nixfmt` itself).
- **statix** — linter for nix antipatterns (unused let bindings, redundant
  patterns, etc.).
- **deadnix** — finds unused function arguments and bindings.

## Rationale

These six tools form a coherent set serving the question "how do you make
the nix dev experience nicer?":

- **nh + nom** are the build/switch layer. `nh` calls `nom` automatically
  when present, so they pair naturally. The output goes from scrolling
  text to a navigable tree; rebuilds become legible.
- **nixd** is non-optional given the editor choice (helix, ADR-005).
  Without an LSP, helix is just a syntax-highlighted text editor for nix
  files. nixd was chosen over `nil` because it has more active
  development and more accurate static analysis.
- **nixfmt** (RFC-166) is the emerging community standard formatter. The
  user picked nixfmt over `alejandra` because nixfmt is what nixpkgs is
  moving toward, and consistency with the broader ecosystem matters
  long-term.
- **statix + deadnix** are linters that catch real bugs and code smells.
  Both are tiny tools, fast, and align with the "tight from the start"
  principle (philosophy.md): keep the tree clean as it grows rather than
  cleaning up later.

A reasonable alternative would be to skip nh/nom and stick with the
default nix CLI, on the grounds of fewer dependencies. The trade is
small (~6 small Rust binaries) for a meaningful daily-experience
upgrade, and home-manager wires them cleanly.

## Consequences

- ✓ Rebuilds are legible: `nh os switch` produces a tree view of progress
  and a generation diff at the end.
- ✓ Helix becomes a real Nix editor with hover, completion, go-to-def via
  nixd.
- ✓ Format-on-save with nixfmt produces consistent style across the
  codebase.
- ✓ Linters catch issues at edit time rather than after they accumulate.
- ✗ Six additional dependencies, three of which (nh, nom, nixd) are
  smaller-community projects than the upstream nix CLI. Future
  fragmentation or maintainer burnout could leave any one of them stranded
  before there's a like-for-like replacement.
- ⚠ Migration trigger: nh or nom going unmaintained — fall back to plain
  `nixos-rebuild switch`. The set is decomposable; losing one doesn't
  invalidate the others.
- ⚠ Migration trigger: nixd LSP lagging behind language features —
  fall back to `nil` (the alternative we considered).

## Implementation

Configured in `home/core/nixos/nix-tooling.nix`:

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    nh
    nix-output-monitor
    nixd
    nixfmt          # RFC-166 formatter (was nixfmt-rfc-style)
    statix
    deadnix
  ];
}
```

Notes:

- These are home-manager packages, not system packages — they're dev
  tools for the user, not system services.
- `nixd` belongs at home-manager level (always available in the editor),
  not in per-project devShells. Editor-side LSP integration relies on
  binaries being on PATH globally for the user.
- `pkgs.nixfmt` is the right attribute. `pkgs.nixfmt-rfc-style` still
  works in current nixpkgs but emits a deprecation warning — it now
  aliases to `pkgs.nixfmt`.
- Helix's nix language config (in `editor.nix`) calls these by absolute
  path via `lib.getExe pkgs.nixfmt` to survive any future binary rename.
- **`NH_FLAKE` is set via `home.sessionVariables`** in the same module so
  `nh os switch` works from any cwd (not just from inside the repo with
  `.` passed explicitly). Hardcoded to `/home/dbf/nix-config`; needs
  updating alongside `editor.nix`'s `flakePath` when the repo moves
  (Tier 5).
- Recommended baseline pass: run `statix check` and `deadnix` on the
  repo once after this slice lands; clean up any flags; then leave them
  as continuous on-edit linters.
