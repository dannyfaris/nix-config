# TODO

Prioritised roadmap. Items are resolved in order; later tiers depend on
earlier ones landing cleanly.

## Tier 1 — Flake conversion + home-manager (DONE)

- [x] Draft CLAUDE.md + TODO.md
- [x] Scaffold flake skeleton (flake-parts, inputs wired, `nix flake show` passes)
- [x] Scaffold module layout (hosts/, modules/system/, modules/home/)
- [x] Decompose bootstrap config into modules
- [x] `sudo nixos-rebuild switch --flake .#nixos-vm` succeeds
- [x] Verify equivalence (SSH, user, claude-code, `nix flake check`)
- [x] Trim bootstrap header (repo-level narrative now lives in CLAUDE.md)

## Tier 2 — Secrets management (DONE)

- [x] Integrate sops-nix
- [x] Replace inline `hashedPassword` with `hashedPasswordFile`
- [x] Audit for any other plaintext secrets (only secret was the password hash)
- [x] Scrub plaintext hash from git history (`git-filter-repo`)

## Tier 3 — Desktop environment (Niri + waybar + Stylix) (CONFIG DONE)

- [x] Niri window manager module (ref: sodiboo/system for niri-flake idioms)
- [x] Waybar status bar
- [x] Stylix theming — Tokyo Night, JetBrains Mono (ref: eduardofuncao/nixferatu)
- [x] Fuzzel launcher
- [x] Ghostty terminal
- [x] Mako notifications
- [x] Greetd autologin (config ready, disabled on the VM — see below)

### Known limitation: niri cannot render in the UTM VM

UTM's Apple Virtualization Framework does not expose `EGL_EXT_device_drm`, which
niri requires to acquire a render device. Niri starts and loads its config but
the screen stays black. Greetd is therefore disabled in `hosts/nixos-vm/` and
re-enabled on the future x86_64 desktop. SSH and the rest of the system are
unaffected. The desktop module set is fully built and refined here — only the
session manager is gated.

## Tier 4 — Multi-host

- [ ] x86_64 desktop host (ref: ryan4yin/nix-config for per-host file shape)
- [ ] Enable `services.greetd.enable = true` on the desktop host
- [ ] Verify niri actually renders on real GPU
- [ ] Factor any remaining host-specific bits out of shared modules
