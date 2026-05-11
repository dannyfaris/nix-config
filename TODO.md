# nix-config Roadmap

Prioritised roadmap and progress tracker. See [docs/](./docs/) for design
rationale (philosophy, taxonomy, and 12 ADRs); this file tracks *what's
happening when*.

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

## Tier 3 — Headless Dev (in progress)

A comprehensive terminal tooling layer: fish + starship + direnv + zellij +
helix + git/gh/glab + ssh + modern CLI utils + nix tooling + four agent
CLIs. Standalone-useful and carries forward unchanged when the desktop tier
is later re-introduced on x86_64.

See [docs/](./docs/) for design rationale.

### Slice 1 — Rollback the desktop commit (DONE)

- [x] Local rebuild from rolled-back tree succeeds (`nix build` clean)
- [x] Tag `tier3-desktop-deferred` at the rolled-back commit (preserves desktop work)
- [x] `git push --force-with-lease` to remote
- [x] Push the tag to remote

### Slice 2 — Documentation foundation (DONE)

- [x] `docs/README.md`, `docs/philosophy.md`, `docs/taxonomy.md` created
- [x] 12 ADRs created in `docs/decisions/`
- [x] `CLAUDE.md` updated with `docs/` pointer + tier renumbering reference
- [x] `TODO.md` transformed (this file)
- [x] AI memory files updated to point to `docs/`

### Slice 3a — Decompose modules/system/ (refactor only) (DONE)

- [x] Extract `boot.nix`, `networking.nix`, `locale.nix`, `nix.nix`,
      `ssh.nix`, `sops.nix`, `users.nix`, `packages.nix` from existing
      `default.nix`
- [x] `default.nix` becomes imports-only
- [x] Build verifies byte-identical system closure (stronger than
      `nix store diff-closures` — same store path before and after)

### Slice 3b — System-side support for headless tier (DONE)

- [x] `modules/system/users.nix`: add `users.users.dbf.shell = pkgs.fish` and
      `programs.fish.enable = true` (system-side gate; see ADR-001)
- [x] `modules/system/mosh.nix` created with `programs.mosh.enable = true`
- [x] `modules/system/nix.nix`: extend `allowUnfreePredicate` to include
      `cursor-cli` (codex and gemini-cli are free; see
      `agent_clis_implementation_notes.md`)

### Slice 4 — modules/home/ taxonomy scaffold + migrate existing (DONE)

- [x] Rewrite `modules/home/default.nix` as wrapper with `home-manager.users.dbf.imports`
- [x] Add `home-manager.backupFileExtension = "hm-bak"` and `news.display = "silent"`
- [x] Create stub files: `shell, prompt, direnv, multiplexer, editor, ssh, cli-utils, nix-tooling`
- [x] Migrate `claude-code` package to `agent-clis.nix`
- [x] Migrate `gh` package to `git.nix`
- [x] Build verifies; closure diff empty at package level (only home-manager metadata changed)

### Slice 5a — Terminal foundation (DONE)

- [x] `shell.nix`: `programs.fish.enable` + sparse abbreviation set
- [x] `prompt.nix`: `programs.starship.enable` + minimal config (see ADR-002)
- [x] `direnv.nix`: `programs.direnv.enable` + `programs.direnv.nix-direnv.enable`
- [x] `multiplexer.nix`: `programs.zellij.enable`

### Slice 5b — Editor

- [ ] `editor.nix`: `programs.helix.enable` + settings (theme, line-number,
      bufferline, lsp, `clipboard-provider = "termcode"`)
- [ ] Helix nix language entry: nixd LSP, nixfmt formatter via `lib.getExe`,
      `auto-format = true`

### Slice 5c — Version control + SSH

- [ ] `git.nix`: `programs.git` with dual identity (personal default; work
      via `gitdir:~/work/`), `programs.gh` with `git_protocol = "https"`
      and `gitCredentialHelper.enable`, glab as package
- [ ] `ssh.nix`: `programs.ssh.enable = true` with explanatory comment

### Slice 5d — Tooling collections

- [ ] `cli-utils.nix`: `programs.X.enable` for fzf, bat, eza, zoxide,
      lazygit, yazi; `home.packages` for ripgrep, fd, htop, dust
- [ ] `nix-tooling.nix`: `home.packages` with nh, nix-output-monitor, nixd,
      nixfmt, statix, deadnix

### Slice 5e — Agent CLIs

- [ ] `agent-clis.nix`: `home.packages` with claude-code, codex, gemini-cli,
      cursor-cli (no sops integration — all four use OAuth; see ADR-008)

### Slice 6 — End-to-end verification

- [ ] `nix flake check` clean
- [ ] `sudo nixos-rebuild switch` clean
- [ ] Smoke tests pass (fish login, starship prompt with nix-shell indicator,
      direnv activation, zellij detach/reattach, helix with nixd, dual git
      identity, gh auth/clone produces HTTPS, glab auth, mosh, OSC52 paste,
      all four agent CLIs invoke)

## Tier 4 — Desktop environment (deferred)

Niri + waybar + Stylix + fuzzel + ghostty + mako. Configuration was
completed in commit `9dc80b2` and rolled back; preserved at git tag
`tier3-desktop-deferred` for recovery. To be re-introduced on x86_64
hardware (Tier 5).

The original tier work touched: niri-flake + stylix flake inputs;
`modules/desktop/` (5 files); greetd block in `hosts/nixos-vm/default.nix`.

The deferral is hardware-driven, not design-driven: niri requires
`EGL_EXT_device_drm`, which UTM's Apple Virtualization Framework GPU does
not expose.

## Tier 5 — x86_64 desktop migration

- [ ] Provision x86_64 host
- [ ] Add `hosts/<desktop>/` (mirror of `hosts/nixos-vm/` shape)
- [ ] Re-introduce desktop modules from `tier3-desktop-deferred` tag
- [ ] Enable `services.greetd` on the desktop host
- [ ] Verify niri renders on real GPU
- [ ] Factor any remaining host-specific bits out of shared modules
- [ ] Reference: ryan4yin/nix-config for multi-host flake-parts patterns
