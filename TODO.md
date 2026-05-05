# TODO

Prioritised roadmap. Items are resolved in order; later tiers depend on
earlier ones landing cleanly.

## Tier 1 — Flake conversion + home-manager (CURRENT)

- [x] Draft CLAUDE.md + TODO.md
- [x] Scaffold flake skeleton (flake-parts, inputs wired, `nix flake show` passes)
- [x] Scaffold module layout (hosts/, modules/system/, modules/home/)
- [x] Decompose bootstrap config into modules
- [x] `sudo nixos-rebuild switch --flake .#nixos-vm` succeeds
- [x] Verify equivalence (SSH, user, claude-code, `nix flake check`)
- [ ] Trim bootstrap header (repo-level narrative now lives in CLAUDE.md)

## Tier 2 — Secrets management

- [ ] Integrate sops-nix
- [ ] Replace inline `hashedPassword` with `hashedPasswordFile`
- [ ] Audit for any other plaintext secrets

## Tier 3 — Desktop environment (Niri + waybar + Stylix)

- [ ] Niri window manager module (ref: sodiboo/system for niri-flake idioms)
- [ ] Waybar status bar
- [ ] Stylix theming (ref: eduardofuncao/nixferatu for Niri+Stylix end-to-end)
- [ ] Fuzzel launcher

## Tier 4 — Multi-host

- [ ] x86_64 desktop host (ref: ryan4yin/nix-config for per-host file shape)
- [ ] Factor any remaining host-specific bits out of shared modules
