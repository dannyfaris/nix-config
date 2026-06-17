# niri — Wayland scrollable-tiling compositor.
#
# Imports niri-flake's nixosModule (package + polkit + dconf + OpenGL +
# xdg.portal + the wayland-sessions/niri.desktop entry that greetd
# discovers) and enables programs.niri at the system layer.
#
# Binary cache: niri-flake.cache.enable defaults to true upstream, which
# would silently add `niri.cachix.org` to nix.settings.substituters —
# one implicit trust delegation per host that imports the module.
# CLAUDE.md's whitelist > blanket stance says every trust delegation
# should be deliberate. The principled shape is therefore to *own* the
# delegation here rather than let niri-flake own it implicitly:
# niri-flake.cache.enable = false so the implicit add doesn't happen,
# and nix.settings then explicitly whitelists the same cache with the
# same upstream key. The delegation is recorded in source, dated, and
# only applies on hosts that import this module (currently metis).
#
# Trust footprint: sodiboo (maintainer) on a single Cachix signing key,
# bounded to niri-stable + niri-unstable + xwayland-satellite (x86_64
# only — niri.cachix.org does not serve aarch64, which is fine here
# because no aarch64 host imports this module). See
# github.com/sodiboo/niri-flake README "Binary cache" section. Revoke
# by removing this module from any host's imports, or by deleting the
# substituter/key lines below; cache.enable = false ensures niri-flake
# does not re-add it.
#
# Without the substituter, niri rebuilds from source on every
# niri-flake bump (~10-30 min on metis-class hardware), and nixpkgs's
# Rust crate fetcher currently 403s on some crates.io paths
# (rust-lang/crates.io#13482, NixOS/nixpkgs#512735 in flight). Both
# costs disappear once the cache is trusted.
#
# Per ADR-028.
{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.niri-flake.nixosModules.niri ];

  programs.niri.enable = true;

  # niri 26.04 line, via niri-flake's *unstable* channel — niri-flake still
  # pins its `stable` slot to 25.08, and 26.04 is where `include optional=true`
  # landed. That directive lets Noctalia theme niri through a declared include
  # (we own the include line; Noctalia writes the colour file) without anyone
  # rewriting the read-only config.kdl. Pinned in flake.lock + served by
  # niri.cachix.org, so "unstable" here means a pinned, cached release commit,
  # not a moving target. See ADR-036 and docs/desktop/noctalia.md.
  programs.niri.package = inputs.niri-flake.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;

  # Own the trust delegation explicitly in nix.settings below; do not
  # let niri-flake add `niri.cachix.org` implicitly via this module's
  # default-true behaviour.
  niri-flake.cache.enable = false;

  # Explicit whitelist (2026-05-28) — replaces the implicit
  # niri-flake.cache.enable = true. Public key sourced from upstream
  # niri-flake `flake.nix` (the same key niri-flake would have added).
  nix.settings = {
    substituters = [ "https://niri.cachix.org" ];
    trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };

  # Register niri's package-shipped systemd user units (niri.service +
  # niri-shutdown.target, at `$out/{lib,share}/systemd/user/` — hardlinked)
  # for systemd-user discovery. niri-flake's nixosModule installs the niri
  # package via `environment.systemPackages` only, so without this NixOS
  # never symlinks the shipped units into `/etc/systemd/user/` and greetd
  # → niri-session's `systemctl --user --wait start niri.service` fails
  # with "Unit not found". See issue #67 for the incident write-up.
  systemd.packages = [ config.programs.niri.package ];

  # Don't let `nh os switch` SIGTERM the live compositor. switch-to-
  # configuration otherwise restarts niri.service when it changes, tearing
  # down the whole graphical-session.target mid-session (and wedging greetd
  # on recovery). `restartIfChanged = false` marks the unit
  # X-RestartIfChanged so switch leaves the running session alone; changes
  # are picked up on the next login.
  #
  # The override must be a *drop-in*: the default full-replace strategy
  # shadows the package unit with a NixOS-generated stub that has no
  # ExecStart= — the exact #67 failure. `overrideStrategy = "asDropin"`
  # keeps the package's `ExecStart=niri --session`. `enableDefaultPath =
  # false` stops NixOS injecting a minimal `PATH=` that would shadow the
  # full session PATH niri-session populates at runtime via `systemctl
  # --user import-environment` (else foot/waybar/fuzzel spawns break).
  systemd.user.services = {
    niri = {
      overrideStrategy = "asDropin";
      restartIfChanged = false;
      enableDefaultPath = false;
    };

    # niri-flake also runs a polkit authentication agent by default — the KDE
    # agent, via the `niri-flake-polkit` user service. Disable it (the
    # niri-flake-documented lever): on this non-Plasma host the KDE/Kirigami
    # agent renders off-theme (it reads kdeglobals, which Stylix doesn't write,
    # so it falls back to stock Breeze), and it is the host's only Qt app —
    # 573 MiB of Qt/KDE for one dialog. It is replaced by mate-polkit (GTK,
    # base16-themed) in home/nixos/polkit-agent.nix, and the now-vestigial
    # Stylix `qt` target is dropped in stylix-targets-desktop.nix. See
    # docs/desktop/polkit.md (#103).
    niri-flake-polkit.enable = false;
  };
}
